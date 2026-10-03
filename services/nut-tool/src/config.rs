use anyhow::{bail, Context, Result};
use serde::Deserialize;
use std::{
    collections::HashSet,
    fs,
    net::SocketAddrV4,
    path::{Path, PathBuf},
};

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct Config {
    pub nut: NutConfig,
    pub policy: PolicyConfig,
    pub ssh: SshConfig,
    pub state: StateConfig,
    pub hosts: Vec<HostConfig>,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            nut: NutConfig::default(),
            policy: PolicyConfig::default(),
            ssh: SshConfig::default(),
            state: StateConfig::default(),
            hosts: Vec::new(),
        }
    }
}

impl Config {
    pub fn load(path: &Path) -> Result<Self> {
        let raw = fs::read_to_string(path)
            .with_context(|| format!("failed to read config {}", path.display()))?;
        let cfg: Self = toml::from_str(&raw)
            .with_context(|| format!("failed to parse TOML config {}", path.display()))?;
        cfg.validate()?;
        Ok(cfg)
    }

    pub fn validate(&self) -> Result<()> {
        if self.nut.address.trim().is_empty() {
            bail!("nut.address must not be empty");
        }
        if self.nut.ups_name.trim().is_empty() {
            bail!("nut.ups_name must not be empty");
        }
        if self.nut.connect_timeout_seconds == 0 || self.nut.read_timeout_seconds == 0 {
            bail!("NUT timeouts must be greater than zero");
        }

        if self.policy.time_on_battery_minutes == 0 {
            bail!("policy.time_on_battery_minutes must be greater than zero");
        }
        validate_percent("policy.low_battery_percent", self.policy.low_battery_percent)?;
        validate_percent("policy.wake_battery_percent", self.policy.wake_battery_percent)?;
        if self.policy.wake_battery_percent < self.policy.low_battery_percent {
            bail!("policy.wake_battery_percent must be >= policy.low_battery_percent");
        }
        if self.policy.poll_interval_seconds == 0 {
            bail!("policy.poll_interval_seconds must be greater than zero");
        }
        if self.policy.max_shutdown_passes == 0 || self.policy.max_wake_passes == 0 {
            bail!("shutdown/wake pass counts must be greater than zero");
        }
        if self.policy.max_concurrent_ssh == 0 {
            bail!("policy.max_concurrent_ssh must be greater than zero");
        }
        if self.policy.wol_packets == 0 {
            bail!("policy.wol_packets must be greater than zero");
        }

        if self.ssh.private_key.trim().is_empty() {
            bail!("ssh.private_key must not be empty");
        }
        if self.ssh.known_hosts.trim().is_empty() {
            bail!("ssh.known_hosts must not be empty");
        }
        if self.ssh.connect_timeout_seconds == 0 || self.ssh.command_timeout_seconds == 0 {
            bail!("SSH timeouts must be greater than zero");
        }

        if self.hosts.is_empty() {
            bail!("at least one [[hosts]] entry is required");
        }

        let mut names = HashSet::new();
        for host in &self.hosts {
            if host.name.trim().is_empty() {
                bail!("host name must not be empty");
            }
            if !names.insert(host.name.clone()) {
                bail!("duplicate host name {:?}", host.name);
            }
            if host.address.trim().is_empty() {
                bail!("host {} has an empty address", host.name);
            }
            if host.ssh_port == 0 {
                bail!("host {} has ssh_port=0", host.name);
            }
            if host.ssh_user.trim().is_empty() {
                bail!("host {} has an empty ssh_user", host.name);
            }
            if host.wake_enabled {
                parse_mac(&host.mac)
                    .with_context(|| format!("host {} has invalid MAC address", host.name))?;
                if host.wol_destination.trim().is_empty() {
                    bail!("host {} has an empty wol_destination", host.name);
                }
                host.wol_destination
                    .parse::<SocketAddrV4>()
                    .with_context(|| format!(
                        "host {} wol_destination must be an IPv4 socket address such as 192.168.1.255:9",
                        host.name
                    ))?;
                if host.wake_check_port == Some(0) {
                    bail!("host {} has wake_check_port=0", host.name);
                }
            }
        }

        Ok(())
    }

    pub fn host(&self, name: &str) -> Result<&HostConfig> {
        self.hosts
            .iter()
            .find(|h| h.name == name)
            .with_context(|| format!("unknown host {name:?}"))
    }

    pub fn state_path(&self) -> PathBuf {
        PathBuf::from(&self.state.path)
    }
}

fn validate_percent(name: &str, value: f64) -> Result<()> {
    if !value.is_finite() || !(0.0..=100.0).contains(&value) {
        bail!("{name} must be between 0 and 100");
    }
    Ok(())
}

pub fn parse_mac(input: &str) -> Result<[u8; 6]> {
    let pieces: Vec<&str> = input.split([':', '-']).collect();
    if pieces.len() != 6 {
        bail!("MAC must contain six octets");
    }

    let mut mac = [0u8; 6];
    for (i, part) in pieces.iter().enumerate() {
        if part.len() != 2 {
            bail!("each MAC octet must be two hexadecimal digits");
        }
        mac[i] = u8::from_str_radix(part, 16)
            .with_context(|| format!("invalid MAC octet {part:?}"))?;
    }
    Ok(mac)
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct NutConfig {
    pub address: String,
    pub ups_name: String,
    pub connect_timeout_seconds: u64,
    pub read_timeout_seconds: u64,
}

impl Default for NutConfig {
    fn default() -> Self {
        Self {
            address: "127.0.0.1:3493".to_string(),
            ups_name: "ups".to_string(),
            connect_timeout_seconds: 3,
            read_timeout_seconds: 3,
        }
    }
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct PolicyConfig {
    pub time_on_battery_minutes: u64,
    pub low_battery_percent: f64,
    pub wake_battery_percent: f64,
    pub poll_interval_seconds: u64,
    pub mains_stable_seconds: u64,
    pub honor_nut_low_battery: bool,
    pub honor_nut_fsd: bool,
    pub shutdown_on_nut_loss_after_confirmed_ob: bool,
    pub max_shutdown_passes: u32,
    pub shutdown_retry_initial_seconds: u64,
    pub shutdown_retry_max_seconds: u64,
    pub max_concurrent_ssh: usize,
    pub continue_after_shutdown_retries_exhausted: bool,
    pub wol_packets: usize,
    pub wol_packet_interval_ms: u64,
    pub max_wake_passes: u32,
    pub wake_retry_seconds: u64,
    pub wake_probe_delay_seconds: u64,
    pub wake_connect_timeout_seconds: u64,
    pub continue_after_wake_retries_exhausted: bool,
}

impl Default for PolicyConfig {
    fn default() -> Self {
        Self {
            time_on_battery_minutes: 10,
            low_battery_percent: 50.0,
            wake_battery_percent: 80.0,
            poll_interval_seconds: 5,
            mains_stable_seconds: 60,
            honor_nut_low_battery: true,
            honor_nut_fsd: true,
            shutdown_on_nut_loss_after_confirmed_ob: true,
            max_shutdown_passes: 5,
            shutdown_retry_initial_seconds: 5,
            shutdown_retry_max_seconds: 30,
            max_concurrent_ssh: 4,
            continue_after_shutdown_retries_exhausted: true,
            wol_packets: 3,
            wol_packet_interval_ms: 250,
            max_wake_passes: 12,
            wake_retry_seconds: 15,
            wake_probe_delay_seconds: 5,
            wake_connect_timeout_seconds: 3,
            continue_after_wake_retries_exhausted: true,
        }
    }
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct SshConfig {
    pub private_key: String,
    pub known_hosts: String,
    pub connect_timeout_seconds: u64,
    pub command_timeout_seconds: u64,
    pub check_command: String,
    pub shutdown_command: String,
}

impl Default for SshConfig {
    fn default() -> Self {
        Self {
            private_key: "/etc/nut-tool/id_ed25519".to_string(),
            known_hosts: "/etc/nut-tool/known_hosts".to_string(),
            connect_timeout_seconds: 5,
            command_timeout_seconds: 15,
            check_command: "nut-tool-check".to_string(),
            shutdown_command: "nut-tool-shutdown".to_string(),
        }
    }
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct StateConfig {
    pub path: String,
}

impl Default for StateConfig {
    fn default() -> Self {
        Self {
            path: "/var/lib/nut-tool/state.json".to_string(),
        }
    }
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct HostConfig {
    pub name: String,
    pub address: String,
    pub ssh_port: u16,
    pub ssh_user: String,
    pub shutdown_enabled: bool,
    pub shutdown_priority: u32,
    pub shutdown_command: Option<String>,
    pub wake_enabled: bool,
    pub wake_priority: u32,
    pub mac: String,
    pub wol_destination: String,
    pub wake_check_address: Option<String>,
    pub wake_check_port: Option<u16>,
}

impl Default for HostConfig {
    fn default() -> Self {
        Self {
            name: String::new(),
            address: String::new(),
            ssh_port: 22,
            ssh_user: "ups-shutdown".to_string(),
            shutdown_enabled: true,
            shutdown_priority: 100,
            shutdown_command: None,
            wake_enabled: true,
            wake_priority: 100,
            mac: String::new(),
            wol_destination: "255.255.255.255:9".to_string(),
            wake_check_address: None,
            wake_check_port: None,
        }
    }
}
