use crate::config::{parse_mac, HostConfig};
use anyhow::{Context, Result};
use tokio::{
    net::{TcpStream, UdpSocket},
    time::{sleep, timeout, Duration},
};

pub fn magic_packet(mac: [u8; 6]) -> [u8; 102] {
    let mut packet = [0u8; 102];
    packet[..6].fill(0xff);
    for i in 0..16 {
        let start = 6 + i * 6;
        packet[start..start + 6].copy_from_slice(&mac);
    }
    packet
}

pub async fn send_magic_burst(
    host: &HostConfig,
    packet_count: usize,
    interval_ms: u64,
) -> Result<()> {
    let mac = parse_mac(&host.mac)?;
    let packet = magic_packet(mac);

    let socket = UdpSocket::bind("0.0.0.0:0")
        .await
        .context("failed to bind WOL UDP socket")?;
    socket
        .set_broadcast(true)
        .context("failed to enable UDP broadcast")?;

    for n in 0..packet_count {
        socket
            .send_to(&packet, &host.wol_destination)
            .await
            .with_context(|| {
                format!(
                    "failed to send WOL packet for {} to {}",
                    host.name, host.wol_destination
                )
            })?;

        if n + 1 < packet_count && interval_ms > 0 {
            sleep(Duration::from_millis(interval_ms)).await;
        }
    }

    Ok(())
}

pub async fn tcp_probe(host: &HostConfig, timeout_seconds: u64) -> Result<bool> {
    let Some(port) = host.wake_check_port else {
        return Ok(true);
    };

    let address = host
        .wake_check_address
        .as_deref()
        .unwrap_or(&host.address);

    let result = timeout(
        Duration::from_secs(timeout_seconds),
        TcpStream::connect((address, port)),
    )
    .await;

    Ok(matches!(result, Ok(Ok(_))))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn constructs_magic_packet() {
        let mac = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55];
        let packet = magic_packet(mac);
        assert_eq!(&packet[..6], &[0xff; 6]);
        for i in 0..16 {
            let start = 6 + i * 6;
            assert_eq!(&packet[start..start + 6], &mac);
        }
    }
}
