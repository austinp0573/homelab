export const STORAGE_KEY = "gen-restic-draft";

export const DEFAULT_INCLUDES = `# paths to back up in the host profile
# these are paths inside the container, where the host is mounted at /host

/host/etc
/host/home
/host/root
/host/srv
/host/opt
`;

export const DEFAULT_EXCLUDES = `# paths as seen inside the container (/ mounted at /host)

# virtual filesystems and runtime
/host/dev
/host/proc
/host/sys
/host/tmp
/host/run
/host/lost+found

# mounted storage is normally backed up by its own job
/host/mnt

# bulk media usually has its own backup policy
/host/media

# caches and package noise
/host/var/cache
/host/var/tmp
/host/var/lib/docker
/host/var/lib/containerd
/host/var/lib/nerdctl
/host/var/lib/libvirt

# restic local cache
/host/var/cache/restic

# the deployed template contains backup secrets and staged application copies
/host/opt/restic-client

# user caches
/host/home/*/.cache
/host/home/*/.local/share/Trash
/host/root/.cache

# common junk
**/.DS_Store
**/node_modules
**/.git
`;

export function emptySecrets() {
  return {
    repo_location: "",
    password: "",
    rest_username: "",
    rest_password: "",
    aws_credentials: "",
    ntfy_token: "",
    ca_cert: "",
  };
}

export function defaultCompose() {
  return {
    image: "restic/restic:0.19.1",
    container_name: "restic",
    restart: "no",
    host_mount: "${HOST_ROOT:-/}",
    excludes_file: "./excludes.txt",
    includes_file: "./includes.txt",
    secrets_dir: "./secrets",
    certs_dir: "./certs",
    staging_dir: "./staging",
    staging_app_dir: "./staging/app",
    cache_dir: "/var/cache/restic",
  };
}

export function defaultPrune() {
  return {
    enabled: false,
    repo_path: "/mnt/coldpool/restic/admin/sample-host",
    password_file: "/root/restic-password.txt",
    image: "restic/restic:0.19.1",
    runtime: "docker",
    keep_daily: "7",
    keep_weekly: "4",
    keep_monthly: "12",
    keep_yearly: "2",
    check_args: "--read-data-subset=5%",
  };
}

export function defaultEnv() {
  return {
    // profile
    BACKUP_MODE: "host",
    HOST_ROOT: "/",
    APP_SOURCE_DIR: "/srv/example-app",
    BACKUP_NAME: "example-app",
    SQLITE_DB: "/srv/example-app/db.sqlite3",
    STAGE_DEST: "./staging/app/example-app",

    RESTIC_HOST: "example-host",
    COMPOSE_CMD: "nerdctl compose",

    HEALTHCHECKS_URL: "",
    NTFY_URL: "https://ntfy.sh",
    NTFY_TOPIC: "",
    NTFY_TOKEN_FILE: "",

    REST_USERNAME_FILE: "",
    REST_PASSWORD_FILE: "",
    RESTIC_REST_USERNAME: "",
    RESTIC_REST_PASSWORD: "",

    RESTIC_CACERT: "",
    RESTIC_TLS_CLIENT_CERT: "",
    RESTIC_INSECURE_TLS: "",

    RESTIC_KEY_HINT: "",
    RESTIC_COMPRESSION: "auto",
    RESTIC_PACK_SIZE: "64",
    RESTIC_READ_CONCURRENCY: "",
    RESTIC_PROGRESS_FPS: "",
    RESTIC_NO_CACHE: "",

    RESTIC_REPOSITORY: "",
    RESTIC_REPOSITORY_FILE: "",
    RESTIC_PASSWORD_FILE: "",
    RESTIC_PASSWORD: "",
    RESTIC_PASSWORD_COMMAND: "",

    AWS_SHARED_CREDENTIALS_FILE: "",
    AWS_PROFILE: "",
    AWS_DEFAULT_REGION: "",
    AWS_ACCESS_KEY_ID: "",
    AWS_SECRET_ACCESS_KEY: "",
    AWS_SESSION_TOKEN: "",
    RESTIC_AWS_ASSUME_ROLE_ARN: "",
    RESTIC_AWS_ASSUME_ROLE_SESSION_NAME: "",
    RESTIC_AWS_ASSUME_ROLE_EXTERNAL_ID: "",
    RESTIC_AWS_ASSUME_ROLE_POLICY: "",
    RESTIC_AWS_ASSUME_ROLE_REGION: "",
    RESTIC_AWS_ASSUME_ROLE_STS_ENDPOINT: "",

    RESTIC_FROM_REPOSITORY: "",
    RESTIC_FROM_REPOSITORY_FILE: "",
    RESTIC_FROM_PASSWORD: "",
    RESTIC_FROM_PASSWORD_FILE: "",
    RESTIC_FROM_PASSWORD_COMMAND: "",
    RESTIC_FROM_KEY_HINT: "",

    AZURE_ACCOUNT_NAME: "",
    AZURE_ACCOUNT_KEY: "",
    AZURE_ACCOUNT_SAS: "",
    AZURE_ENDPOINT_SUFFIX: "",
    AZURE_FORCE_CLI_CREDENTIAL: "",

    B2_ACCOUNT_ID: "",
    B2_ACCOUNT_KEY: "",

    GOOGLE_PROJECT_ID: "",
    GOOGLE_APPLICATION_CREDENTIALS: "",
    GOOGLE_ACCESS_TOKEN: "",

    OS_AUTH_URL: "",
    OS_REGION_NAME: "",
    OS_USERNAME: "",
    OS_USER_ID: "",
    OS_PASSWORD: "",
    OS_TENANT_ID: "",
    OS_TENANT_NAME: "",
    OS_USER_DOMAIN_NAME: "",
    OS_USER_DOMAIN_ID: "",
    OS_PROJECT_NAME: "",
    OS_PROJECT_DOMAIN_NAME: "",
    OS_PROJECT_DOMAIN_ID: "",
    OS_TRUST_ID: "",
    OS_APPLICATION_CREDENTIAL_ID: "",
    OS_APPLICATION_CREDENTIAL_NAME: "",
    OS_APPLICATION_CREDENTIAL_SECRET: "",
    OS_STORAGE_URL: "",
    OS_AUTH_TOKEN: "",
    ST_AUTH: "",
    ST_USER: "",
    ST_KEY: "",

    RCLONE_BWLIMIT: "",
  };
}

export function defaultOptions() {
  return {
    use_rest_auth: false,
    use_aws_credentials_file: false,
    use_ntfy_token: false,
    use_ca_cert: false,
    ca_cert_filename: "truenas-ca.crt",
    backend: "rest",
  };
}

export function emptyDraft() {
  return {
    profile: "host",
    env: defaultEnv(),
    includes: DEFAULT_INCLUDES,
    excludes: DEFAULT_EXCLUDES,
    compose: defaultCompose(),
    prune: defaultPrune(),
    options: defaultOptions(),
  };
}

export function applyProfileDefaults(draft, profile) {
  const next = structuredClone(draft);
  next.profile = profile;
  if (profile === "host") {
    next.env.BACKUP_MODE = "host";
    next.env.HOST_ROOT = "/";
  } else if (profile === "app") {
    next.env.BACKUP_MODE = "app";
    next.env.HOST_ROOT = "./empty-host";
  } else if (profile === "sqlite") {
    next.env.BACKUP_MODE = "";
    next.env.HOST_ROOT = "./empty-host";
  }
  return next;
}
