use crate::config::{HostConfig, SshConfig};
use anyhow::{bail, Context, Result};
use async_ssh2_tokio::client::{AuthMethod, Client, ServerCheckMethod};
use std::{fs, os::unix::fs::PermissionsExt, path::Path};
use tokio::time::{timeout, Duration};

#[derive(Debug, Clone)]
pub struct SshExecutor {
    cfg: SshConfig,
}

impl SshExecutor {
    pub fn new(cfg: SshConfig) -> Self {
        Self { cfg }
    }

    pub fn validate_local_files(&self) -> Result<()> {
        let key = Path::new(&self.cfg.private_key);
        let known_hosts = Path::new(&self.cfg.known_hosts);

        let key_meta = fs::metadata(key)
            .with_context(|| format!("failed to stat SSH private key {}", key.display()))?;
        if !key_meta.is_file() {
            bail!("SSH private key is not a regular file: {}", key.display());
        }
        let mode = key_meta.permissions().mode() & 0o777;
        if mode & 0o077 != 0 {
            bail!(
                "SSH private key {} is too permissive ({mode:o}); use mode 0600 or 0400",
                key.display()
            );
        }

        let known_meta = fs::metadata(known_hosts)
            .with_context(|| format!("failed to stat known_hosts {}", known_hosts.display()))?;
        if !known_meta.is_file() {
            bail!("known_hosts is not a regular file: {}", known_hosts.display());
        }

        Ok(())
    }

    pub async fn test_host(&self, host: &HostConfig) -> Result<()> {
        self.execute(host, &self.cfg.check_command).await
    }

    pub async fn shutdown_host(&self, host: &HostConfig) -> Result<()> {
        let command = host
            .shutdown_command
            .as_deref()
            .unwrap_or(&self.cfg.shutdown_command);
        self.execute(host, command).await
    }

    async fn execute(&self, host: &HostConfig, command: &str) -> Result<()> {
        let auth = AuthMethod::with_key_file(&self.cfg.private_key, None);
        let server_check = ServerCheckMethod::with_known_hosts_file(&self.cfg.known_hosts);
        let connect_timeout = Duration::from_secs(self.cfg.connect_timeout_seconds);
        let command_timeout = Duration::from_secs(self.cfg.command_timeout_seconds);

        let connect = Client::connect(
            (host.address.as_str(), host.ssh_port),
            &host.ssh_user,
            auth,
            server_check,
        );

        let mut client = timeout(connect_timeout, connect)
            .await
            .with_context(|| format!("SSH connect to {} timed out", host.name))?
            .with_context(|| format!("SSH connect/auth/host-key check failed for {}", host.name))?;

        let result = timeout(command_timeout, client.execute(command))
            .await
            .with_context(|| format!("SSH command on {} timed out", host.name))?
            .with_context(|| format!("SSH command transport failed on {}", host.name))?;

        if result.exit_status != 0 {
            let stderr = result.stderr.trim();
            if stderr.is_empty() {
                bail!(
                    "SSH command on {} exited with status {}",
                    host.name,
                    result.exit_status
                );
            }
            bail!(
                "SSH command on {} exited with status {}: {}",
                host.name,
                result.exit_status,
                stderr
            );
        }

        Ok(())
    }
}
