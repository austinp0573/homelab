import { createStore } from "./store.js";
import { buildFileMap, listPreview } from "./generator.js";
import { zipFiles } from "./zip.js";
import { downloadBlob, field, textInput, checkbox, selectInput } from "./util.js";

const store = createStore();
const ui = {
  tab: "edit",
  previewFile: ".env",
  status: "",
};

const app = document.getElementById("app");

store.subscribe(render);
render();

function setStatus(msg) {
  ui.status = msg;
  render();
  if (msg) {
    setTimeout(() => {
      if (ui.status === msg) {
        ui.status = "";
        render();
      }
    }, 2000);
  }
}

function envField(label, key, draft, opts = {}) {
  return field(
    label,
    textInput(draft.env[key] || "", (v) => store.patchEnv({ [key]: v }), opts),
  );
}

function composeField(label, key, draft) {
  return field(
    label,
    textInput(draft.compose[key] || "", (v) => store.patchCompose({ [key]: v })),
  );
}

function pruneField(label, key, draft) {
  return field(
    label,
    textInput(draft.prune[key] || "", (v) => store.patchPrune({ [key]: v })),
  );
}

function secretField(label, key, secrets, opts = {}) {
  return field(
    label,
    textInput(secrets[key] || "", (v) => store.setSecret(key, v), {
      type: opts.type || "text",
      multiline: opts.multiline,
      rows: opts.rows,
      spellcheck: false,
      className: opts.className,
    }),
  );
}

function section(title, children) {
  const box = document.createElement("section");
  box.className = "section";
  const h = document.createElement("h2");
  h.textContent = title;
  box.append(h);
  for (const child of children) {
    if (child) box.append(child);
  }
  return box;
}

function grid(children) {
  const g = document.createElement("div");
  g.className = "grid";
  for (const c of children) if (c) g.append(c);
  return g;
}

function renderEdit(draft, secrets) {
  const root = document.createElement("div");
  root.className = "edit";

  root.append(
    section("profile", [
      field(
        "backup profile",
        selectInput(
          draft.profile,
          [
            { value: "host", label: "host paths" },
            { value: "app", label: "app directory" },
            { value: "sqlite", label: "sqlite only" },
          ],
          (v) => store.setProfile(v),
        ),
      ),
      draft.profile === "host"
        ? grid([envField("HOST_ROOT", "HOST_ROOT", draft)])
        : null,
      draft.profile === "app"
        ? grid([
            envField("HOST_ROOT", "HOST_ROOT", draft),
            envField("APP_SOURCE_DIR", "APP_SOURCE_DIR", draft),
            envField("BACKUP_NAME", "BACKUP_NAME", draft),
          ])
        : null,
      draft.profile === "sqlite"
        ? grid([
            envField("HOST_ROOT", "HOST_ROOT", draft),
            envField("SQLITE_DB", "SQLITE_DB", draft),
            envField("STAGE_DEST", "STAGE_DEST", draft),
          ])
        : null,
    ]),
  );

  root.append(
    section("repository", [
      field(
        "backend",
        selectInput(
          draft.options.backend,
          [
            { value: "rest", label: "rest server" },
            { value: "local", label: "local / other path" },
            { value: "s3", label: "s3 compatible" },
            { value: "b2", label: "backblaze b2" },
            { value: "azure", label: "azure" },
            { value: "gcs", label: "google cloud storage" },
            { value: "swift", label: "openstack swift" },
            { value: "rclone", label: "rclone" },
          ],
          (v) => store.patchOptions({ backend: v }),
        ),
      ),
      grid([
        envField("RESTIC_HOST", "RESTIC_HOST", draft),
        envField("COMPOSE_CMD", "COMPOSE_CMD", draft),
      ]),
      secretField("repo location (secrets/repo_location.txt)", "repo_location", secrets, {
        placeholder: "rest:https://192.168.1.50:8000/sample-host",
      }),
      secretField("repository password (secrets/password.txt)", "password", secrets, {
        type: "password",
      }),
      checkbox(draft.options.use_rest_auth, (v) => store.patchOptions({ use_rest_auth: v }), "include rest-server auth files"),
      draft.options.use_rest_auth
        ? grid([
            secretField("rest username", "rest_username", secrets),
            secretField("rest password", "rest_password", secrets, { type: "password" }),
          ])
        : null,
      checkbox(draft.options.use_ca_cert, (v) => store.patchOptions({ use_ca_cert: v }), "include CA cert under certs/"),
      draft.options.use_ca_cert
        ? grid([
            field(
              "cert filename",
              textInput(draft.options.ca_cert_filename || "truenas-ca.crt", (v) =>
                store.patchOptions({ ca_cert_filename: v }),
              ),
            ),
            envField("RESTIC_CACERT (container path)", "RESTIC_CACERT", draft, {
              placeholder: "/certs/truenas-ca.crt",
            }),
          ])
        : null,
      draft.options.use_ca_cert
        ? secretField("CA cert PEM", "ca_cert", secrets, { multiline: true, rows: 8, className: "mono" })
        : null,
      grid([
        envField("RESTIC_TLS_CLIENT_CERT", "RESTIC_TLS_CLIENT_CERT", draft),
        envField("RESTIC_INSECURE_TLS", "RESTIC_INSECURE_TLS", draft),
      ]),
    ]),
  );

  if (draft.options.backend === "s3") {
    root.append(
      section("s3", [
        checkbox(
          draft.options.use_aws_credentials_file,
          (v) => store.patchOptions({ use_aws_credentials_file: v }),
          "include secrets/aws_credentials",
        ),
        draft.options.use_aws_credentials_file
          ? secretField("aws credentials file body", "aws_credentials", secrets, {
              multiline: true,
              rows: 5,
              className: "mono",
            })
          : null,
        grid([
          envField("AWS_SHARED_CREDENTIALS_FILE", "AWS_SHARED_CREDENTIALS_FILE", draft),
          envField("AWS_PROFILE", "AWS_PROFILE", draft),
          envField("AWS_DEFAULT_REGION", "AWS_DEFAULT_REGION", draft),
          envField("AWS_ACCESS_KEY_ID", "AWS_ACCESS_KEY_ID", draft),
          envField("AWS_SECRET_ACCESS_KEY", "AWS_SECRET_ACCESS_KEY", draft),
          envField("AWS_SESSION_TOKEN", "AWS_SESSION_TOKEN", draft),
        ]),
        grid([
          envField("RESTIC_AWS_ASSUME_ROLE_ARN", "RESTIC_AWS_ASSUME_ROLE_ARN", draft),
          envField("RESTIC_AWS_ASSUME_ROLE_SESSION_NAME", "RESTIC_AWS_ASSUME_ROLE_SESSION_NAME", draft),
          envField("RESTIC_AWS_ASSUME_ROLE_EXTERNAL_ID", "RESTIC_AWS_ASSUME_ROLE_EXTERNAL_ID", draft),
          envField("RESTIC_AWS_ASSUME_ROLE_POLICY", "RESTIC_AWS_ASSUME_ROLE_POLICY", draft),
          envField("RESTIC_AWS_ASSUME_ROLE_REGION", "RESTIC_AWS_ASSUME_ROLE_REGION", draft),
          envField("RESTIC_AWS_ASSUME_ROLE_STS_ENDPOINT", "RESTIC_AWS_ASSUME_ROLE_STS_ENDPOINT", draft),
        ]),
      ]),
    );
  }

  if (draft.options.backend === "b2") {
    root.append(
      section("backblaze b2", [
        grid([envField("B2_ACCOUNT_ID", "B2_ACCOUNT_ID", draft), envField("B2_ACCOUNT_KEY", "B2_ACCOUNT_KEY", draft)]),
      ]),
    );
  }

  if (draft.options.backend === "azure") {
    root.append(
      section("azure", [
        grid([
          envField("AZURE_ACCOUNT_NAME", "AZURE_ACCOUNT_NAME", draft),
          envField("AZURE_ACCOUNT_KEY", "AZURE_ACCOUNT_KEY", draft),
          envField("AZURE_ACCOUNT_SAS", "AZURE_ACCOUNT_SAS", draft),
          envField("AZURE_ENDPOINT_SUFFIX", "AZURE_ENDPOINT_SUFFIX", draft),
          envField("AZURE_FORCE_CLI_CREDENTIAL", "AZURE_FORCE_CLI_CREDENTIAL", draft),
        ]),
      ]),
    );
  }

  if (draft.options.backend === "gcs") {
    root.append(
      section("google cloud storage", [
        grid([
          envField("GOOGLE_PROJECT_ID", "GOOGLE_PROJECT_ID", draft),
          envField("GOOGLE_APPLICATION_CREDENTIALS", "GOOGLE_APPLICATION_CREDENTIALS", draft),
          envField("GOOGLE_ACCESS_TOKEN", "GOOGLE_ACCESS_TOKEN", draft),
        ]),
      ]),
    );
  }

  if (draft.options.backend === "swift") {
    root.append(
      section("openstack swift", [
        grid([
          envField("OS_AUTH_URL", "OS_AUTH_URL", draft),
          envField("OS_REGION_NAME", "OS_REGION_NAME", draft),
          envField("OS_USERNAME", "OS_USERNAME", draft),
          envField("OS_USER_ID", "OS_USER_ID", draft),
          envField("OS_PASSWORD", "OS_PASSWORD", draft),
          envField("OS_TENANT_ID", "OS_TENANT_ID", draft),
          envField("OS_TENANT_NAME", "OS_TENANT_NAME", draft),
          envField("OS_USER_DOMAIN_NAME", "OS_USER_DOMAIN_NAME", draft),
          envField("OS_USER_DOMAIN_ID", "OS_USER_DOMAIN_ID", draft),
          envField("OS_PROJECT_NAME", "OS_PROJECT_NAME", draft),
          envField("OS_PROJECT_DOMAIN_NAME", "OS_PROJECT_DOMAIN_NAME", draft),
          envField("OS_PROJECT_DOMAIN_ID", "OS_PROJECT_DOMAIN_ID", draft),
          envField("OS_TRUST_ID", "OS_TRUST_ID", draft),
          envField("OS_APPLICATION_CREDENTIAL_ID", "OS_APPLICATION_CREDENTIAL_ID", draft),
          envField("OS_APPLICATION_CREDENTIAL_NAME", "OS_APPLICATION_CREDENTIAL_NAME", draft),
          envField("OS_APPLICATION_CREDENTIAL_SECRET", "OS_APPLICATION_CREDENTIAL_SECRET", draft),
          envField("OS_STORAGE_URL", "OS_STORAGE_URL", draft),
          envField("OS_AUTH_TOKEN", "OS_AUTH_TOKEN", draft),
          envField("ST_AUTH", "ST_AUTH", draft),
          envField("ST_USER", "ST_USER", draft),
          envField("ST_KEY", "ST_KEY", draft),
        ]),
      ]),
    );
  }

  if (draft.options.backend === "rclone") {
    root.append(section("rclone", [grid([envField("RCLONE_BWLIMIT", "RCLONE_BWLIMIT", draft)])]));
  }

  // allow aws credentials file even when not on s3 backend (e.g. rest + later)
  if (draft.options.backend !== "s3") {
    root.append(
      section("optional aws credentials file", [
        checkbox(
          draft.options.use_aws_credentials_file,
          (v) => store.patchOptions({ use_aws_credentials_file: v }),
          "include secrets/aws_credentials",
        ),
        draft.options.use_aws_credentials_file
          ? secretField("aws credentials file body", "aws_credentials", secrets, {
              multiline: true,
              rows: 5,
              className: "mono",
            })
          : null,
      ]),
    );
  }

  root.append(
    section("notifications", [
      grid([
        envField("HEALTHCHECKS_URL", "HEALTHCHECKS_URL", draft),
        envField("NTFY_URL", "NTFY_URL", draft),
        envField("NTFY_TOPIC", "NTFY_TOPIC", draft),
      ]),
      checkbox(draft.options.use_ntfy_token, (v) => store.patchOptions({ use_ntfy_token: v }), "include ntfy token file"),
      draft.options.use_ntfy_token
        ? grid([
            envField("NTFY_TOKEN_FILE", "NTFY_TOKEN_FILE", draft),
            secretField("ntfy token", "ntfy_token", secrets, { type: "password" }),
          ])
        : null,
    ]),
  );

  root.append(
    section("restic tuning", [
      grid([
        envField("RESTIC_COMPRESSION", "RESTIC_COMPRESSION", draft),
        envField("RESTIC_PACK_SIZE", "RESTIC_PACK_SIZE", draft),
        envField("RESTIC_KEY_HINT", "RESTIC_KEY_HINT", draft),
        envField("RESTIC_READ_CONCURRENCY", "RESTIC_READ_CONCURRENCY", draft),
        envField("RESTIC_PROGRESS_FPS", "RESTIC_PROGRESS_FPS", draft),
        envField("RESTIC_NO_CACHE", "RESTIC_NO_CACHE", draft),
      ]),
    ]),
  );

  root.append(
    section("restic copy (optional)", [
      grid([
        envField("RESTIC_FROM_REPOSITORY", "RESTIC_FROM_REPOSITORY", draft),
        envField("RESTIC_FROM_REPOSITORY_FILE", "RESTIC_FROM_REPOSITORY_FILE", draft),
        envField("RESTIC_FROM_PASSWORD", "RESTIC_FROM_PASSWORD", draft),
        envField("RESTIC_FROM_PASSWORD_FILE", "RESTIC_FROM_PASSWORD_FILE", draft),
        envField("RESTIC_FROM_PASSWORD_COMMAND", "RESTIC_FROM_PASSWORD_COMMAND", draft),
        envField("RESTIC_FROM_KEY_HINT", "RESTIC_FROM_KEY_HINT", draft),
      ]),
    ]),
  );

  root.append(
    section("alternate env repo/password methods", [
      grid([
        envField("RESTIC_REPOSITORY", "RESTIC_REPOSITORY", draft),
        envField("RESTIC_PASSWORD", "RESTIC_PASSWORD", draft),
        envField("RESTIC_PASSWORD_COMMAND", "RESTIC_PASSWORD_COMMAND", draft),
      ]),
    ]),
  );

  root.append(
    section("includes.txt", [
      textInput(draft.includes, (v) => store.setIncludes(v), {
        multiline: true,
        rows: 12,
        className: "mono full",
        spellcheck: false,
      }),
    ]),
  );

  root.append(
    section("excludes.txt", [
      textInput(draft.excludes, (v) => store.setExcludes(v), {
        multiline: true,
        rows: 16,
        className: "mono full",
        spellcheck: false,
      }),
    ]),
  );

  root.append(
    section("compose.yml", [
      grid([
        composeField("image", "image", draft),
        composeField("container_name", "container_name", draft),
        composeField("restart", "restart", draft),
        composeField("host mount source", "host_mount", draft),
        composeField("excludes file", "excludes_file", draft),
        composeField("includes file", "includes_file", draft),
        composeField("secrets dir", "secrets_dir", draft),
        composeField("certs dir", "certs_dir", draft),
        composeField("staging dir", "staging_dir", draft),
        composeField("staging/app dir", "staging_app_dir", draft),
        composeField("cache dir", "cache_dir", draft),
      ]),
    ]),
  );

  root.append(
    section("truenas prune", [
      checkbox(draft.prune.enabled, (v) => store.patchPrune({ enabled: v }), "include truenas/prune.sh in zip"),
      draft.prune.enabled
        ? grid([
            pruneField("REPO_PATH", "repo_path", draft),
            pruneField("PASSWORD_FILE", "password_file", draft),
            pruneField("image", "image", draft),
            pruneField("runtime", "runtime", draft),
            pruneField("KEEP_DAILY", "keep_daily", draft),
            pruneField("KEEP_WEEKLY", "keep_weekly", draft),
            pruneField("KEEP_MONTHLY", "keep_monthly", draft),
            pruneField("KEEP_YEARLY", "keep_yearly", draft),
            pruneField("CHECK_ARGS (empty = full check)", "check_args", draft),
          ])
        : null,
    ]),
  );

  return root;
}

function renderPreview(draft, secrets) {
  const files = listPreview(draft, secrets);
  if (!files.find((f) => f.path === ui.previewFile)) {
    ui.previewFile = files[0]?.path || ".env";
  }
  const current = files.find((f) => f.path === ui.previewFile) || files[0];

  const root = document.createElement("div");
  root.className = "preview-layout";

  const list = document.createElement("div");
  list.className = "file-list";
  for (const f of files) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "file-item" + (f.path === ui.previewFile ? " active" : "");
    btn.textContent = f.path;
    btn.addEventListener("click", () => {
      ui.previewFile = f.path;
      render();
    });
    list.append(btn);
  }

  const pane = document.createElement("pre");
  pane.className = "preview-pane";
  pane.textContent = current ? current.content : "";

  root.append(list, pane);
  return root;
}

function downloadZip() {
  const draft = store.getDraft();
  const secrets = store.getSecrets();
  const files = buildFileMap(draft, secrets);
  const blob = zipFiles(files);
  const host = draft.env.RESTIC_HOST || "restic";
  downloadBlob(`${host}-restic-config.zip`, blob);
  setStatus("zip downloaded");
}

function render() {
  const draft = store.getDraft();
  const secrets = store.getSecrets();
  app.replaceChildren();

  const top = document.createElement("header");
  top.className = "topbar";
  const brand = document.createElement("div");
  brand.className = "brand";
  brand.textContent = "gen-restic";

  const tabs = document.createElement("div");
  tabs.className = "tabs";
  for (const t of [
    { id: "edit", label: "edit" },
    { id: "preview", label: "preview" },
  ]) {
    const b = document.createElement("button");
    b.type = "button";
    b.className = "tab" + (ui.tab === t.id ? " active" : "");
    b.textContent = t.label;
    b.addEventListener("click", () => {
      ui.tab = t.id;
      render();
    });
    tabs.append(b);
  }

  const spacer = document.createElement("div");
  spacer.className = "spacer";

  const status = document.createElement("span");
  status.className = "status";
  status.textContent = ui.status;

  const actions = document.createElement("div");
  actions.className = "actions";

  const zipBtn = document.createElement("button");
  zipBtn.type = "button";
  zipBtn.textContent = "download zip";
  zipBtn.addEventListener("click", downloadZip);

  const forgetBtn = document.createElement("button");
  forgetBtn.type = "button";
  forgetBtn.className = "danger";
  forgetBtn.textContent = "forget secrets";
  forgetBtn.addEventListener("click", () => {
    store.forgetSecrets();
    setStatus("secrets cleared");
  });

  const resetBtn = document.createElement("button");
  resetBtn.type = "button";
  resetBtn.textContent = "reset draft";
  resetBtn.addEventListener("click", () => {
    if (confirm("reset the whole draft?")) {
      store.resetDraft();
      setStatus("draft reset");
    }
  });

  actions.append(zipBtn, forgetBtn, resetBtn);
  top.append(brand, tabs, spacer, status, actions);

  const main = document.createElement("main");
  main.className = "main";
  if (ui.tab === "edit") main.append(renderEdit(draft, secrets));
  else main.append(renderPreview(draft, secrets));

  const note = document.createElement("footer");
  note.className = "footer";
  note.textContent =
    "draft (without secrets) is saved in localStorage. secrets stay in memory until forget secrets or reload.";

  app.append(top, main, note);
}
