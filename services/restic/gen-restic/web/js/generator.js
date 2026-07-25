function line(key, value, { comment = false } = {}) {
  if (value === undefined || value === null || value === "") {
    return comment ? `# ${key}=` : null;
  }
  const body = `${key}=${value}`;
  return comment ? `# ${body}` : body;
}

function push(lines, item) {
  if (item === null || item === undefined) return;
  if (Array.isArray(item)) {
    for (const x of item) push(lines, x);
    return;
  }
  lines.push(item);
}

function section(lines, title) {
  lines.push("");
  lines.push(`# ${title}`);
}

function emitAssigned(lines, env, keys) {
  for (const key of keys) {
    const item = line(key, env[key]);
    if (item) lines.push(item);
  }
}

function emitOptionalBlock(lines, title, env, keys) {
  const present = keys.some((k) => env[k]);
  if (!present) return;
  section(lines, title);
  emitAssigned(lines, env, keys);
}

/**
 * Build .env text for the current draft.
 */
export function emitEnv(draft) {
  const { profile, env, options } = draft;
  const lines = [];

  if (profile === "host") {
    lines.push("# host profile");
    lines.push("BACKUP_MODE=host");
    lines.push(`HOST_ROOT=${env.HOST_ROOT || "/"}`);
  } else if (profile === "app") {
    lines.push("# app profile");
    lines.push("BACKUP_MODE=app");
    lines.push(`HOST_ROOT=${env.HOST_ROOT || "./empty-host"}`);
    lines.push(`APP_SOURCE_DIR=${env.APP_SOURCE_DIR || "/srv/example-app"}`);
    lines.push(`BACKUP_NAME=${env.BACKUP_NAME || "example-app"}`);
  } else {
    lines.push("# sqlite-only profile");
    lines.push(`HOST_ROOT=${env.HOST_ROOT || "./empty-host"}`);
    lines.push(`SQLITE_DB=${env.SQLITE_DB || ""}`);
    lines.push(`STAGE_DEST=${env.STAGE_DEST || "./staging/app/example-app"}`);
  }

  section(lines, "snapshot host name. keep this stable.");
  lines.push(`RESTIC_HOST=${env.RESTIC_HOST || "example-host"}`);

  section(lines, "compose command on this host");
  lines.push(`COMPOSE_CMD=${env.COMPOSE_CMD || "nerdctl compose"}`);

  section(lines, "notifications");
  push(lines, line("HEALTHCHECKS_URL", env.HEALTHCHECKS_URL, { comment: !env.HEALTHCHECKS_URL }));
  lines.push(`NTFY_URL=${env.NTFY_URL || "https://ntfy.sh"}`);
  push(lines, line("NTFY_TOPIC", env.NTFY_TOPIC, { comment: !env.NTFY_TOPIC }));
  if (options.use_ntfy_token) {
    lines.push(`NTFY_TOKEN_FILE=${env.NTFY_TOKEN_FILE || "./secrets/ntfy_token.txt"}`);
  } else {
    push(lines, line("NTFY_TOKEN_FILE", env.NTFY_TOKEN_FILE, { comment: true }));
  }

  if (options.use_rest_auth || options.backend === "rest") {
    section(lines, "rest server auth");
    if (options.use_rest_auth) {
      lines.push(`REST_USERNAME_FILE=${env.REST_USERNAME_FILE || "./secrets/rest_username.txt"}`);
      lines.push(`REST_PASSWORD_FILE=${env.REST_PASSWORD_FILE || "./secrets/rest_password.txt"}`);
    } else {
      push(lines, line("REST_USERNAME_FILE", env.REST_USERNAME_FILE, { comment: true }));
      push(lines, line("REST_PASSWORD_FILE", env.REST_PASSWORD_FILE, { comment: true }));
    }
    push(lines, line("RESTIC_REST_USERNAME", env.RESTIC_REST_USERNAME, { comment: !env.RESTIC_REST_USERNAME }));
    push(lines, line("RESTIC_REST_PASSWORD", env.RESTIC_REST_PASSWORD, { comment: !env.RESTIC_REST_PASSWORD }));
  }

  section(lines, "tls");
  if (options.use_ca_cert) {
    const caPath = env.RESTIC_CACERT || `/certs/${options.ca_cert_filename || "truenas-ca.crt"}`;
    lines.push(`RESTIC_CACERT=${caPath}`);
  } else {
    push(lines, line("RESTIC_CACERT", env.RESTIC_CACERT, { comment: true }));
  }
  push(lines, line("RESTIC_TLS_CLIENT_CERT", env.RESTIC_TLS_CLIENT_CERT, { comment: !env.RESTIC_TLS_CLIENT_CERT }));
  push(lines, line("RESTIC_INSECURE_TLS", env.RESTIC_INSECURE_TLS, { comment: !env.RESTIC_INSECURE_TLS }));

  section(lines, "restic tuning");
  push(lines, line("RESTIC_KEY_HINT", env.RESTIC_KEY_HINT, { comment: !env.RESTIC_KEY_HINT }));
  lines.push(`RESTIC_COMPRESSION=${env.RESTIC_COMPRESSION || "auto"}`);
  lines.push(`RESTIC_PACK_SIZE=${env.RESTIC_PACK_SIZE || "64"}`);
  push(lines, line("RESTIC_READ_CONCURRENCY", env.RESTIC_READ_CONCURRENCY, { comment: !env.RESTIC_READ_CONCURRENCY }));
  push(lines, line("RESTIC_PROGRESS_FPS", env.RESTIC_PROGRESS_FPS, { comment: !env.RESTIC_PROGRESS_FPS }));
  push(lines, line("RESTIC_NO_CACHE", env.RESTIC_NO_CACHE, { comment: !env.RESTIC_NO_CACHE }));

  section(lines, "alternate repository and password methods. files are the normal setup.");
  push(lines, line("RESTIC_REPOSITORY", env.RESTIC_REPOSITORY, { comment: !env.RESTIC_REPOSITORY }));
  push(lines, line("RESTIC_REPOSITORY_FILE", env.RESTIC_REPOSITORY_FILE, { comment: true }));
  push(lines, line("RESTIC_PASSWORD_FILE", env.RESTIC_PASSWORD_FILE, { comment: true }));
  push(lines, line("RESTIC_PASSWORD", env.RESTIC_PASSWORD, { comment: !env.RESTIC_PASSWORD }));
  push(lines, line("RESTIC_PASSWORD_COMMAND", env.RESTIC_PASSWORD_COMMAND, { comment: !env.RESTIC_PASSWORD_COMMAND }));

  if (options.backend === "s3" || options.use_aws_credentials_file || hasAny(env, S3_KEYS)) {
    section(lines, "s3 and compatible storage");
    if (options.use_aws_credentials_file) {
      lines.push(
        `AWS_SHARED_CREDENTIALS_FILE=${env.AWS_SHARED_CREDENTIALS_FILE || "/run/secrets/aws_credentials"}`,
      );
    } else {
      push(lines, line("AWS_SHARED_CREDENTIALS_FILE", env.AWS_SHARED_CREDENTIALS_FILE, { comment: true }));
    }
    emitAssigned(lines, env, [
      "AWS_PROFILE",
      "AWS_DEFAULT_REGION",
      "AWS_ACCESS_KEY_ID",
      "AWS_SECRET_ACCESS_KEY",
      "AWS_SESSION_TOKEN",
      "RESTIC_AWS_ASSUME_ROLE_ARN",
      "RESTIC_AWS_ASSUME_ROLE_SESSION_NAME",
      "RESTIC_AWS_ASSUME_ROLE_EXTERNAL_ID",
      "RESTIC_AWS_ASSUME_ROLE_POLICY",
      "RESTIC_AWS_ASSUME_ROLE_REGION",
      "RESTIC_AWS_ASSUME_ROLE_STS_ENDPOINT",
    ]);
  }

  emitOptionalBlock(lines, "restic copy source repository", env, [
    "RESTIC_FROM_REPOSITORY",
    "RESTIC_FROM_REPOSITORY_FILE",
    "RESTIC_FROM_PASSWORD",
    "RESTIC_FROM_PASSWORD_FILE",
    "RESTIC_FROM_PASSWORD_COMMAND",
    "RESTIC_FROM_KEY_HINT",
  ]);

  if (options.backend === "azure" || hasAny(env, AZURE_KEYS)) {
    section(lines, "azure");
    emitAssigned(lines, env, AZURE_KEYS);
  }

  if (options.backend === "b2" || hasAny(env, B2_KEYS)) {
    section(lines, "backblaze b2");
    emitAssigned(lines, env, B2_KEYS);
  }

  if (options.backend === "gcs" || hasAny(env, GCS_KEYS)) {
    section(lines, "google cloud storage");
    emitAssigned(lines, env, GCS_KEYS);
  }

  if (options.backend === "swift" || hasAny(env, SWIFT_KEYS)) {
    section(lines, "openstack swift");
    emitAssigned(lines, env, SWIFT_KEYS);
  }

  if (options.backend === "rclone" || env.RCLONE_BWLIMIT) {
    section(lines, "rclone backend");
    push(lines, line("RCLONE_BWLIMIT", env.RCLONE_BWLIMIT));
  }

  lines.push("");
  return lines.join("\n");
}

const S3_KEYS = [
  "AWS_SHARED_CREDENTIALS_FILE",
  "AWS_PROFILE",
  "AWS_DEFAULT_REGION",
  "AWS_ACCESS_KEY_ID",
  "AWS_SECRET_ACCESS_KEY",
  "AWS_SESSION_TOKEN",
  "RESTIC_AWS_ASSUME_ROLE_ARN",
  "RESTIC_AWS_ASSUME_ROLE_SESSION_NAME",
  "RESTIC_AWS_ASSUME_ROLE_EXTERNAL_ID",
  "RESTIC_AWS_ASSUME_ROLE_POLICY",
  "RESTIC_AWS_ASSUME_ROLE_REGION",
  "RESTIC_AWS_ASSUME_ROLE_STS_ENDPOINT",
];
const AZURE_KEYS = [
  "AZURE_ACCOUNT_NAME",
  "AZURE_ACCOUNT_KEY",
  "AZURE_ACCOUNT_SAS",
  "AZURE_ENDPOINT_SUFFIX",
  "AZURE_FORCE_CLI_CREDENTIAL",
];
const B2_KEYS = ["B2_ACCOUNT_ID", "B2_ACCOUNT_KEY"];
const GCS_KEYS = ["GOOGLE_PROJECT_ID", "GOOGLE_APPLICATION_CREDENTIALS", "GOOGLE_ACCESS_TOKEN"];
const SWIFT_KEYS = [
  "OS_AUTH_URL",
  "OS_REGION_NAME",
  "OS_USERNAME",
  "OS_USER_ID",
  "OS_PASSWORD",
  "OS_TENANT_ID",
  "OS_TENANT_NAME",
  "OS_USER_DOMAIN_NAME",
  "OS_USER_DOMAIN_ID",
  "OS_PROJECT_NAME",
  "OS_PROJECT_DOMAIN_NAME",
  "OS_PROJECT_DOMAIN_ID",
  "OS_TRUST_ID",
  "OS_APPLICATION_CREDENTIAL_ID",
  "OS_APPLICATION_CREDENTIAL_NAME",
  "OS_APPLICATION_CREDENTIAL_SECRET",
  "OS_STORAGE_URL",
  "OS_AUTH_TOKEN",
  "ST_AUTH",
  "ST_USER",
  "ST_KEY",
];

function hasAny(env, keys) {
  return keys.some((k) => env[k]);
}

export function emitCompose(draft) {
  const c = draft.compose;
  return `# deploy to /opt/restic-client/
# generated by gen-restic

services:
  restic:
    image: ${c.image || "restic/restic:0.19.1"}
    container_name: ${c.container_name || "restic"}
    env_file: .env
    environment:
      RESTIC_REPOSITORY_FILE: /run/secrets/repo_location.txt
      RESTIC_PASSWORD_FILE: /run/secrets/password.txt
      RESTIC_CACHE_DIR: /cache
      TMPDIR: /cache/tmp
      RESTIC_HOST: \${RESTIC_HOST}
      RESTIC_PACK_SIZE: \${RESTIC_PACK_SIZE:-64}
      RESTIC_COMPRESSION: \${RESTIC_COMPRESSION:-auto}
      # set by backup.sh / helpers from secrets files when using rest server
      RESTIC_REST_USERNAME: \${RESTIC_REST_USERNAME:-}
      RESTIC_REST_PASSWORD: \${RESTIC_REST_PASSWORD:-}
    volumes:
      - ${c.host_mount || "${HOST_ROOT:-/}"}:/host:ro
      - ${c.excludes_file || "./excludes.txt"}:/etc/restic/excludes.txt:ro
      - ${c.includes_file || "./includes.txt"}:/etc/restic/includes.txt:ro
      - ${c.secrets_dir || "./secrets"}:/run/secrets:ro
      - ${c.certs_dir || "./certs"}:/certs:ro
      - ${c.staging_dir || "./staging"}:/staging:ro
      - ${c.staging_app_dir || "./staging/app"}:/app:ro
      - ${c.cache_dir || "/var/cache/restic"}:/cache
    restart: "${c.restart || "no"}"
`;
}

export function emitPrune(draft) {
  const p = draft.prune;
  const repoPath = p.repo_path || "/mnt/coldpool/restic/admin/sample-host";
  const passwordFile = p.password_file || "/root/restic-password.txt";
  const image = p.image || "restic/restic:0.19.1";
  const runtime = p.runtime || "docker";
  const keepDaily = p.keep_daily || "7";
  const keepWeekly = p.keep_weekly || "4";
  const keepMonthly = p.keep_monthly || "12";
  const keepYearly = p.keep_yearly || "2";
  // empty check_args means full check; otherwise bake the default into the script
  const checkLine =
    p.check_args === ""
      ? 'CHECK_ARGS="${CHECK_ARGS-}"'
      : `CHECK_ARGS="\${CHECK_ARGS-${p.check_args || "--read-data-subset=5%"}}"`;

  return `#!/usr/bin/env bash
# run on the TrueNAS host (or any host with direct write access to the dataset).
# append-only rest-server clients cannot forget/prune.
#
# uses a local path repo, not the rest: url.
#
# example:
#   REPO_PATH=${repoPath} \\
#   PASSWORD_FILE=${passwordFile} \\
#   ./prune.sh

set -euo pipefail

REPO_PATH="\${REPO_PATH:-${repoPath}}"
PASSWORD_FILE="\${PASSWORD_FILE:-${passwordFile}}"
IMAGE="\${RESTIC_IMAGE:-${image}}"
RUNTIME="\${CONTAINER_RUNTIME:-${runtime}}"

KEEP_DAILY="\${KEEP_DAILY:-${keepDaily}}"
KEEP_WEEKLY="\${KEEP_WEEKLY:-${keepWeekly}}"
KEEP_MONTHLY="\${KEEP_MONTHLY:-${keepMonthly}}"
KEEP_YEARLY="\${KEEP_YEARLY:-${keepYearly}}"
# default is a small data check. set CHECK_ARGS= for a full check.
${checkLine}

if [ ! -d "\${REPO_PATH}" ]; then
  echo "repo path missing: \${REPO_PATH}"
  exit 1
fi

if [ ! -f "\${PASSWORD_FILE}" ]; then
  echo "password file missing: \${PASSWORD_FILE}"
  exit 1
fi

run_restic() {
  \${RUNTIME} run --rm \\
    -v "\${REPO_PATH}:/repo" \\
    -v "\${PASSWORD_FILE}:/password:ro" \\
    -e RESTIC_REPOSITORY=/repo \\
    -e RESTIC_PASSWORD_FILE=/password \\
    "\${IMAGE}" "\$@"
}

echo "checking \${REPO_PATH}"
# CHECK_ARGS is an operator-controlled list of restic check arguments.
# shellcheck disable=SC2086
run_restic check \${CHECK_ARGS}

echo "pruning \${REPO_PATH}"
run_restic forget --prune \\
    --keep-daily "\${KEEP_DAILY}" \\
    --keep-weekly "\${KEEP_WEEKLY}" \\
    --keep-monthly "\${KEEP_MONTHLY}" \\
    --keep-yearly "\${KEEP_YEARLY}"

echo "prune finished"
`;
}

export function emitDeploy(draft) {
  const { profile, prune, options, env } = draft;
  const stageDest = env.STAGE_DEST || "./staging/app/example-app";
  const stageName = stageDest.split("/").filter(Boolean).pop() || "example-app";
  const lines = [];
  let n = 1;

  function step(text) {
    lines.push(`${n}. ${text}`);
    n += 1;
  }

  lines.push("deploy steps");
  lines.push("");
  step("unpack this archive to the deploy path (example: /opt/restic-client)");
  step("copy backup.sh and scripts/ from the restic compose template into this directory");
  step("chmod 700 backup.sh scripts/*.sh");
  step("chmod 600 .env secrets/*");
  step("mkdir -p /var/cache/restic/tmp staging/app");
  if (profile === "host") {
    step("review includes.txt and excludes.txt");
  } else {
    step("ensure empty-host/ exists (placeholder included)");
  }
  step("./scripts/init-repo.sh");

  if (profile === "sqlite") {
    step("./scripts/stage-sqlite.sh");
    step(
      `${env.COMPOSE_CMD || "nerdctl compose"} run --rm restic backup /app/${stageName} --exclude-caches`,
    );
  } else {
    step("./backup.sh");
  }
  step("./scripts/snapshots.sh");
  step("schedule one daily backup (cron example in the compose template README)");

  if (options.use_ca_cert) {
    step(`confirm RESTIC_CACERT points at certs/${options.ca_cert_filename || "truenas-ca.crt"}`);
  }

  if (prune.enabled) {
    step("copy truenas/prune.sh to the TrueNAS host and schedule it there");
    step(
      `example weekly cron: REPO_PATH=${prune.repo_path} PASSWORD_FILE=${prune.password_file} /path/to/prune.sh`,
    );
  }

  lines.push("");
  lines.push("notes");
  lines.push("- secrets typed in gen-restic are not stored in browser storage");
  lines.push("- do not commit secrets/ or .env");
  if (profile === "sqlite") {
    lines.push("- sqlite-only needs sqlite3 on the host; stage-sqlite.sh fails if it is missing");
  }
  if (profile === "app") {
    lines.push("- app profile needs rsync; sqlite3 is required when the source has sqlite files");
  }
  lines.push("");
  return lines.join("\n");
}

/**
 * @param {object} draft
 * @param {object} secrets in-memory only
 * @returns {Record<string, string>}
 */
export function buildFileMap(draft, secrets) {
  const files = {};
  const opts = draft.options;

  files["compose.yml"] = emitCompose(draft);
  files[".env"] = emitEnv(draft);
  files["includes.txt"] = draft.includes.endsWith("\n") ? draft.includes : draft.includes + "\n";
  files["excludes.txt"] = draft.excludes.endsWith("\n") ? draft.excludes : draft.excludes + "\n";
  files["DEPLOY.txt"] = emitDeploy(draft);

  files["empty-host/.gitkeep"] = "";
  files["staging/.gitkeep"] = "";
  files["staging/app/.gitkeep"] = "";
  files["certs/.gitkeep"] = "";
  files["secrets/.gitkeep"] = "";

  files["secrets/repo_location.txt"] = secretLine(secrets.repo_location);
  files["secrets/password.txt"] = secretLine(secrets.password);

  if (opts.use_rest_auth) {
    files["secrets/rest_username.txt"] = secretLine(secrets.rest_username);
    files["secrets/rest_password.txt"] = secretLine(secrets.rest_password);
  }

  if (opts.use_aws_credentials_file) {
    const aws =
      secrets.aws_credentials ||
      "[default]\naws_access_key_id = replace-me\naws_secret_access_key = replace-me\n";
    files["secrets/aws_credentials"] = aws.endsWith("\n") ? aws : aws + "\n";
  }

  if (opts.use_ntfy_token) {
    files["secrets/ntfy_token.txt"] = secretLine(secrets.ntfy_token);
  }

  if (opts.use_ca_cert) {
    const name = opts.ca_cert_filename || "truenas-ca.crt";
    files[`certs/${name}`] = secretLine(secrets.ca_cert);
  }

  if (draft.prune.enabled) {
    files["truenas/prune.sh"] = emitPrune(draft);
  }

  return files;
}

export function listPreview(draft, secrets) {
  const files = buildFileMap(draft, secrets);
  return Object.keys(files)
    .sort()
    .map((path) => ({ path, content: files[path] }));
}

function secretLine(value) {
  if (!value) return "\n";
  return String(value).replace(/\r?\n$/, "") + "\n";
}
