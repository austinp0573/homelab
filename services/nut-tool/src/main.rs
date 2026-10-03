mod config;
mod controller;
mod nut;
mod ssh;
mod state;
mod wol;

use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};
use config::Config;
use controller::Controller;
use nut::NutClient;
use ssh::SshExecutor;
use state::PersistentState;
use std::{fs, path::PathBuf};
use tracing::{error, info};
use tracing_subscriber::EnvFilter;

#[derive(Debug, Parser)]
#[command(name = "nut-tool", version, about = "NUT-driven UPS shutdown and Wake-on-LAN orchestrator")]
struct Cli {
    /// TOML configuration file.
    #[arg(long, global = true, default_value = "/etc/nut-tool/config.toml")]
    config: PathBuf,

    /// Override configured minutes continuously on battery before shutdown.
    #[arg(long, global = true)]
    time_on_battery: Option<u64>,

    /// Override configured battery percentage at/below which shutdown is triggered.
    #[arg(long, global = true)]
    low_battery_percent: Option<f64>,

    /// Override configured battery percentage required before Wake-on-LAN.
    #[arg(long, global = true)]
    wake_battery_percent: Option<f64>,

    /// Simulate shutdown/WOL actions and do not write persistent state.
    #[arg(long, global = true)]
    dry_run: bool,

    #[command(subcommand)]
    command: Option<Command>,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Run the long-lived controller. This is the default when no subcommand is given.
    Run,

    /// Validate config, NUT telemetry, local SSH files, and optionally remote SSH gates.
    Check {
        /// Skip connecting to configured SSH targets.
        #[arg(long)]
        skip_ssh: bool,
    },

    /// Print the persisted controller state and a current NUT snapshot.
    Status,

    /// Execute the configured harmless SSH check command on one host.
    TestSsh {
        host: String,
    },

    /// Manually send the configured WOL burst to one host.
    Wake {
        host: String,
    },

    /// Delete persistent state. Intended only for deliberate administrative recovery.
    ResetState {
        /// Required acknowledgement.
        #[arg(long)]
        yes: bool,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    init_tracing();
    let cli = Cli::parse();

    let mut cfg = Config::load(&cli.config)?;
    apply_cli_overrides(&cli, &mut cfg);
    cfg.validate()?;

    match cli.command.unwrap_or(Command::Run) {
        Command::Run => {
            let state = PersistentState::load(&cfg.state_path())?;
            let mut controller = Controller::new(cfg, state, cli.dry_run);
            controller.run().await
        }

        Command::Check { skip_ssh } => check(&cfg, skip_ssh).await,

        Command::Status => status(&cfg).await,

        Command::TestSsh { host } => {
            let host = cfg.host(&host)?;
            let ssh = SshExecutor::new(cfg.ssh.clone());
            ssh.validate_local_files()?;
            ssh.test_host(host).await?;
            println!("{}: SSH check succeeded", host.name);
            Ok(())
        }

        Command::Wake { host } => {
            let host = cfg.host(&host)?;
            if !host.wake_enabled {
                bail!("host {} has wake_enabled=false", host.name);
            }
            if cli.dry_run {
                println!(
                    "DRY RUN: would send {} WOL packets for {} to {}",
                    cfg.policy.wol_packets, host.name, host.wol_destination
                );
                return Ok(());
            }
            wol::send_magic_burst(
                host,
                cfg.policy.wol_packets,
                cfg.policy.wol_packet_interval_ms,
            )
            .await?;
            println!("{}: WOL burst sent", host.name);
            Ok(())
        }

        Command::ResetState { yes } => {
            if !yes {
                bail!("refusing to delete state without --yes");
            }
            let path = cfg.state_path();
            match fs::remove_file(&path) {
                Ok(()) => println!("deleted {}", path.display()),
                Err(err) if err.kind() == std::io::ErrorKind::NotFound => {
                    println!("{} does not exist", path.display())
                }
                Err(err) => {
                    return Err(err)
                        .with_context(|| format!("failed to delete {}", path.display()));
                }
            }
            Ok(())
        }
    }
}

fn init_tracing() {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_target(false)
        .compact()
        .init();
}

fn apply_cli_overrides(cli: &Cli, cfg: &mut Config) {
    if let Some(value) = cli.time_on_battery {
        cfg.policy.time_on_battery_minutes = value;
    }
    if let Some(value) = cli.low_battery_percent {
        cfg.policy.low_battery_percent = value;
    }
    if let Some(value) = cli.wake_battery_percent {
        cfg.policy.wake_battery_percent = value;
    }
}

async fn check(cfg: &Config, skip_ssh: bool) -> Result<()> {
    println!("Configuration: OK");

    let nut = NutClient::new(cfg.nut.clone());
    let snapshot = nut.poll().await.context("NUT check failed")?;
    println!(
        "NUT: OK  status={} battery={:.1}% runtime={}s",
        snapshot.status_raw,
        snapshot.battery_charge,
        snapshot
            .battery_runtime_seconds
            .map(|v| v.to_string())
            .unwrap_or_else(|| "n/a".to_string())
    );

    let ssh = SshExecutor::new(cfg.ssh.clone());
    ssh.validate_local_files()?;
    println!("SSH local files: OK");

    if !skip_ssh {
        let mut failures = 0usize;
        for host in cfg.hosts.iter().filter(|h| h.shutdown_enabled) {
            match ssh.test_host(host).await {
                Ok(()) => println!("SSH {}: OK", host.name),
                Err(err) => {
                    failures += 1;
                    error!(host = %host.name, error = %format!("{err:#}"), "SSH check failed");
                    println!("SSH {}: FAILED: {err:#}", host.name);
                }
            }
        }
        if failures > 0 {
            bail!("{failures} SSH target(s) failed validation");
        }
    }

    for host in cfg.hosts.iter().filter(|h| h.wake_enabled) {
        config::parse_mac(&host.mac)?;
        println!(
            "WOL {}: config OK  mac={} destination={} probe={}",
            host.name,
            host.mac,
            host.wol_destination,
            host.wake_check_port
                .map(|p| p.to_string())
                .unwrap_or_else(|| "disabled".to_string())
        );
    }

    info!("all requested checks passed");
    Ok(())
}

async fn status(cfg: &Config) -> Result<()> {
    let state = PersistentState::load(&cfg.state_path())?;
    println!("Persistent controller state:");
    println!("{}", serde_json::to_string_pretty(&state)?);

    println!();
    println!("Current UPS snapshot:");
    let nut = NutClient::new(cfg.nut.clone());
    match nut.poll().await {
        Ok(snapshot) => {
            println!("status:          {}", snapshot.status_raw);
            println!("battery:         {:.1}%", snapshot.battery_charge);
            println!(
                "runtime:         {}",
                snapshot
                    .battery_runtime_seconds
                    .map(|v| format!("{v}s"))
                    .unwrap_or_else(|| "n/a".to_string())
            );
            println!("online:           {}", snapshot.online);
            println!("on_battery:       {}", snapshot.on_battery);
            println!("low_battery:      {}", snapshot.low_battery);
            println!("forced_shutdown:  {}", snapshot.forced_shutdown);
            println!("output_off:       {}", snapshot.output_off);
        }
        Err(err) => {
            println!("NUT ERROR: {err:#}");
        }
    }

    Ok(())
}
