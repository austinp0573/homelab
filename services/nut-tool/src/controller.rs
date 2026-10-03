use crate::{
    config::{Config, HostConfig},
    nut::{NutClient, UpsSnapshot},
    ssh::SshExecutor,
    state::{unix_now, PersistentState, Phase},
    wol,
};
use anyhow::{Context, Result};
use std::collections::BTreeMap;
use tokio::{
    signal::unix::{signal, SignalKind},
    task::JoinSet,
    time::{sleep, Duration, MissedTickBehavior},
};
use tracing::{debug, error, info, warn};

pub struct Controller {
    cfg: Config,
    nut: NutClient,
    ssh: SshExecutor,
    state: PersistentState,
    dry_run: bool,
    consecutive_nut_errors: u64,
}

impl Controller {
    pub fn new(cfg: Config, state: PersistentState, dry_run: bool) -> Self {
        Self {
            nut: NutClient::new(cfg.nut.clone()),
            ssh: SshExecutor::new(cfg.ssh.clone()),
            cfg,
            state: if dry_run {
                PersistentState::default()
            } else {
                state
            },
            dry_run,
            consecutive_nut_errors: 0,
        }
    }

    pub async fn run(&mut self) -> Result<()> {
        self.ssh.validate_local_files()?;

        if self.dry_run {
            warn!("DRY RUN enabled: SSH shutdown and WOL sends are simulated; state is not persisted");
        } else {
            // A process restart creates an observation gap. Never count that gap as
            // continuous stable mains before waking equipment. If we crashed while
            // actively waking, preserve per-host wake completion but return through
            // the recharge/stability gate before sending more packets.
            match self.state.phase {
                Phase::Recharging => {
                    self.state.mains_stable_since_unix = None;
                    self.persist()?;
                    warn!("process restart invalidated the persisted mains-stability timer");
                }
                Phase::Waking => {
                    self.state.phase = Phase::Recharging;
                    self.state.mains_stable_since_unix = None;
                    self.persist()?;
                    warn!("process restarted during WAKING; returning through the recharge/stability gate before resuming WOL");
                }
                _ => {}
            }
        }

        info!(
            nut = %self.cfg.nut.address,
            ups = %self.cfg.nut.ups_name,
            poll_seconds = self.cfg.policy.poll_interval_seconds,
            phase = ?self.state.phase,
            "controller starting"
        );

        let mut interval = tokio::time::interval(Duration::from_secs(
            self.cfg.policy.poll_interval_seconds,
        ));
        interval.set_missed_tick_behavior(MissedTickBehavior::Delay);

        let mut sigterm = signal(SignalKind::terminate()).context("failed to register SIGTERM handler")?;
        let ctrl_c = tokio::signal::ctrl_c();
        tokio::pin!(ctrl_c);

        loop {
            tokio::select! {
                _ = interval.tick() => {
                    self.tick().await?;
                }
                _ = sigterm.recv() => {
                    info!("received SIGTERM; exiting cleanly");
                    self.persist()?;
                    return Ok(());
                }
                result = &mut ctrl_c => {
                    result.context("failed waiting for Ctrl-C")?;
                    info!("received Ctrl-C; exiting cleanly");
                    self.persist()?;
                    return Ok(());
                }
            }
        }
    }

    async fn tick(&mut self) -> Result<()> {
        match self.nut.poll().await {
            Ok(snapshot) => {
                if self.consecutive_nut_errors > 0 {
                    info!(
                        failures = self.consecutive_nut_errors,
                        "NUT telemetry recovered"
                    );
                    self.consecutive_nut_errors = 0;
                }

                debug!(
                    phase = ?self.state.phase,
                    status = %snapshot.status_raw,
                    battery = snapshot.battery_charge,
                    runtime_seconds = ?snapshot.battery_runtime_seconds,
                    "UPS poll"
                );

                self.handle_snapshot(snapshot).await
            }
            Err(err) => self.handle_nut_error(err).await,
        }
    }

    async fn handle_snapshot(&mut self, snapshot: UpsSnapshot) -> Result<()> {
        // FSD is an explicit NUT forced-shutdown request. Honor it even if the
        // current status also says OL; a coordinated NUT shutdown can set FSD
        // independently of our custom OB/charge thresholds.
        if self.cfg.policy.honor_nut_fsd
            && snapshot.forced_shutdown
            && matches!(self.state.phase, Phase::Unknown | Phase::Online | Phase::OnBattery)
        {
            if self.state.phase == Phase::OnBattery {
                self.latch_and_shutdown("NUT_FSD").await?;
            } else {
                let now = unix_now();
                self.state.begin_forced_shutdown(now);
                self.persist()?;
                warn!(cycle_id = now, "SHUTDOWN LATCHED: NUT_FSD");
                self.execute_shutdown_sequence().await?;
            }
            return Ok(());
        }

        match self.state.phase {
            Phase::Unknown => {
                if snapshot.on_battery {
                    self.begin_outage()?;
                    self.evaluate_shutdown_trigger(&snapshot).await?;
                } else if snapshot.online {
                    self.transition_online()?;
                } else {
                    warn!(status = %snapshot.status_raw, "UPS state is not actionable");
                }
            }

            Phase::Online => {
                if snapshot.on_battery {
                    self.begin_outage()?;
                    self.evaluate_shutdown_trigger(&snapshot).await?;
                } else if snapshot.output_off {
                    warn!(status = %snapshot.status_raw, "UPS output reports OFF while controller is ONLINE");
                }
            }

            Phase::OnBattery => {
                if snapshot.online {
                    info!(
                        battery = snapshot.battery_charge,
                        "utility power returned before shutdown threshold; cancelling outage timer"
                    );
                    self.state.cancel_uncommitted_outage(unix_now());
                    self.persist()?;
                } else if snapshot.on_battery {
                    self.evaluate_shutdown_trigger(&snapshot).await?;
                }
            }

            Phase::ShuttingDown => {
                self.execute_shutdown_sequence().await?;
            }

            Phase::WaitingForMains => {
                if snapshot.online {
                    self.state.phase = Phase::Recharging;
                    self.state.mains_stable_since_unix = Some(unix_now());
                    self.persist()?;
                    info!(
                        battery = snapshot.battery_charge,
                        stable_seconds_required = self.cfg.policy.mains_stable_seconds,
                        "utility power returned; beginning mains-stability/recharge wait"
                    );
                }
            }

            Phase::Recharging => {
                if snapshot.on_battery {
                    warn!("utility power failed again before wake; returning to WAITING_FOR_MAINS");
                    self.state.phase = Phase::WaitingForMains;
                    self.state.mains_stable_since_unix = None;
                    self.persist()?;
                    return Ok(());
                }

                if snapshot.online {
                    let now = unix_now();
                    let stable_since = match self.state.mains_stable_since_unix {
                        Some(value) => value,
                        None => {
                            self.state.mains_stable_since_unix = Some(now);
                            self.persist()?;
                            now
                        }
                    };
                    let stable_for = now.saturating_sub(stable_since);

                    debug!(
                        stable_for_seconds = stable_for,
                        required_stable_seconds = self.cfg.policy.mains_stable_seconds,
                        battery = snapshot.battery_charge,
                        wake_battery = self.cfg.policy.wake_battery_percent,
                        "waiting to wake"
                    );

                    if stable_for >= self.cfg.policy.mains_stable_seconds
                        && snapshot.battery_charge >= self.cfg.policy.wake_battery_percent
                    {
                        self.state.phase = Phase::Waking;
                        self.persist()?;
                        info!(
                            battery = snapshot.battery_charge,
                            stable_for_seconds = stable_for,
                            "wake conditions satisfied"
                        );
                        self.execute_wake_sequence().await?;
                    }
                }
            }

            Phase::Waking => {
                if snapshot.on_battery {
                    warn!(
                        "power failed during/after wake activity; treating this as a new outage cycle"
                    );
                    self.begin_outage()?;
                    self.evaluate_shutdown_trigger(&snapshot).await?;
                } else if snapshot.online {
                    self.execute_wake_sequence().await?;
                }
            }
        }

        Ok(())
    }

    async fn handle_nut_error(&mut self, err: anyhow::Error) -> Result<()> {
        self.consecutive_nut_errors += 1;

        if self.consecutive_nut_errors == 1 || self.consecutive_nut_errors % 12 == 0 {
            error!(
                failures = self.consecutive_nut_errors,
                error = %format!("{err:#}"),
                phase = ?self.state.phase,
                "failed to retrieve trustworthy NUT telemetry"
            );
        }

        match self.state.phase {
            Phase::OnBattery
                if self
                    .cfg
                    .policy
                    .shutdown_on_nut_loss_after_confirmed_ob =>
            {
                let elapsed = self.outage_elapsed_seconds();
                let trigger_seconds = self.cfg.policy.time_on_battery_minutes.saturating_mul(60);
                if elapsed >= trigger_seconds {
                    warn!(
                        elapsed_seconds = elapsed,
                        "NUT telemetry is unavailable, but a previously confirmed outage has reached the configured time threshold"
                    );
                    self.latch_and_shutdown("time_on_battery while NUT telemetry unavailable")
                        .await?;
                }
            }

            Phase::ShuttingDown => {
                warn!("NUT is unavailable, but shutdown was already latched; continuing shutdown sequence");
                self.execute_shutdown_sequence().await?;
            }

            Phase::Recharging => {
                if self.state.mains_stable_since_unix.take().is_some() {
                    warn!("NUT telemetry gap invalidated the mains-stability timer");
                    self.persist()?;
                }
            }

            Phase::Waking => {
                warn!("NUT telemetry unavailable during WAKING; no additional WOL packets will be sent until telemetry recovers");
            }

            _ => {}
        }

        Ok(())
    }

    fn begin_outage(&mut self) -> Result<()> {
        let now = unix_now();
        self.state.begin_outage(now);
        self.persist()?;
        warn!(
            cycle_id = now,
            time_threshold_minutes = self.cfg.policy.time_on_battery_minutes,
            charge_threshold = self.cfg.policy.low_battery_percent,
            "UPS transitioned to ON_BATTERY"
        );
        Ok(())
    }

    fn transition_online(&mut self) -> Result<()> {
        self.state.phase = Phase::Online;
        self.state.cycle_id = None;
        self.state.outage_started_unix = None;
        self.state.mains_stable_since_unix = None;
        self.persist()?;
        info!("UPS is ONLINE");
        Ok(())
    }

    async fn evaluate_shutdown_trigger(&mut self, snapshot: &UpsSnapshot) -> Result<()> {
        let elapsed = self.outage_elapsed_seconds();
        let time_limit = self.cfg.policy.time_on_battery_minutes.saturating_mul(60);

        let mut reasons = Vec::new();
        if elapsed >= time_limit {
            reasons.push(format!(
                "time_on_battery={}s>={}s",
                elapsed, time_limit
            ));
        }
        if snapshot.battery_charge <= self.cfg.policy.low_battery_percent {
            reasons.push(format!(
                "battery_charge={:.1}%<={:.1}%",
                snapshot.battery_charge, self.cfg.policy.low_battery_percent
            ));
        }
        if self.cfg.policy.honor_nut_low_battery && snapshot.low_battery {
            reasons.push("NUT_LB".to_string());
        }
        if self.cfg.policy.honor_nut_fsd && snapshot.forced_shutdown {
            reasons.push("NUT_FSD".to_string());
        }

        if reasons.is_empty() {
            debug!(
                elapsed_seconds = elapsed,
                battery = snapshot.battery_charge,
                "shutdown threshold not reached"
            );
            return Ok(());
        }

        self.latch_and_shutdown(&reasons.join(", ")).await
    }

    async fn latch_and_shutdown(&mut self, reason: &str) -> Result<()> {
        if self.state.phase != Phase::ShuttingDown {
            self.state.phase = Phase::ShuttingDown;
            self.persist()?;
            warn!(reason = %reason, "SHUTDOWN LATCHED");
        }
        self.execute_shutdown_sequence().await
    }

    async fn execute_shutdown_sequence(&mut self) -> Result<()> {
        let max_passes = self.cfg.policy.max_shutdown_passes;

        for pass in 1..=max_passes {
            let pending = self.pending_shutdown_hosts();
            if pending.is_empty() {
                break;
            }

            warn!(
                pass,
                max_passes,
                hosts = pending.len(),
                "starting shutdown pass"
            );

            let mut by_priority: BTreeMap<u32, Vec<HostConfig>> = BTreeMap::new();
            for host in pending {
                by_priority
                    .entry(host.shutdown_priority)
                    .or_default()
                    .push(host);
            }

            for (priority, mut hosts) in by_priority {
                hosts.sort_by(|a, b| a.name.cmp(&b.name));
                info!(priority, hosts = hosts.len(), "processing shutdown priority group");

                for chunk in hosts.chunks(self.cfg.policy.max_concurrent_ssh) {
                    let mut tasks = JoinSet::new();

                    for host in chunk.iter().cloned() {
                        let ssh = self.ssh.clone();
                        let dry_run = self.dry_run;
                        tasks.spawn(async move {
                            let name = host.name.clone();
                            let result = if dry_run {
                                Ok(())
                            } else {
                                ssh.shutdown_host(&host).await
                            };
                            (name, result)
                        });
                    }

                    while let Some(joined) = tasks.join_next().await {
                        let (name, result) = joined.context("shutdown worker task panicked")?;
                        match result {
                            Ok(()) => {
                                if self.dry_run {
                                    warn!(host = %name, "DRY RUN: would send SSH shutdown command");
                                } else {
                                    info!(host = %name, "shutdown command accepted");
                                }
                                self.state.shutdown_completed.insert(name.clone());
                                self.state.shutdown_unresolved.remove(&name);
                            }
                            Err(err) => {
                                error!(
                                    host = %name,
                                    pass,
                                    error = %format!("{err:#}"),
                                    "shutdown attempt failed"
                                );
                                self.state.shutdown_unresolved.insert(name);
                            }
                        }
                        self.persist()?;
                    }
                }
            }

            if self.pending_shutdown_hosts().is_empty() {
                break;
            }

            if pass < max_passes {
                let delay = shutdown_backoff_seconds(
                    pass,
                    self.cfg.policy.shutdown_retry_initial_seconds,
                    self.cfg.policy.shutdown_retry_max_seconds,
                );
                warn!(delay_seconds = delay, "shutdown failures remain; circling back after delay");
                sleep(Duration::from_secs(delay)).await;
            }
        }

        let still_pending = self.pending_shutdown_hosts();
        self.state.shutdown_unresolved = still_pending.iter().map(|h| h.name.clone()).collect();
        self.persist()?;

        if !still_pending.is_empty() {
            error!(
                hosts = ?self.state.shutdown_unresolved,
                "shutdown retry budget exhausted for one or more hosts"
            );

            if !self
                .cfg
                .policy
                .continue_after_shutdown_retries_exhausted
            {
                warn!("strict shutdown failure policy is enabled; remaining in SHUTTING_DOWN and retrying on the next controller tick");
                return Ok(());
            }
        } else {
            info!("all configured shutdown hosts accepted their shutdown command");
        }

        self.state.phase = Phase::WaitingForMains;
        self.state.mains_stable_since_unix = None;
        self.persist()?;

        // Shutdown may have taken long enough that utility power has already returned.
        match self.nut.poll().await {
            Ok(snapshot) if snapshot.online => {
                self.state.phase = Phase::Recharging;
                self.state.mains_stable_since_unix = Some(unix_now());
                self.persist()?;
                info!(
                    battery = snapshot.battery_charge,
                    "utility power is already back; beginning recharge/stability wait"
                );
            }
            Ok(_) => {
                info!("shutdown phase complete; waiting for utility power to return");
            }
            Err(err) => {
                warn!(
                    error = %format!("{err:#}"),
                    "shutdown phase complete; NUT unavailable, so wake remains inhibited"
                );
            }
        }

        Ok(())
    }

    async fn execute_wake_sequence(&mut self) -> Result<()> {
        let priorities: Vec<u32> = {
            let mut values: Vec<u32> = self
                .cfg
                .hosts
                .iter()
                .filter(|h| h.wake_enabled)
                .map(|h| h.wake_priority)
                .collect();
            values.sort_unstable();
            values.dedup();
            values
        };

        for priority in priorities {
            for pass in 1..=self.cfg.policy.max_wake_passes {
                let mut pending: Vec<HostConfig> = self
                    .cfg
                    .hosts
                    .iter()
                    .filter(|h| {
                        h.wake_enabled
                            && h.wake_priority == priority
                            && !self.state.wake_completed.contains(&h.name)
                    })
                    .cloned()
                    .collect();
                pending.sort_by(|a, b| a.name.cmp(&b.name));

                if pending.is_empty() {
                    break;
                }

                match self.check_wake_safety().await? {
                    WakeSafety::Safe => {}
                    WakeSafety::TelemetryUnavailable => return Ok(()),
                    WakeSafety::PowerLost(snapshot) => {
                        warn!(
                            status = %snapshot.status_raw,
                            "utility power was lost during wake; beginning a new outage cycle"
                        );
                        self.begin_outage()?;
                        self.evaluate_shutdown_trigger(&snapshot).await?;
                        return Ok(());
                    }
                    WakeSafety::NeedsRecharge(snapshot) => {
                        warn!(
                            battery = snapshot.battery_charge,
                            "battery fell below wake threshold; returning to RECHARGING"
                        );
                        self.state.phase = Phase::Recharging;
                        self.state.mains_stable_since_unix = Some(unix_now());
                        self.persist()?;
                        return Ok(());
                    }
                }

                info!(priority, pass, hosts = pending.len(), "starting WOL pass");

                for host in &pending {
                    if self.dry_run {
                        warn!(
                            host = %host.name,
                            destination = %host.wol_destination,
                            "DRY RUN: would send WOL burst"
                        );
                        self.state.wake_completed.insert(host.name.clone());
                        self.state.wake_unresolved.remove(&host.name);
                        self.persist()?;
                        continue;
                    }

                    match wol::send_magic_burst(
                        host,
                        self.cfg.policy.wol_packets,
                        self.cfg.policy.wol_packet_interval_ms,
                    )
                    .await
                    {
                        Ok(()) => {
                            info!(
                                host = %host.name,
                                destination = %host.wol_destination,
                                packets = self.cfg.policy.wol_packets,
                                "WOL burst sent"
                            );
                            if host.wake_check_port.is_none() {
                                self.state.wake_completed.insert(host.name.clone());
                                self.state.wake_unresolved.remove(&host.name);
                                self.persist()?;
                            }
                        }
                        Err(err) => {
                            error!(
                                host = %host.name,
                                error = %format!("{err:#}"),
                                "failed to send WOL burst"
                            );
                            self.state.wake_unresolved.insert(host.name.clone());
                            self.persist()?;
                        }
                    }
                }

                let needs_probe = pending.iter().any(|h| {
                    h.wake_check_port.is_some() && !self.state.wake_completed.contains(&h.name)
                });

                if needs_probe {
                    sleep(Duration::from_secs(self.cfg.policy.wake_probe_delay_seconds)).await;

                    for host in &pending {
                        if host.wake_check_port.is_none()
                            || self.state.wake_completed.contains(&host.name)
                        {
                            continue;
                        }

                        match wol::tcp_probe(host, self.cfg.policy.wake_connect_timeout_seconds).await {
                            Ok(true) => {
                                info!(
                                    host = %host.name,
                                    port = ?host.wake_check_port,
                                    "wake probe succeeded"
                                );
                                self.state.wake_completed.insert(host.name.clone());
                                self.state.wake_unresolved.remove(&host.name);
                            }
                            Ok(false) => {
                                warn!(
                                    host = %host.name,
                                    port = ?host.wake_check_port,
                                    "host is not reachable on wake-check port yet"
                                );
                                self.state.wake_unresolved.insert(host.name.clone());
                            }
                            Err(err) => {
                                warn!(
                                    host = %host.name,
                                    error = %format!("{err:#}"),
                                    "wake probe failed"
                                );
                                self.state.wake_unresolved.insert(host.name.clone());
                            }
                        }
                        self.persist()?;
                    }
                }

                let remaining_in_priority = self.cfg.hosts.iter().any(|h| {
                    h.wake_enabled
                        && h.wake_priority == priority
                        && !self.state.wake_completed.contains(&h.name)
                });
                if !remaining_in_priority {
                    break;
                }

                if pass < self.cfg.policy.max_wake_passes {
                    sleep(Duration::from_secs(self.cfg.policy.wake_retry_seconds)).await;
                }
            }

            let unresolved_priority: Vec<String> = self
                .cfg
                .hosts
                .iter()
                .filter(|h| {
                    h.wake_enabled
                        && h.wake_priority == priority
                        && !self.state.wake_completed.contains(&h.name)
                })
                .map(|h| h.name.clone())
                .collect();

            for name in &unresolved_priority {
                self.state.wake_unresolved.insert(name.clone());
            }
            self.persist()?;

            if !unresolved_priority.is_empty() {
                error!(
                    priority,
                    hosts = ?unresolved_priority,
                    "wake retry budget exhausted for priority group"
                );
                if !self.cfg.policy.continue_after_wake_retries_exhausted {
                    warn!("strict wake failure policy is enabled; remaining in WAKING and retrying on a later controller tick");
                    return Ok(());
                }
            }
        }

        let now = unix_now();
        let wake_failures = self.state.wake_unresolved.clone();
        let shutdown_failures = self.state.shutdown_unresolved.clone();
        self.state.complete_cycle(now);
        self.persist()?;

        if wake_failures.is_empty() && shutdown_failures.is_empty() {
            info!("UPS outage cycle completed successfully");
        } else {
            warn!(
                shutdown_unresolved = ?shutdown_failures,
                wake_unresolved = ?wake_failures,
                "UPS outage cycle completed with unresolved hosts"
            );
        }

        Ok(())
    }

    async fn check_wake_safety(&mut self) -> Result<WakeSafety> {
        match self.nut.poll().await {
            Ok(snapshot) if snapshot.on_battery => Ok(WakeSafety::PowerLost(snapshot)),
            Ok(snapshot) if !snapshot.online => {
                warn!(status = %snapshot.status_raw, "UPS is not definitively OL; wake inhibited");
                Ok(WakeSafety::TelemetryUnavailable)
            }
            Ok(snapshot)
                if snapshot.battery_charge < self.cfg.policy.wake_battery_percent =>
            {
                Ok(WakeSafety::NeedsRecharge(snapshot))
            }
            Ok(_) => Ok(WakeSafety::Safe),
            Err(err) => {
                warn!(
                    error = %format!("{err:#}"),
                    "could not verify NUT state immediately before WOL; wake inhibited"
                );
                Ok(WakeSafety::TelemetryUnavailable)
            }
        }
    }

    fn pending_shutdown_hosts(&self) -> Vec<HostConfig> {
        let mut pending: Vec<HostConfig> = self
            .cfg
            .hosts
            .iter()
            .filter(|h| h.shutdown_enabled && !self.state.shutdown_completed.contains(&h.name))
            .cloned()
            .collect();
        pending.sort_by(|a, b| {
            a.shutdown_priority
                .cmp(&b.shutdown_priority)
                .then_with(|| a.name.cmp(&b.name))
        });
        pending
    }

    fn outage_elapsed_seconds(&self) -> u64 {
        self.state
            .outage_started_unix
            .map(|started| unix_now().saturating_sub(started))
            .unwrap_or(0)
    }

    fn persist(&mut self) -> Result<()> {
        if self.dry_run {
            return Ok(());
        }
        self.state.save_atomic(&self.cfg.state_path())
    }

    pub fn state(&self) -> &PersistentState {
        &self.state
    }
}

fn shutdown_backoff_seconds(pass: u32, initial: u64, maximum: u64) -> u64 {
    let shift = pass.saturating_sub(1).min(20);
    initial.saturating_mul(1u64 << shift).min(maximum)
}

enum WakeSafety {
    Safe,
    TelemetryUnavailable,
    PowerLost(UpsSnapshot),
    NeedsRecharge(UpsSnapshot),
}
