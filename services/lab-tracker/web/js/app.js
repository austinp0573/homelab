(() => {
  const TYPES = [
    "physical",
    "vm",
    "vps",
    "lxc",
    "nas",
    "switch",
    "ap",
    "ups",
    "pi",
    "gpu",
    "service",
    "network",
    "backup_job",
    "other",
  ];

  const STATUSES = [
    "draft",
    "planned",
    "active",
    "maintenance",
    "inactive",
    "retired",
  ];

  const FIELD_CATEGORIES = [
    "identity",
    "hardware",
    "network",
    "access",
    "power",
    "backup",
    "notes",
    "other",
  ];

  const BUILTIN_SECTIONS = [
    {
      id: "identity",
      title: "identity",
      fields: [
        ["hostname", "hostname"],
        ["role", "role"],
        ["os", "os"],
        ["location", "location"],
        ["dns_names", "dns names"],
      ],
    },
    {
      id: "hardware",
      title: "hardware",
      fields: [
        ["cpu", "cpu"],
        ["ram", "ram"],
        ["disks", "disks"],
        ["gpu", "gpu"],
        ["serial", "serial"],
        ["asset_tag", "asset tag"],
        ["purchase_date", "purchase date"],
        ["warranty", "warranty"],
        ["model", "model"],
        ["boot", "boot"],
        ["hypervisor", "hypervisor"],
        ["vmid", "vmid"],
        ["storage_pool", "storage pool"],
        ["bridge", "bridge"],
        ["provider", "provider"],
        ["region", "region"],
        ["cost", "cost"],
      ],
    },
    {
      id: "access",
      title: "access",
      fields: [
        ["ssh_user", "ssh user"],
        ["ssh_port", "ssh port"],
        ["mgmt_url", "mgmt url"],
        ["tailscale", "tailscale"],
        ["wireguard", "wireguard"],
        ["secrets", "secrets / refs"],
      ],
    },
    {
      id: "notes",
      title: "notes",
      fields: [["notes", "notes", "textarea"]],
    },
  ];

  const state = {
    hash: "",
    inventory: { version: 1, custom_fields: [], assets: [] },
    view: "dashboard",
    filter: "",
    selected: new Set(),
    dirtyLocal: false,
  };

  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

  function flash(msg, ok = false) {
    const el = $("#flash");
    if (!msg) {
      el.className = "flash hidden";
      el.textContent = "";
      return;
    }
    el.className = "flash" + (ok ? " ok" : "");
    el.textContent = msg;
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function newId() {
    const bytes = new Uint8Array(4);
    crypto.getRandomValues(bytes);
    return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
  }

  function byId(id) {
    return state.inventory.assets.find((a) => a.id === id);
  }

  function assetName(id) {
    const a = byId(id);
    return a ? a.name : id;
  }

  function parentsOf(asset) {
    return asset.parents || [];
  }

  function matchesFilter(asset) {
    const q = state.filter.trim().toLowerCase();
    if (!q) return true;
    const blob = [
      asset.name,
      asset.type,
      asset.status,
      asset.os,
      asset.hostname,
      asset.role,
      asset.location,
      asset.notes,
      ...(asset.tags || []),
      ...((asset.interfaces || []).flatMap((i) => [
        i.name,
        i.mac,
        i.network,
        ...(i.ips || []),
      ])),
      ...((asset.ports || []).flatMap((p) => [p.label, p.port, p.protocol])),
    ]
      .filter(Boolean)
      .join(" ")
      .toLowerCase();
    return blob.includes(q);
  }

  function filteredAssets() {
    return state.inventory.assets.filter(matchesFilter);
  }

  async function apiGet() {
    const res = await fetch("/api/inventory");
    const data = await res.json();
    if (!res.ok) {
      throw new Error(formatErr(data));
    }
    return data;
  }

  async function apiPut(inventory) {
    const res = await fetch("/api/inventory", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ hash: state.hash, inventory }),
    });
    const data = await res.json();
    if (!res.ok) {
      throw new Error(formatErr(data));
    }
    return data;
  }

  function formatErr(data) {
    if (!data) return "request failed";
    if (data.error) {
      return data.fix ? data.error + "\nfix: " + data.fix : data.error;
    }
    if (data.detail) return String(data.detail);
    return "request failed";
  }

  async function loadInventory() {
    const data = await apiGet();
    state.hash = data.hash;
    state.inventory = data.inventory;
    state.selected.clear();
    state.dirtyLocal = false;
    render();
  }

  async function saveInventory() {
    const data = await apiPut(state.inventory);
    state.hash = data.hash;
    state.inventory = data.inventory;
    state.dirtyLocal = false;
    return data;
  }

  async function mutate(fn) {
    flash("");
    const snapshot = JSON.stringify(state.inventory);
    try {
      fn();
      await saveInventory();
      flash("saved", true);
      render();
    } catch (err) {
      state.inventory = JSON.parse(snapshot);
      flash(String(err.message || err));
      render();
    }
  }

  function render() {
    $$(".tab").forEach((btn) => {
      btn.classList.toggle("active", btn.dataset.view === state.view);
    });
    const main = $("#main");
    if (state.view === "dashboard") main.innerHTML = renderDashboard();
    else if (state.view === "tree") main.innerHTML = renderTree();
    else if (state.view === "table") main.innerHTML = renderTable();
    else if (state.view === "fields") main.innerHTML = renderFields();
    bindMain();
  }

  function countBy(key) {
    const out = {};
    for (const a of state.inventory.assets) {
      const k = a[key] || "unknown";
      out[k] = (out[k] || 0) + 1;
    }
    return out;
  }

  function orphans() {
    const ids = new Set(state.inventory.assets.map((a) => a.id));
    return state.inventory.assets.filter((a) => {
      const p = parentsOf(a);
      if (!p.length) {
        // root nodes are fine; orphan means parent ids missing
        return false;
      }
      return p.some((pid) => !ids.has(pid));
    });
  }

  function missingBasics() {
    return state.inventory.assets.filter((a) => {
      if (a.type === "backup_job" || a.type === "network") return false;
      return !a.os && !(a.interfaces || []).some((i) => (i.ips || []).length);
    });
  }

  function renderDashboard() {
    const byType = countBy("type");
    const byStatus = countBy("status");
    const upsList = state.inventory.assets.filter((a) => a.type === "ups");
    const orphanList = orphans();
    const attention = missingBasics();

    let html = `<div class="grid-cards">`;
    html += card("assets", state.inventory.assets.length);
    for (const t of TYPES) {
      if (byType[t]) html += card(t, byType[t]);
    }
    html += `</div>`;

    html += `<div class="section"><h2>status</h2><div>`;
    for (const s of STATUSES) {
      if (byStatus[s]) {
        html += `<span class="badge status-${escapeHtml(s)}">${escapeHtml(s)}: ${byStatus[s]}</span> `;
      }
    }
    if (!Object.keys(byStatus).length) html += `<span class="muted">no assets yet</span>`;
    html += `</div></div>`;

    html += `<div class="section"><h2>power</h2>`;
    if (!upsList.length) {
      html += `<div class="muted">no ups assets yet</div>`;
    } else {
      html += `<div class="power-map">`;
      for (const ups of upsList) {
        const fed = state.inventory.assets.filter((a) =>
          (a.powered_by || []).includes(ups.id)
        );
        html += `<div style="margin-bottom:10px"><strong>${escapeHtml(ups.name)}</strong>`;
        if (!fed.length) html += ` <span class="muted">- nothing linked</span>`;
        else {
          html += `<ul>`;
          for (const a of fed) {
            html += `<li><button type="button" class="linkish" data-open="${escapeHtml(a.id)}">${escapeHtml(a.name)}</button> <span class="badge type">${escapeHtml(a.type)}</span></li>`;
          }
          html += `</ul>`;
        }
        html += `</div>`;
      }
      html += `</div>`;
    }
    html += `</div>`;

    html += `<div class="section"><h2>orphans / broken parents</h2>`;
    if (!orphanList.length) html += `<div class="muted">none</div>`;
    else {
      html += `<ul>`;
      for (const a of orphanList) {
        html += `<li><button type="button" class="linkish" data-open="${escapeHtml(a.id)}">${escapeHtml(a.name)}</button> parents: ${(a.parents || []).map(escapeHtml).join(", ")}</li>`;
      }
      html += `</ul>`;
    }
    html += `</div>`;

    html += `<div class="section"><h2>maybe needs attention</h2><div class="muted">no os and no ips</div>`;
    if (!attention.length) html += `<div class="muted">none</div>`;
    else {
      html += `<ul>`;
      for (const a of attention.slice(0, 30)) {
        html += `<li><button type="button" class="linkish" data-open="${escapeHtml(a.id)}">${escapeHtml(a.name)}</button></li>`;
      }
      html += `</ul>`;
    }
    html += `</div>`;

    return html;
  }

  function card(label, value) {
    return `<div class="card"><div class="label">${escapeHtml(label)}</div><div class="value">${value}</div></div>`;
  }

  function renderTree() {
    const assets = filteredAssets();
    if (!assets.length) {
      return `<div class="empty">no assets match</div>`;
    }
    const idSet = new Set(assets.map((a) => a.id));
    const rootNodes = assets.filter((a) => {
      const p = parentsOf(a);
      return !p.length || p.every((pid) => !idSet.has(pid));
    });

    function walk(asset, seen) {
      if (seen.has(asset.id)) {
        return `<li><span class="node muted">cycle: ${escapeHtml(asset.name)}</span></li>`;
      }
      seen.add(asset.id);
      const kids = assets.filter((a) => (a.parents || []).includes(asset.id));
      let html = `<li><span class="node" data-open="${escapeHtml(asset.id)}"><span class="badge type">${escapeHtml(asset.type)}</span> ${escapeHtml(asset.name)} <span class="badge status-${escapeHtml(asset.status)}">${escapeHtml(asset.status)}</span></span>`;
      if (kids.length) {
        html += `<ul>`;
        for (const k of kids) html += walk(k, new Set(seen));
        html += `</ul>`;
      }
      html += `</li>`;
      return html;
    }

    let html = `<div class="tree"><ul>`;
    for (const r of rootNodes) html += walk(r, new Set());
    html += `</ul></div>`;
    return html;
  }

  function renderTable() {
    const assets = filteredAssets();
    let html = `<div class="toolbar">
      <button type="button" id="bulk-tag">bulk tag</button>
      <button type="button" id="bulk-status">bulk status</button>
      <button type="button" class="danger" id="bulk-delete">bulk delete</button>
      <span class="muted" id="sel-count">${state.selected.size} selected</span>
    </div>`;
    if (!assets.length) {
      html += `<div class="empty">no assets match</div>`;
      return html;
    }
    html += `<table class="data"><thead><tr>
      <th class="row-check"><input type="checkbox" id="check-all"></th>
      <th>name</th><th>type</th><th>status</th><th>parents</th><th>os</th><th>tags</th>
    </tr></thead><tbody>`;
    for (const a of assets) {
      const sel = state.selected.has(a.id);
      html += `<tr class="${sel ? "selected" : ""}" data-open-row="${escapeHtml(a.id)}">
        <td><input type="checkbox" class="row-check" data-id="${escapeHtml(a.id)}" ${sel ? "checked" : ""}></td>
        <td><button type="button" class="linkish" data-open="${escapeHtml(a.id)}">${escapeHtml(a.name)}</button></td>
        <td><span class="badge type">${escapeHtml(a.type)}</span></td>
        <td><span class="badge status-${escapeHtml(a.status)}">${escapeHtml(a.status)}</span></td>
        <td class="mono">${(a.parents || []).map(assetName).map(escapeHtml).join(", ") || "-"}</td>
        <td>${escapeHtml(a.os || "-")}</td>
        <td>${(a.tags || []).map((t) => `<span class="badge">${escapeHtml(t)}</span>`).join(" ") || "-"}</td>
      </tr>`;
    }
    html += `</tbody></table>`;
    return html;
  }

  function renderFields() {
    const fields = state.inventory.custom_fields || [];
    let html = `<div class="section"><h2>custom fields</h2>
      <p class="muted">global fields you can fill on any asset. they show under the category you pick.</p>
      <div class="toolbar"><button type="button" class="primary" id="field-add">add field</button></div>`;
    if (!fields.length) {
      html += `<div class="muted">none yet</div></div>`;
      return html;
    }
    html += `<table class="data"><thead><tr><th>key</th><th>label</th><th>category</th><th></th></tr></thead><tbody>`;
    for (const f of fields) {
      html += `<tr>
        <td class="mono">${escapeHtml(f.key)}</td>
        <td>${escapeHtml(f.label)}</td>
        <td>${escapeHtml(f.category)}</td>
        <td><button type="button" class="danger" data-del-field="${escapeHtml(f.key)}">delete</button></td>
      </tr>`;
    }
    html += `</tbody></table></div>`;
    return html;
  }

  function bindMain() {
    $$("[data-open]").forEach((el) => {
      el.addEventListener("click", (e) => {
        e.stopPropagation();
        openAsset(el.dataset.open);
      });
    });
    $$("[data-open-row]").forEach((tr) => {
      tr.addEventListener("click", (e) => {
        if (e.target.closest("input,button")) return;
        openAsset(tr.dataset.openRow);
      });
    });
    $$(".row-check[data-id]").forEach((cb) => {
      cb.addEventListener("change", () => {
        if (cb.checked) state.selected.add(cb.dataset.id);
        else state.selected.delete(cb.dataset.id);
        const count = $("#sel-count");
        if (count) count.textContent = state.selected.size + " selected";
        render();
      });
    });
    const checkAll = $("#check-all");
    if (checkAll) {
      checkAll.addEventListener("change", () => {
        const assets = filteredAssets();
        if (checkAll.checked) assets.forEach((a) => state.selected.add(a.id));
        else assets.forEach((a) => state.selected.delete(a.id));
        render();
      });
    }
    const bulkTag = $("#bulk-tag");
    if (bulkTag) {
      bulkTag.addEventListener("click", () => {
        if (!state.selected.size) return flash("select at least one asset");
        const tag = prompt("tag to add");
        if (!tag || !tag.trim()) return;
        mutate(() => {
          for (const id of state.selected) {
            const a = byId(id);
            if (!a) continue;
            a.tags = a.tags || [];
            if (!a.tags.includes(tag.trim())) a.tags.push(tag.trim());
          }
        });
      });
    }
    const bulkStatus = $("#bulk-status");
    if (bulkStatus) {
      bulkStatus.addEventListener("click", () => {
        if (!state.selected.size) return flash("select at least one asset");
        const status = prompt("status (" + STATUSES.join(", ") + ")");
        if (!status || !STATUSES.includes(status.trim())) {
          return flash("invalid status");
        }
        mutate(() => {
          for (const id of state.selected) {
            const a = byId(id);
            if (a) a.status = status.trim();
          }
        });
      });
    }
    const bulkDelete = $("#bulk-delete");
    if (bulkDelete) {
      bulkDelete.addEventListener("click", () => {
        if (!state.selected.size) return flash("select at least one asset");
        if (!confirm("delete " + state.selected.size + " asset(s)? children become orphans (parents cleared if pointing here).")) return;
        mutate(() => {
          const doomed = new Set(state.selected);
          state.inventory.assets = state.inventory.assets.filter((a) => !doomed.has(a.id));
          for (const a of state.inventory.assets) {
            for (const key of [
              "parents",
              "powered_by",
              "backup_jobs",
              "depends_on",
              "backed_up_by",
              "fronted_by",
              "monitored_by",
            ]) {
              if (a[key]) a[key] = a[key].filter((x) => !doomed.has(x));
            }
          }
          state.selected.clear();
        });
      });
    }
    const fieldAdd = $("#field-add");
    if (fieldAdd) {
      fieldAdd.addEventListener("click", () => openFieldEditor());
    }
    $$("[data-del-field]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const key = btn.dataset.delField;
        if (!confirm("delete custom field '" + key + "'?")) return;
        mutate(() => {
          state.inventory.custom_fields = state.inventory.custom_fields.filter(
            (f) => f.key !== key
          );
          for (const a of state.inventory.assets) {
            if (a.custom && key in a.custom) delete a.custom[key];
          }
        });
      });
    });
  }

  function openFieldEditor() {
    const panel = $("#modal-panel");
    panel.innerHTML = `<h2>add custom field</h2>
      <div class="form-grid">
        <label>key</label><input id="f-key" placeholder="warranty_url">
        <label>label</label><input id="f-label" placeholder="Warranty URL">
        <label>category</label>
        <select id="f-cat">${FIELD_CATEGORIES.map((c) => `<option value="${c}">${c}</option>`).join("")}</select>
      </div>
      <div class="form-actions">
        <button type="button" class="primary" id="f-save">save</button>
        <button type="button" id="f-cancel">cancel</button>
      </div>`;
    showModal(true);
    $("#f-cancel").onclick = () => showModal(false);
    $("#f-save").onclick = () => {
      const key = $("#f-key").value.trim();
      const label = $("#f-label").value.trim() || key;
      const category = $("#f-cat").value;
      if (!key) return flash("key is required");
      if (!/^[A-Za-z0-9_]+$/.test(key)) {
        return flash("key must be letters, numbers, underscore");
      }
      if ((state.inventory.custom_fields || []).some((f) => f.key === key)) {
        return flash("key already exists");
      }
      mutate(() => {
        state.inventory.custom_fields = state.inventory.custom_fields || [];
        state.inventory.custom_fields.push({ key, label, category });
      }).then(() => showModal(false));
    };
  }

  function showModal(on) {
    $("#modal").classList.toggle("hidden", !on);
  }

  function openAsset(id) {
    const existing = id ? byId(id) : null;
    const asset = existing
      ? JSON.parse(JSON.stringify(existing))
      : {
          id: newId(),
          name: "",
          type: "physical",
          status: "active",
          parents: [],
          tags: [],
        };

    const panel = $("#modal-panel");
    panel.innerHTML = renderAssetForm(asset, !existing);
    showModal(true);
    bindAssetForm(asset, !existing);
  }

  function optionList(values, selected) {
    return values
      .map((v) => `<option value="${escapeHtml(v)}" ${v === selected ? "selected" : ""}>${escapeHtml(v)}</option>`)
      .join("");
  }

  function renderAssetForm(asset, isNew) {
    const otherAssets = state.inventory.assets.filter((a) => a.id !== asset.id);
    const parentOpts = otherAssets
      .map((a) => {
        const sel = (asset.parents || []).includes(a.id) ? "selected" : "";
        return `<option value="${escapeHtml(a.id)}" ${sel}>${escapeHtml(a.name)} (${escapeHtml(a.type)})</option>`;
      })
      .join("");

    function relSelect(key, label) {
      const opts = otherAssets
        .map((a) => {
          const sel = (asset[key] || []).includes(a.id) ? "selected" : "";
          return `<option value="${escapeHtml(a.id)}" ${sel}>${escapeHtml(a.name)} (${escapeHtml(a.type)})</option>`;
        })
        .join("");
      return `<label>${label}</label>
        <select multiple size="4" data-rel="${key}">${opts}</select>`;
    }

    let html = `<h2>${isNew ? "new asset" : "edit " + escapeHtml(asset.name)}</h2>
      <div class="form-grid">
        <label>name</label><input id="a-name" value="${escapeHtml(asset.name || "")}">
        <label>type</label><select id="a-type">${optionList(TYPES, asset.type)}</select>
        <label>status</label><select id="a-status">${optionList(STATUSES, asset.status)}</select>
        <label>tags</label><input id="a-tags" value="${escapeHtml((asset.tags || []).join(", "))}" placeholder="comma separated">
        <label>parents</label><select multiple size="4" id="a-parents">${parentOpts}</select>
      </div>`;

    for (const section of BUILTIN_SECTIONS) {
      html += `<details class="block"><summary>${section.title}</summary><div class="block-body form-grid">`;
      for (const [key, label, kind] of section.fields) {
        const val = asset[key] || "";
        if (kind === "textarea") {
          html += `<label>${label}</label><textarea data-field="${key}">${escapeHtml(val)}</textarea>`;
        } else {
          html += `<label>${label}</label><input data-field="${key}" value="${escapeHtml(val)}">`;
        }
      }
      const customs = (state.inventory.custom_fields || []).filter(
        (f) => f.category === section.id
      );
      for (const f of customs) {
        const val = (asset.custom && asset.custom[f.key]) || "";
        html += `<label>${escapeHtml(f.label)}</label><input data-custom="${escapeHtml(f.key)}" value="${escapeHtml(val)}">`;
      }
      html += `</div></details>`;
    }

    // network interfaces
    html += `<details class="block"><summary>interfaces</summary><div class="block-body">
      <div class="list-editor" id="iface-list"></div>
      <button type="button" id="iface-add">add interface</button>
    </div></details>`;

    // ports
    html += `<details class="block"><summary>ports</summary><div class="block-body">
      <div class="list-editor" id="port-list"></div>
      <button type="button" id="port-add">add port</button>
    </div></details>`;

    // power / backup / relations
    html += `<details class="block"><summary>power / backup / relations</summary><div class="block-body form-grid">
      ${relSelect("powered_by", "powered by")}
      ${relSelect("backup_jobs", "backup jobs")}
      ${relSelect("depends_on", "depends on")}
      ${relSelect("backed_up_by", "backed up by")}
      ${relSelect("fronted_by", "fronted by")}
      ${relSelect("monitored_by", "monitored by")}
    </div></details>`;

    // other custom fields not in builtin categories
    const otherCustom = (state.inventory.custom_fields || []).filter(
      (f) => !BUILTIN_SECTIONS.some((s) => s.id === f.category)
    );
    if (otherCustom.length) {
      html += `<details class="block"><summary>other custom</summary><div class="block-body form-grid">`;
      for (const f of otherCustom) {
        const val = (asset.custom && asset.custom[f.key]) || "";
        html += `<label>${escapeHtml(f.label)}</label><input data-custom="${escapeHtml(f.key)}" value="${escapeHtml(val)}">`;
      }
      html += `</div></details>`;
    }

    html += `<div class="form-actions">
      <button type="button" class="primary" id="a-save">save</button>
      <button type="button" id="a-cancel">cancel</button>
      ${isNew ? "" : `<button type="button" class="danger" id="a-delete">delete</button>`}
      <span class="muted mono">id: ${escapeHtml(asset.id)}</span>
    </div>`;
    return html;
  }

  function bindAssetForm(asset, isNew) {
    const ifaces = JSON.parse(JSON.stringify(asset.interfaces || []));
    const ports = JSON.parse(JSON.stringify(asset.ports || []));

    function drawIfaces() {
      const box = $("#iface-list");
      box.innerHTML = "";
      ifaces.forEach((iface, idx) => {
        const row = document.createElement("div");
        row.className = "list-row";
        row.innerHTML = `
          <input data-k="name" placeholder="name" value="${escapeHtml(iface.name || "")}">
          <input data-k="mac" placeholder="mac" value="${escapeHtml(iface.mac || "")}">
          <input data-k="ips" placeholder="ips comma sep" value="${escapeHtml((iface.ips || []).join(", "))}">
          <input data-k="network" placeholder="network asset name or note" value="${escapeHtml(iface.network || "")}">
          <input data-k="role" placeholder="role" value="${escapeHtml(iface.role || "")}">
          <button type="button" data-rm>x</button>`;
        row.querySelectorAll("input").forEach((inp) => {
          inp.addEventListener("input", () => {
            const k = inp.dataset.k;
            if (k === "ips") {
              ifaces[idx].ips = inp.value
                .split(",")
                .map((s) => s.trim())
                .filter(Boolean);
            } else {
              ifaces[idx][k] = inp.value;
            }
          });
        });
        row.querySelector("[data-rm]").onclick = () => {
          ifaces.splice(idx, 1);
          drawIfaces();
        };
        box.appendChild(row);
      });
    }

    function drawPorts() {
      const box = $("#port-list");
      box.innerHTML = "";
      ports.forEach((port, idx) => {
        const row = document.createElement("div");
        row.className = "list-row";
        row.innerHTML = `
          <input data-k="label" placeholder="label" value="${escapeHtml(port.label || "")}">
          <input data-k="port" placeholder="port" value="${escapeHtml(port.port || "")}">
          <input data-k="protocol" placeholder="tcp/udp" value="${escapeHtml(port.protocol || "")}">
          <input data-k="note" placeholder="note" value="${escapeHtml(port.note || "")}">
          <button type="button" data-rm>x</button>`;
        row.querySelectorAll("input").forEach((inp) => {
          inp.addEventListener("input", () => {
            ports[idx][inp.dataset.k] = inp.value;
          });
        });
        row.querySelector("[data-rm]").onclick = () => {
          ports.splice(idx, 1);
          drawPorts();
        };
        box.appendChild(row);
      });
    }

    drawIfaces();
    drawPorts();
    $("#iface-add").onclick = () => {
      ifaces.push({ name: "", mac: "", ips: [], network: "", role: "" });
      drawIfaces();
    };
    $("#port-add").onclick = () => {
      ports.push({ label: "", port: "", protocol: "", note: "" });
      drawPorts();
    };

    $("#a-cancel").onclick = () => showModal(false);
    const del = $("#a-delete");
    if (del) {
      del.onclick = () => {
        if (!confirm("delete " + asset.name + "?")) return;
        mutate(() => {
          const doomed = asset.id;
          state.inventory.assets = state.inventory.assets.filter((a) => a.id !== doomed);
          for (const a of state.inventory.assets) {
            for (const key of [
              "parents",
              "powered_by",
              "backup_jobs",
              "depends_on",
              "backed_up_by",
              "fronted_by",
              "monitored_by",
            ]) {
              if (a[key]) a[key] = a[key].filter((x) => x !== doomed);
            }
          }
        }).then(() => showModal(false));
      };
    }

    $("#a-save").onclick = () => {
      const name = $("#a-name").value.trim();
      if (!name) return flash("name is required");
      const next = {
        id: asset.id,
        name,
        type: $("#a-type").value,
        status: $("#a-status").value,
        tags: $("#a-tags").value
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean),
        parents: [...$("#a-parents").selectedOptions].map((o) => o.value),
      };
      $$("[data-field]").forEach((el) => {
        const v = el.value.trim();
        if (v) next[el.dataset.field] = v;
      });
      const custom = {};
      $$("[data-custom]").forEach((el) => {
        const v = el.value.trim();
        if (v) custom[el.dataset.custom] = v;
      });
      if (Object.keys(custom).length) next.custom = custom;
      if (ifaces.length) next.interfaces = ifaces;
      if (ports.length) next.ports = ports;
      $$("[data-rel]").forEach((sel) => {
        const vals = [...sel.selectedOptions].map((o) => o.value);
        if (vals.length) next[sel.dataset.rel] = vals;
      });

      mutate(() => {
        const idx = state.inventory.assets.findIndex((a) => a.id === next.id);
        if (idx >= 0) state.inventory.assets[idx] = next;
        else state.inventory.assets.push(next);
      }).then(() => showModal(false));
    };
  }

  // topbar
  $$(".tab").forEach((btn) => {
    btn.addEventListener("click", () => {
      state.view = btn.dataset.view;
      render();
    });
  });

  $("#search").addEventListener("input", (e) => {
    state.filter = e.target.value;
    if (state.view === "dashboard") return;
    render();
  });

  $("#btn-new").addEventListener("click", () => openAsset(null));

  $("#btn-reload").addEventListener("click", async () => {
    if (!confirm("reload inventory.yml from disk? unsaved UI state is discarded (saves already wrote to disk).")) return;
    try {
      await loadInventory();
      flash("reloaded from disk", true);
    } catch (err) {
      flash(String(err.message || err));
    }
  });

  $("#modal").addEventListener("click", (e) => {
    if (e.target.id === "modal") showModal(false);
  });

  loadInventory().catch((err) => {
    flash(String(err.message || err));
    render();
  });
})();
