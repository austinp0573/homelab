use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};
use std::{
    collections::BTreeSet,
    fs::{self, File, OpenOptions},
    io::Write,
    os::unix::fs::PermissionsExt,
    path::Path,
    time::{SystemTime, UNIX_EPOCH},
};

pub const STATE_VERSION: u32 = 1;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Phase {
    Unknown,
    Online,
    OnBattery,
    ShuttingDown,
    WaitingForMains,
    Recharging,
    Waking,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PersistentState {
    pub version: u32,
    pub phase: Phase,
    pub cycle_id: Option<u64>,
    pub outage_started_unix: Option<u64>,
    pub mains_stable_since_unix: Option<u64>,
    pub shutdown_completed: BTreeSet<String>,
    pub shutdown_unresolved: BTreeSet<String>,
    pub wake_completed: BTreeSet<String>,
    pub wake_unresolved: BTreeSet<String>,
    pub last_error: Option<String>,
    pub last_updated_unix: u64,
    pub last_cycle_completed_unix: Option<u64>,
    pub last_cycle_shutdown_unresolved: Vec<String>,
    pub last_cycle_wake_unresolved: Vec<String>,
}

impl Default for PersistentState {
    fn default() -> Self {
        Self {
            version: STATE_VERSION,
            phase: Phase::Unknown,
            cycle_id: None,
            outage_started_unix: None,
            mains_stable_since_unix: None,
            shutdown_completed: BTreeSet::new(),
            shutdown_unresolved: BTreeSet::new(),
            wake_completed: BTreeSet::new(),
            wake_unresolved: BTreeSet::new(),
            last_error: None,
            last_updated_unix: unix_now(),
            last_cycle_completed_unix: None,
            last_cycle_shutdown_unresolved: Vec::new(),
            last_cycle_wake_unresolved: Vec::new(),
        }
    }
}

impl PersistentState {
    pub fn load(path: &Path) -> Result<Self> {
        if !path.exists() {
            return Ok(Self::default());
        }

        let file = File::open(path)
            .with_context(|| format!("failed to open state file {}", path.display()))?;
        let state: Self = serde_json::from_reader(file)
            .with_context(|| format!("state file {} is corrupt or incompatible", path.display()))?;

        if state.version != STATE_VERSION {
            bail!(
                "unsupported state version {} in {}; expected {}",
                state.version,
                path.display(),
                STATE_VERSION
            );
        }

        Ok(state)
    }

    pub fn begin_outage(&mut self, now: u64) {
        self.phase = Phase::OnBattery;
        self.cycle_id = Some(now);
        self.outage_started_unix = Some(now);
        self.mains_stable_since_unix = None;
        self.shutdown_completed.clear();
        self.shutdown_unresolved.clear();
        self.wake_completed.clear();
        self.wake_unresolved.clear();
        self.last_error = None;
        self.touch(now);
    }


    pub fn begin_forced_shutdown(&mut self, now: u64) {
        self.phase = Phase::ShuttingDown;
        self.cycle_id = Some(now);
        self.outage_started_unix = Some(now);
        self.mains_stable_since_unix = None;
        self.shutdown_completed.clear();
        self.shutdown_unresolved.clear();
        self.wake_completed.clear();
        self.wake_unresolved.clear();
        self.last_error = None;
        self.touch(now);
    }

    pub fn cancel_uncommitted_outage(&mut self, now: u64) {
        self.phase = Phase::Online;
        self.cycle_id = None;
        self.outage_started_unix = None;
        self.mains_stable_since_unix = None;
        self.shutdown_completed.clear();
        self.shutdown_unresolved.clear();
        self.wake_completed.clear();
        self.wake_unresolved.clear();
        self.last_error = None;
        self.touch(now);
    }

    pub fn complete_cycle(&mut self, now: u64) {
        self.last_cycle_shutdown_unresolved = self.shutdown_unresolved.iter().cloned().collect();
        self.last_cycle_wake_unresolved = self.wake_unresolved.iter().cloned().collect();
        self.last_cycle_completed_unix = Some(now);

        self.phase = Phase::Online;
        self.cycle_id = None;
        self.outage_started_unix = None;
        self.mains_stable_since_unix = None;
        self.shutdown_completed.clear();
        self.shutdown_unresolved.clear();
        self.wake_completed.clear();
        self.wake_unresolved.clear();
        self.last_error = None;
        self.touch(now);
    }

    pub fn touch(&mut self, now: u64) {
        self.last_updated_unix = now;
    }

    pub fn save_atomic(&mut self, path: &Path) -> Result<()> {
        let now = unix_now();
        self.touch(now);

        let parent = path
            .parent()
            .context("state path has no parent directory")?;
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create state directory {}", parent.display()))?;
        fs::set_permissions(parent, fs::Permissions::from_mode(0o750))
            .with_context(|| format!("failed to set permissions on {}", parent.display()))?;

        let file_name = path
            .file_name()
            .and_then(|s| s.to_str())
            .context("state path has an invalid file name")?;
        let tmp_path = parent.join(format!(".{file_name}.tmp.{}", std::process::id()));

        let serialized = serde_json::to_vec_pretty(self).context("failed to serialize state")?;

        let mut tmp = OpenOptions::new()
            .create(true)
            .truncate(true)
            .write(true)
            .mode(0o600)
            .open(&tmp_path)
            .with_context(|| format!("failed to create temporary state file {}", tmp_path.display()))?;

        tmp.write_all(&serialized)
            .with_context(|| format!("failed to write {}", tmp_path.display()))?;
        tmp.write_all(b"\n")
            .with_context(|| format!("failed to finalize {}", tmp_path.display()))?;
        tmp.sync_all()
            .with_context(|| format!("failed to fsync {}", tmp_path.display()))?;
        drop(tmp);

        fs::rename(&tmp_path, path).with_context(|| {
            format!(
                "failed to atomically replace {} with {}",
                path.display(),
                tmp_path.display()
            )
        })?;

        File::open(parent)
            .with_context(|| format!("failed to open state directory {} for fsync", parent.display()))?
            .sync_all()
            .with_context(|| format!("failed to fsync state directory {}", parent.display()))?;

        Ok(())
    }
}

pub fn unix_now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}
