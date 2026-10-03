use crate::config::NutConfig;
use anyhow::{bail, Context, Result};
use std::collections::HashMap;
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    net::TcpStream,
    time::{timeout, Duration},
};

#[derive(Debug, Clone)]
pub struct UpsSnapshot {
    pub status_raw: String,
    pub battery_charge: f64,
    pub battery_runtime_seconds: Option<u64>,
    pub online: bool,
    pub on_battery: bool,
    pub low_battery: bool,
    pub forced_shutdown: bool,
    pub output_off: bool,
}

#[derive(Debug, Clone)]
pub struct NutClient {
    cfg: NutConfig,
}

impl NutClient {
    pub fn new(cfg: NutConfig) -> Self {
        Self { cfg }
    }

    pub async fn poll(&self) -> Result<UpsSnapshot> {
        let vars = self.list_vars().await?;

        let status_raw = vars
            .get("ups.status")
            .context("NUT did not return required variable ups.status")?
            .clone();

        let charge_raw = vars
            .get("battery.charge")
            .context("NUT did not return required variable battery.charge")?;
        let battery_charge: f64 = charge_raw
            .parse()
            .with_context(|| format!("invalid battery.charge value {charge_raw:?}"))?;
        if !battery_charge.is_finite() || !(0.0..=100.0).contains(&battery_charge) {
            bail!("battery.charge is outside 0..=100: {battery_charge}");
        }

        let tokens: Vec<&str> = status_raw.split_whitespace().collect();
        let online = tokens.contains(&"OL");
        let on_battery = tokens.contains(&"OB");

        if tokens.contains(&"WAIT") {
            bail!("NUT UPS status is WAIT; driver has not provided a usable status yet");
        }
        if online && on_battery {
            bail!("ambiguous NUT status contains both OL and OB: {status_raw:?}");
        }
        if !online && !on_battery && !tokens.contains(&"OFF") {
            bail!("NUT status has no definitive OL/OB/OFF state: {status_raw:?}");
        }

        let battery_runtime_seconds = vars
            .get("battery.runtime")
            .and_then(|v| v.parse::<f64>().ok())
            .filter(|v| v.is_finite() && *v >= 0.0)
            .map(|v| v as u64);

        Ok(UpsSnapshot {
            status_raw,
            battery_charge,
            battery_runtime_seconds,
            online,
            on_battery,
            low_battery: tokens.contains(&"LB"),
            forced_shutdown: tokens.contains(&"FSD"),
            output_off: tokens.contains(&"OFF"),
        })
    }

    async fn list_vars(&self) -> Result<HashMap<String, String>> {
        let connect_timeout = Duration::from_secs(self.cfg.connect_timeout_seconds);
        let read_timeout = Duration::from_secs(self.cfg.read_timeout_seconds);

        let stream = timeout(connect_timeout, TcpStream::connect(&self.cfg.address))
            .await
            .context("timed out connecting to NUT upsd")?
            .with_context(|| format!("failed to connect to NUT upsd at {}", self.cfg.address))?;

        let mut stream = BufReader::new(stream);
        let request = format!("LIST VAR {}\n", self.cfg.ups_name);
        stream
            .get_mut()
            .write_all(request.as_bytes())
            .await
            .context("failed to write LIST VAR request to NUT")?;
        stream
            .get_mut()
            .flush()
            .await
            .context("failed to flush LIST VAR request to NUT")?;

        let expected_begin = format!("BEGIN LIST VAR {}", self.cfg.ups_name);
        let expected_end = format!("END LIST VAR {}", self.cfg.ups_name);
        let mut first = true;
        let mut vars = HashMap::new();

        for _ in 0..4096 {
            let mut line = String::new();
            let bytes = timeout(read_timeout, stream.read_line(&mut line))
                .await
                .context("timed out waiting for NUT response")?
                .context("failed reading NUT response")?;

            if bytes == 0 {
                bail!("NUT closed the connection before completing LIST VAR");
            }
            if line.len() > 16 * 1024 {
                bail!("NUT returned an unexpectedly long protocol line");
            }

            let line = line.trim_end_matches(['\r', '\n']);
            if let Some(err) = line.strip_prefix("ERR ") {
                bail!("NUT returned error: {err}");
            }

            if first {
                first = false;
                if line != expected_begin {
                    bail!("unexpected NUT LIST VAR preamble: {line:?}");
                }
                continue;
            }

            if line == expected_end {
                let _ = stream.get_mut().write_all(b"LOGOUT\n").await;
                return Ok(vars);
            }

            let fields = parse_nut_fields(line)
                .with_context(|| format!("failed to parse NUT protocol line {line:?}"))?;
            if fields.len() != 4 || fields[0] != "VAR" || fields[1] != self.cfg.ups_name {
                bail!("unexpected NUT LIST VAR row: {line:?}");
            }

            vars.insert(fields[2].clone(), fields[3].clone());
        }

        bail!("NUT returned too many LIST VAR rows without END LIST")
    }
}

fn parse_nut_fields(input: &str) -> Result<Vec<String>> {
    let mut out = Vec::new();
    let mut chars = input.chars().peekable();

    while chars.peek().is_some() {
        while matches!(chars.peek(), Some(c) if c.is_whitespace()) {
            chars.next();
        }
        if chars.peek().is_none() {
            break;
        }

        let mut field = String::new();
        if chars.peek() == Some(&'"') {
            chars.next();
            let mut closed = false;
            while let Some(ch) = chars.next() {
                match ch {
                    '"' => {
                        closed = true;
                        break;
                    }
                    '\\' => {
                        let escaped = chars.next().context("dangling backslash in quoted NUT field")?;
                        field.push(escaped);
                    }
                    other => field.push(other),
                }
            }
            if !closed {
                bail!("unterminated quoted NUT field");
            }
            if matches!(chars.peek(), Some(c) if !c.is_whitespace()) {
                bail!("unexpected characters after quoted NUT field");
            }
        } else {
            while let Some(ch) = chars.peek().copied() {
                if ch.is_whitespace() {
                    break;
                }
                field.push(ch);
                chars.next();
            }
        }

        out.push(field);
    }

    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_simple_var() {
        let fields = parse_nut_fields(r#"VAR ups ups.status "OB LB""#).unwrap();
        assert_eq!(fields, vec!["VAR", "ups", "ups.status", "OB LB"]);
    }

    #[test]
    fn parses_escaped_value() {
        let fields = parse_nut_fields("VAR ups ups.model \"A \\\"quoted\\\" \\\\ model\"").unwrap();
        assert_eq!(fields[3], "A \"quoted\" \\ model");
    }
}
