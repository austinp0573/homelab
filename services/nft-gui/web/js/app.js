import {
  createStore,
  emptyAddressGroup,
  emptyHelper,
  emptyMap,
  emptyMapEntry,
  emptyPortGroup,
  emptyTable,
  normalizeRuleset,
} from "./store.js";
import { generateConfig, getRuleSyntax, summarizeRule } from "./generator.js";
import { PRESETS, getPreset } from "./presets.js";
import { collectValidation, ruleIssues } from "./validate.js";

const CT_STATES = ["new", "established", "related", "invalid", "untracked"];
const CT_STATUS = ["expected", "seen-reply", "assured", "confirmed", "snat", "dnat"];
const FAMILIES = ["inet", "ip", "ip6", "bridge", "netdev"];
const CHAIN_TYPES = ["filter", "nat", "route"];
const PRIORITIES = ["raw", "mangle", "dstnat", "filter", "security", "srcnat", "-300", "-200", "-100", "0", "100", "200", "300"];
const POLICIES = ["accept", "drop"];
const L4PROTOS = ["", "tcp", "udp", "sctp", "icmp", "icmpv6", "gre", "esp", "ah"];
const VERDICTS = ["accept", "drop", "reject", "return", "jump", "goto", "masquerade", "snat", "dnat", "redirect"];
const REJECT_TYPES_IP = ["port-unreachable", "admin-prohibited", "no-route", "host-unreachable", "prot-unreachable"];
const REJECT_TYPES_COMMON = ["port-unreachable", "admin-prohibited", "no-route"];

const store = createStore();
const ui = {
  tab: "rules",
  selection: { kind: "welcome" },
  copyStatus: "",
  confirm: null,
};

const app = document.getElementById("app");

function hooksForTable(table) {
  if (table.family === "netdev") return ["", "ingress", "egress"];
  return ["", "prerouting", "input", "forward", "output", "postrouting"];
}

function typesForTable(table) {
  if (table.family === "bridge" || table.family === "netdev") return ["filter"];
  return CHAIN_TYPES;
}

function rejectTypesForTable(table) {
  return table.family === "ip" ? REJECT_TYPES_IP : REJECT_TYPES_COMMON;
}

function exportData(state) {
  const issues = collectValidation(state);
  return { issues, config: generateConfig(state, issues) };
}

function downloadText(filename, text) {
  const blob = new Blob([text], { type: "text/plain" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

function importRulesetFromFile() {
  const input = document.createElement("input");
  input.type = "file";
  input.accept = ".json,application/json";
  input.addEventListener("change", async () => {
    const file = input.files && input.files[0];
    if (!file) return;
    try {
      if (file.size > 1024 * 1024) throw new Error("file is too large");
      const parsed = JSON.parse(await file.text());
      const ruleset = normalizeRuleset(parsed);
      askConfirm("replace the current ruleset with this import?", () => {
        store.replaceRuleset(ruleset);
        ui.tab = "rules";
        ui.selection = { kind: "welcome" };
      });
    } catch {
      ui.copyStatus = "import failed";
      render();
      setTimeout(() => {
        ui.copyStatus = "";
        render();
      }, 2000);
    }
  });
  input.click();
}

function el(tag, attrs = {}, children = []) {
  const node = document.createElement(tag);
  let valueProp;
  let selectedProp;
  for (const [key, value] of Object.entries(attrs)) {
    if (key === "className") node.className = value;
    else if (key === "text") node.textContent = value;
    else if (key === "value") valueProp = value;
    else if (key === "selected") selectedProp = value;
    else if (key === "checked") node.checked = !!value;
    else if (key === "disabled") node.disabled = !!value;
    else if (key === "readonly" || key === "readOnly") node.readOnly = !!value;
    else if (key.startsWith("on") && typeof value === "function") node.addEventListener(key.slice(2).toLowerCase(), value);
    else if (value === false || value === null || value === undefined) continue;
    else if (value === true) node.setAttribute(key, "");
    else node.setAttribute(key, value);
  }
  for (const child of [].concat(children)) {
    if (child === null || child === undefined || child === false) continue;
    node.append(child.nodeType ? child : document.createTextNode(String(child)));
  }
  if (valueProp !== undefined) node.value = valueProp;
  if (selectedProp !== undefined) node.selected = !!selectedProp;
  return node;
}

function findTable(state, tableId) {
  return state.tables.find((t) => t.id === tableId) || null;
}

function findChain(state, tableId, chainId) {
  const table = findTable(state, tableId);
  if (!table) return null;
  return table.chains.find((c) => c.id === chainId) || null;
}

function findRule(state, tableId, chainId, ruleId) {
  const chain = findChain(state, tableId, chainId);
  if (!chain) return null;
  return chain.rules.find((r) => r.id === ruleId) || null;
}

function select(kind, ids = {}) {
  ui.selection = { kind, ...ids };
  render();
}

function setTab(tab) {
  ui.tab = tab;
  if (tab === "objects" && ui.selection.kind !== "address" && ui.selection.kind !== "port" && ui.selection.kind !== "objects") {
    ui.selection = { kind: "objects" };
  }
  if (tab === "rules" && ["address", "port", "objects", "presets"].includes(ui.selection.kind)) {
    ui.selection = { kind: "welcome" };
  }
  if (tab === "presets") ui.selection = { kind: "presets" };
  render();
}

function askConfirm(message, onYes) {
  ui.confirm = { message, onYes };
  render();
}

function fieldSelect(value, options, onChange, attrs = {}) {
  const select = el(
    "select",
    {
      ...attrs,
      onChange: (e) => onChange(e.target.value),
    },
    options.map((opt) => {
      const v = typeof opt === "string" ? opt : opt.value;
      const label = typeof opt === "string" ? opt || "(none)" : opt.label;
      return el("option", { value: v }, [label]);
    })
  );
  select.value = value ?? "";
  return select;
}

function textInput(value, onChange, attrs = {}) {
  return el("input", {
    type: "text",
    value: value || "",
    ...attrs,
    onInput: (e) => onChange(e.target.value, { quiet: true }),
    onBlur: () => render(),
  });
}

function textareaInput(value, onChange, attrs = {}) {
  return el(
    "textarea",
    {
      ...attrs,
      value: value || "",
      onInput: (e) => onChange(e.target.value, { quiet: true }),
      onBlur: () => render(),
    }
  );
}

function checkbox(checked, onChange, label, attrs = {}) {
  return el("label", {}, [
    el("input", {
      type: "checkbox",
      checked: !!checked,
      ...attrs,
      onChange: (e) => onChange(e.target.checked),
    }),
    label,
  ]);
}

function focusKey(parts) {
  return parts.filter(Boolean).join(":");
}

function modeValueGroup({
  label,
  mode,
  value,
  groupId,
  groups,
  onMode,
  onValue,
  onGroup,
  valuePlaceholder,
  keyBase,
}) {
  return el("div", { className: "full form-grid" }, [
    el("label", { text: label }),
    el("div", { className: "form-row" }, [
      fieldSelect(
        mode || "none",
        [
          { value: "none", label: "none" },
          { value: "value", label: "literal" },
          { value: "group", label: "group" },
        ],
        onMode,
        { style: "width: 120px", "data-focus": focusKey([keyBase, "mode"]) }
      ),
      mode === "value"
        ? textInput(value, onValue, {
            placeholder: valuePlaceholder,
            style: "flex:1; min-width:180px",
            "data-focus": focusKey([keyBase, "value"]),
          })
        : null,
      mode === "group"
        ? fieldSelect(
            groupId || "",
            [{ value: "", label: "(select group)" }, ...groups.map((g) => ({ value: g.id, label: g.name || g.id }))],
            onGroup,
            { style: "flex:1; min-width:180px", "data-focus": focusKey([keyBase, "group"]) }
          )
        : null,
    ]),
  ]);
}

function renderTopbar() {
  return el("div", { className: "topbar" }, [
    el("div", { className: "brand", text: "nft-gui" }),
    el("div", { className: "tabs" }, [
      el("button", { className: `tab${ui.tab === "rules" ? " active" : ""}`, onClick: () => setTab("rules"), text: "tables & rules" }),
      el("button", { className: `tab${ui.tab === "objects" ? " active" : ""}`, onClick: () => setTab("objects"), text: "groups" }),
      el("button", { className: `tab${ui.tab === "presets" ? " active" : ""}`, onClick: () => setTab("presets"), text: "presets" }),
    ]),
    el("div", { className: "spacer" }),
    el("button", {
      className: "btn small",
      text: "export json",
      onClick: () => downloadText("nft-gui-ruleset.json", JSON.stringify(store.getState(), null, 2) + "\n"),
    }),
    el("button", {
      className: "btn small",
      text: "import json",
      onClick: () => importRulesetFromFile(),
    }),
    el("button", {
      className: "btn danger",
      text: "clear all",
      onClick: () =>
        askConfirm("clear the entire ruleset from this browser?", () => {
          store.clearAll();
          ui.selection = { kind: "welcome" };
          ui.tab = "rules";
        }),
    }),
  ]);
}

function renderSidebar(state) {
  if (ui.tab === "presets") {
    return el("aside", { className: "sidebar" }, [
      el("div", { className: "panel-head" }, [el("h2", { text: "presets" })]),
      el("div", { className: "panel-body hint", text: "load a starter layout. this replaces the current ruleset." }),
    ]);
  }

  if (ui.tab === "objects") {
    return el("aside", { className: "sidebar" }, [
      el("div", { className: "panel-head" }, [el("h2", { text: "groups" })]),
      el("div", { className: "tree-actions" }, [
        el("button", {
          className: "btn small",
          text: "address group",
          onClick: () => {
            const id = store.addAddressGroup({ ...emptyAddressGroup(), name: `hosts_${state.addressGroups.length + 1}` });
            select("address", { id });
          },
        }),
        el("button", {
          className: "btn small",
          text: "port group",
          onClick: () => {
            const id = store.addPortGroup({ ...emptyPortGroup(), name: `ports_${state.portGroups.length + 1}` });
            select("port", { id });
          },
        }),
      ]),
      el("div", { className: "tree-section", text: "address groups" }),
      ...(state.addressGroups.length
        ? state.addressGroups.map((g) =>
            el("button", {
              className: `tree-item${ui.selection.kind === "address" && ui.selection.id === g.id ? " active" : ""}`,
              onClick: () => select("address", { id: g.id }),
            }, [
              g.name || "(unnamed)",
              el("span", { className: "meta", text: g.addrType }),
            ])
          )
        : [el("div", { className: "empty", text: "no address groups" })]),
      el("div", { className: "tree-section", text: "port groups" }),
      ...(state.portGroups.length
        ? state.portGroups.map((g) =>
            el("button", {
              className: `tree-item${ui.selection.kind === "port" && ui.selection.id === g.id ? " active" : ""}`,
              onClick: () => select("port", { id: g.id }),
            }, [
              g.name || "(unnamed)",
              el("span", { className: "meta", text: `${(g.elements || []).filter(Boolean).length}` }),
            ])
          )
        : [el("div", { className: "empty", text: "no port groups" })]),
    ]);
  }

  return el("aside", { className: "sidebar" }, [
    el("div", { className: "panel-head" }, [el("h2", { text: "tables" })]),
    el("div", { className: "tree-actions" }, [
      el("button", {
        className: "btn small",
        text: "add table",
        onClick: () => {
          const id = store.addTable();
          select("table", { tableId: id });
        },
      }),
    ]),
    ...(state.tables.length
      ? state.tables.flatMap((table) => {
          const nodes = [
            el("button", {
              className: `tree-item${ui.selection.kind === "table" && ui.selection.tableId === table.id ? " active" : ""}`,
              onClick: () => select("table", { tableId: table.id }),
            }, [
              `${table.family} ${table.name || "(unnamed)"}`,
              el("span", { className: "meta", text: `${table.chains.length}` }),
            ]),
          ];
          for (const chain of table.chains) {
            nodes.push(
              el("button", {
                className: `tree-item child${ui.selection.kind === "chain" && ui.selection.chainId === chain.id ? " active" : ""}`,
                onClick: () => select("chain", { tableId: table.id, chainId: chain.id }),
              }, [
                chain.name || "(chain)",
                el("span", { className: "meta", text: chain.hook || "regular" }),
              ])
            );
          }
          return nodes;
        })
      : [el("div", { className: "empty", text: "no tables yet. add a table or load a preset." })]),
  ]);
}

function renderAddressEditor(state, group) {
  if (!group) return el("div", { className: "empty", text: "address group not found" });
  const k = `addr:${group.id}`;
  return el("div", { className: "panel-body" }, [
    el("div", { className: "section" }, [
      el("div", { className: "form-row", style: "margin-bottom:10px" }, [
        el("button", {
          className: "btn danger small",
          text: "delete group",
          onClick: () =>
            askConfirm(`delete address group ${group.name || group.id}?`, () => {
              store.removeAddressGroup(group.id);
              ui.selection = { kind: "objects" };
            }),
        }),
      ]),
      el("div", { className: "form-grid" }, [
        el("label", { text: "name" }),
        textInput(group.name, (v, opts) => store.updateAddressGroup(group.id, { name: v }, opts), {
          placeholder: "trusted_hosts",
          "data-focus": focusKey([k, "name"]),
        }),
        el("label", { text: "address type" }),
        fieldSelect(group.addrType, ["ipv4", "ipv6"], (v) => store.updateAddressGroup(group.id, { addrType: v }), {
          "data-focus": focusKey([k, "type"]),
        }),
        el("label", { text: "comment" }),
        textInput(group.comment, (v, opts) => store.updateAddressGroup(group.id, { comment: v }, opts), {
          "data-focus": focusKey([k, "comment"]),
        }),
        el("label", { text: "set timeout" }),
        textInput(group.timeout, (v, opts) => store.updateAddressGroup(group.id, { timeout: v }, opts), {
          placeholder: "optional, for example 1h",
          "data-focus": focusKey([k, "timeout"]),
        }),
        el("label", { text: "elements" }),
        el("div", {}, [
          textareaInput(
            (group.elements || []).join("\n"),
            (v, opts) =>
              store.updateAddressGroup(
                group.id,
                {
                  // preserve blank lines while editing (filtered on emit)
                  elements: v.split("\n").map((s) => s.trim()),
                },
                opts
              ),
            {
              placeholder: "one ip or cidr per line\n10.0.0.0/8\n192.168.1.10",
              "data-focus": focusKey([k, "elements"]),
            }
          ),
          el("p", { className: "hint", text: "emitted as an nft set with interval support when referenced. a timeout applies to every loaded element." }),
        ]),
      ]),
    ]),
  ]);
}

function renderPortEditor(state, group) {
  if (!group) return el("div", { className: "empty", text: "port group not found" });
  const k = `port:${group.id}`;
  return el("div", { className: "panel-body" }, [
    el("div", { className: "section" }, [
      el("div", { className: "form-row", style: "margin-bottom:10px" }, [
        el("button", {
          className: "btn danger small",
          text: "delete group",
          onClick: () =>
            askConfirm(`delete port group ${group.name || group.id}?`, () => {
              store.removePortGroup(group.id);
              ui.selection = { kind: "objects" };
            }),
        }),
      ]),
      el("div", { className: "form-grid" }, [
        el("label", { text: "name" }),
        textInput(group.name, (v, opts) => store.updatePortGroup(group.id, { name: v }, opts), {
          placeholder: "web_ports",
          "data-focus": focusKey([k, "name"]),
        }),
        el("label", { text: "comment" }),
        textInput(group.comment, (v, opts) => store.updatePortGroup(group.id, { comment: v }, opts), {
          "data-focus": focusKey([k, "comment"]),
        }),
        el("label", { text: "set timeout" }),
        textInput(group.timeout, (v, opts) => store.updatePortGroup(group.id, { timeout: v }, opts), {
          placeholder: "optional, for example 1h",
          "data-focus": focusKey([k, "timeout"]),
        }),
        el("label", { text: "elements" }),
        el("div", {}, [
          textareaInput(
            (group.elements || []).join("\n"),
            (v, opts) =>
              store.updatePortGroup(
                group.id,
                {
                  // preserve blank lines while editing (filtered on emit)
                  elements: v.split("\n").map((s) => s.trim()),
                },
                opts
              ),
            {
              placeholder: "one port or range per line\n22\n80\n443\n8000-8100",
              "data-focus": focusKey([k, "elements"]),
            }
          ),
          el("p", { className: "hint", text: "emitted as type inet_service with interval support when referenced." }),
        ]),
      ]),
    ]),
  ]);
}

function renderMapEditor(table, map) {
  const k = `map:${map.id}`;
  return el("div", { className: "card" }, [
    el("div", { className: "card-head" }, [
      el("strong", { text: map.name || "(unnamed map)" }),
      el("div", { className: "spacer" }),
      el("button", {
        className: "btn danger small",
        text: "delete",
        onClick: () => store.removeMap(table.id, map.id),
      }),
    ]),
    el("div", { className: "form-grid object-grid" }, [
      el("label", { text: "name" }),
      textInput(map.name, (v, opts) => store.updateMap(table.id, map.id, { name: v }, opts), {
        placeholder: "client_policy",
        "data-focus": focusKey([k, "name"]),
      }),
      el("label", { text: "key type" }),
      fieldSelect(map.keyType, ["ipv4_addr", "ipv6_addr"], (v) => store.updateMap(table.id, map.id, { keyType: v }), {
        "data-focus": focusKey([k, "keyType"]),
      }),
      el("label", { text: "value type" }),
      fieldSelect(map.valueType, ["verdict", "mark"], (v) => store.updateMap(table.id, map.id, { valueType: v }), {
        "data-focus": focusKey([k, "valueType"]),
      }),
      el("label", { text: "comment" }),
      textInput(map.comment, (v, opts) => store.updateMap(table.id, map.id, { comment: v }, opts), {
        "data-focus": focusKey([k, "comment"]),
      }),
    ]),
    el("div", { className: "object-entries" }, [
      el("div", { className: "muted", text: map.valueType === "verdict" ? "address to verdict entries" : "address to packet mark entries" }),
      ...(map.entries || []).map((entry) =>
        el("div", { className: "form-row" }, [
          textInput(entry.key, (v, opts) => store.updateMapEntry(table.id, map.id, entry.id, { key: v }, opts), {
            placeholder: map.keyType === "ipv6_addr" ? "2001:db8::10" : "192.0.2.10",
            style: "flex: 1; min-width: 150px",
            "data-focus": focusKey([k, entry.id, "key"]),
          }),
          map.valueType === "verdict"
            ? fieldSelect(entry.value || "accept", ["accept", "drop", "return"], (v) => store.updateMapEntry(table.id, map.id, entry.id, { value: v }), {
                style: "width: 120px",
                "data-focus": focusKey([k, entry.id, "value"]),
              })
            : textInput(entry.value, (v, opts) => store.updateMapEntry(table.id, map.id, entry.id, { value: v }, opts), {
                placeholder: "0x1",
                style: "width: 120px",
                "data-focus": focusKey([k, entry.id, "value"]),
              }),
          el("button", {
            className: "btn danger small",
            text: "remove",
            onClick: () => store.removeMapEntry(table.id, map.id, entry.id),
          }),
        ])
      ),
      el("button", {
        className: "btn small",
        text: "add entry",
        onClick: () => store.addMapEntry(table.id, map.id, emptyMapEntry()),
      }),
    ]),
  ]);
}

function renderHelperEditor(table, helper) {
  const k = `helper:${helper.id}`;
  return el("div", { className: "card" }, [
    el("div", { className: "card-head" }, [
      el("strong", { text: helper.name || "(unnamed helper)" }),
      el("div", { className: "spacer" }),
      el("button", {
        className: "btn danger small",
        text: "delete",
        onClick: () => store.removeHelper(table.id, helper.id),
      }),
    ]),
    el("div", { className: "form-grid object-grid" }, [
      el("label", { text: "name" }),
      textInput(helper.name, (v, opts) => store.updateHelper(table.id, helper.id, { name: v }, opts), {
        placeholder: "ftp_helper",
        "data-focus": focusKey([k, "name"]),
      }),
      el("label", { text: "helper type" }),
      fieldSelect(helper.type, ["ftp", "tftp"], (v) => {
        store.updateHelper(table.id, helper.id, { type: v, protocol: v === "ftp" ? "tcp" : "udp" });
      }, { "data-focus": focusKey([k, "type"]) }),
      el("label", { text: "layer 3" }),
      fieldSelect(helper.l3proto, ["ip", "ip6"], (v) => store.updateHelper(table.id, helper.id, { l3proto: v }), {
        "data-focus": focusKey([k, "l3proto"]),
      }),
      el("label", { text: "comment" }),
      textInput(helper.comment, (v, opts) => store.updateHelper(table.id, helper.id, { comment: v }, opts), {
        "data-focus": focusKey([k, "comment"]),
      }),
    ]),
    el("p", { className: "hint", text: `uses ${helper.protocol}; the kernel must have the matching connection tracking helper available.` }),
  ]);
}

function renderTableEditor(state, table) {
  if (!table) return el("div", { className: "empty", text: "table not found" });
  const k = `table:${table.id}`;
  return el("div", { className: "panel-body" }, [
    el("div", { className: "section" }, [
      el("div", { className: "form-row", style: "margin-bottom:10px" }, [
        el("button", {
          className: "btn small",
          text: "add chain",
          onClick: () => {
            const id = store.addChain(table.id);
            select("chain", { tableId: table.id, chainId: id });
          },
        }),
        el("button", {
          className: "btn danger small",
          text: "delete table",
          onClick: () =>
            askConfirm(`delete table ${table.family} ${table.name}?`, () => {
              store.removeTable(table.id);
              ui.selection = { kind: "welcome" };
            }),
        }),
      ]),
      el("div", { className: "form-grid" }, [
        el("label", { text: "family" }),
        fieldSelect(table.family, FAMILIES, (v) => store.updateTable(table.id, { family: v }), {
          "data-focus": focusKey([k, "family"]),
        }),
        el("label", { text: "name" }),
        textInput(table.name, (v, opts) => store.updateTable(table.id, { name: v }, opts), {
          placeholder: "filter",
          "data-focus": focusKey([k, "name"]),
        }),
        el("label", { text: "comment" }),
        textInput(table.comment, (v, opts) => store.updateTable(table.id, { comment: v }, opts), {
          "data-focus": focusKey([k, "comment"]),
        }),
      ]),
    ]),
    el("div", { className: "section" }, [
      el("div", { className: "section-head" }, [
        el("h3", { text: "maps" }),
        el("button", {
          className: "btn small",
          text: "add map",
          onClick: () => store.addMap(table.id, emptyMap()),
        }),
      ]),
      (table.maps || []).length
        ? el("div", { className: "list" }, (table.maps || []).map((map) => renderMapEditor(table, map)))
        : el("p", { className: "hint", text: "maps provide typed address to verdict or packet mark lookups." }),
    ]),
    el("div", { className: "section" }, [
      el("div", { className: "section-head" }, [
        el("h3", { text: "connection tracking helpers" }),
        el("button", {
          className: "btn small",
          text: "add helper",
          onClick: () => store.addHelper(table.id, emptyHelper()),
        }),
      ]),
      (table.helpers || []).length
        ? el("div", { className: "list" }, (table.helpers || []).map((helper) => renderHelperEditor(table, helper)))
        : el("p", { className: "hint", text: "optional ftp and tftp helpers. availability depends on kernel modules." }),
    ]),
    el("div", { className: "section" }, [
      el("h3", { text: "chains" }),
      table.chains.length
        ? el(
            "div",
            { className: "list" },
            table.chains.map((c) =>
              el("div", { className: "card" }, [
                el("div", { className: "card-head" }, [
                  el("strong", { text: c.name || "(unnamed)" }),
                  el("span", { className: "muted", text: c.hook ? `${c.type}/${c.hook}` : "regular" }),
                  el("div", { className: "spacer" }),
                  el("button", {
                    className: "btn small",
                    text: "edit",
                    onClick: () => select("chain", { tableId: table.id, chainId: c.id }),
                  }),
                ]),
                el("div", { className: "muted", text: `${c.rules.length} rule(s), policy ${c.policy}` }),
              ])
            )
          )
        : el("p", { className: "hint", text: "no chains in this table yet." }),
    ]),
  ]);
}

function renderRuleCard(state, table, chain, rule, index) {
  const open = ui.selection.kind === "rule" && ui.selection.ruleId === rule.id;
  const issues = ruleIssues(state, table, chain, rule);
  return el("div", { className: `card${issues.some((item) => item.level === "error") ? " has-errors" : ""}` }, [
    el("div", { className: "card-head" }, [
      el("strong", { text: `#${index + 1}` }),
      el("div", { className: "spacer" }),
      el("button", {
        className: "btn small",
        text: "up",
        disabled: index === 0,
        onClick: () => store.moveRule(table.id, chain.id, rule.id, "up"),
      }),
      el("button", {
        className: "btn small",
        text: "down",
        disabled: index === chain.rules.length - 1,
        onClick: () => store.moveRule(table.id, chain.id, rule.id, "down"),
      }),
      el("button", {
        className: "btn small",
        text: "duplicate",
        onClick: () => {
          const id = store.duplicateRule(table.id, chain.id, rule.id);
          if (id) select("rule", { tableId: table.id, chainId: chain.id, ruleId: id });
        },
      }),
      el("button", {
        className: "btn small",
        text: open ? "close" : "edit",
        onClick: () => {
          if (open) select("chain", { tableId: table.id, chainId: chain.id });
          else select("rule", { tableId: table.id, chainId: chain.id, ruleId: rule.id });
        },
      }),
      el("button", {
        className: "btn danger small",
        text: "delete",
        onClick: () =>
          askConfirm("delete this rule?", () => {
            store.removeRule(table.id, chain.id, rule.id);
            select("chain", { tableId: table.id, chainId: chain.id });
          }),
      }),
    ]),
    el("div", { className: "rule-summary", text: summarizeRule(rule, state, table) }),
    open ? renderRuleEditor(state, table, chain, rule) : null,
  ]);
}

function renderRuleFeedback(state, table, chain, rule) {
  const rendered = getRuleSyntax(state, table, chain, rule);
  const errors = rendered.issues.filter((item) => item.level === "error");
  const warnings = rendered.issues.filter((item) => item.level !== "error");
  return el("div", { id: `rule-feedback-${rule.id}`, className: `rule-feedback${errors.length ? " errors" : ""}` }, [
    el("div", { className: "rule-preview", text: rendered.line || "# rule will be skipped until errors are fixed" }),
    ...(errors.length ? errors.map((item) => el("div", { className: "rule-error", text: item.message })) : []),
    ...(warnings.length ? warnings.map((item) => el("div", { className: "rule-warning", text: item.message })) : []),
  ]);
}

function renderRuleEditor(state, table, chain, rule) {
  const patch = (p, opts) => store.updateRule(table.id, chain.id, rule.id, p, opts);
  const showNat = ["masquerade", "snat", "dnat", "redirect"].includes(rule.verdict);
  const showJump = rule.verdict === "jump" || rule.verdict === "goto";
  const showReject = rule.verdict === "reject";
  const verdictMap = rule.mapId && (table.maps || []).find((map) => map.id === rule.mapId)?.valueType === "verdict";
  const chainNames = table.chains.map((c) => c.name).filter((name) => name && name !== chain.name);
  const k = `rule:${rule.id}`;

  return el("div", { className: "form-grid" }, [
    el("label", { text: "enabled" }),
    el("div", { className: "checks" }, [
      checkbox(rule.enabled !== false, (v) => patch({ enabled: v }), "include in output", {
        "data-focus": focusKey([k, "enabled"]),
      }),
    ]),
    el("label", { text: "comment" }),
    textInput(rule.comment, (v, opts) => patch({ comment: v }, opts), { "data-focus": focusKey([k, "comment"]) }),
    el("label", { text: "iifname" }),
    textInput(rule.iifname, (v, opts) => patch({ iifname: v }, opts), {
      placeholder: "eth0 or lo,wg0",
      "data-focus": focusKey([k, "iifname"]),
    }),
    el("label", { text: "oifname" }),
    textInput(rule.oifname, (v, opts) => patch({ oifname: v }, opts), {
      placeholder: "eth0",
      "data-focus": focusKey([k, "oifname"]),
    }),
    el("label", { text: "protocol" }),
    fieldSelect(
      rule.l4proto || "",
      L4PROTOS.map((p) => ({ value: p, label: p || "(any)" })),
      (v) => patch({ l4proto: v }),
      { "data-focus": focusKey([k, "l4proto"]) }
    ),

    modeValueGroup({
      label: "saddr",
      mode: rule.saddrMode,
      value: rule.saddrValue,
      groupId: rule.saddrGroupId,
      groups: state.addressGroups,
      onMode: (v) => patch({ saddrMode: v }),
      onValue: (v, opts) => patch({ saddrValue: v }, opts),
      onGroup: (v) => patch({ saddrGroupId: v }),
      valuePlaceholder: "10.0.0.0/8 or list",
      keyBase: focusKey([k, "saddr"]),
    }),
    modeValueGroup({
      label: "daddr",
      mode: rule.daddrMode,
      value: rule.daddrValue,
      groupId: rule.daddrGroupId,
      groups: state.addressGroups,
      onMode: (v) => patch({ daddrMode: v }),
      onValue: (v, opts) => patch({ daddrValue: v }, opts),
      onGroup: (v) => patch({ daddrGroupId: v }),
      valuePlaceholder: "192.168.1.10",
      keyBase: focusKey([k, "daddr"]),
    }),
    modeValueGroup({
      label: "sport",
      mode: rule.sportMode,
      value: rule.sportValue,
      groupId: rule.sportGroupId,
      groups: state.portGroups,
      onMode: (v) => patch({ sportMode: v }),
      onValue: (v, opts) => patch({ sportValue: v }, opts),
      onGroup: (v) => patch({ sportGroupId: v }),
      valuePlaceholder: "1024-65535",
      keyBase: focusKey([k, "sport"]),
    }),
    modeValueGroup({
      label: "dport",
      mode: rule.dportMode,
      value: rule.dportValue,
      groupId: rule.dportGroupId,
      groups: state.portGroups,
      onMode: (v) => patch({ dportMode: v }),
      onValue: (v, opts) => patch({ dportValue: v }, opts),
      onGroup: (v) => patch({ dportGroupId: v }),
      valuePlaceholder: "22,80,443",
      keyBase: focusKey([k, "dport"]),
    }),

    el("label", { text: "ct state" }),
    el(
      "div",
      { className: "checks" },
      CT_STATES.map((s) =>
        checkbox(
          (rule.ctState || []).includes(s),
          (checked) => {
            const set = new Set(rule.ctState || []);
            if (checked) set.add(s);
            else set.delete(s);
            patch({ ctState: [...set] });
          },
          s,
          { "data-focus": focusKey([k, "ct", s]) }
        )
      )
    ),
    el("label", { text: "ct status" }),
    el(
      "div",
      { className: "checks" },
      CT_STATUS.map((status) =>
        checkbox(
          (rule.ctStatus || []).includes(status),
          (checked) => {
            const set = new Set(rule.ctStatus || []);
            if (checked) set.add(status);
            else set.delete(status);
            patch({ ctStatus: [...set] });
          },
          status,
          { "data-focus": focusKey([k, "ct-status", status]) }
        )
      )
    ),
    el("label", { text: "ct direction" }),
    fieldSelect(rule.ctDirection || "", [{ value: "", label: "(any)" }, "original", "reply"], (v) => patch({ ctDirection: v }), {
      "data-focus": focusKey([k, "ct-direction"]),
    }),
    el("label", { text: "ct mark equals" }),
    textInput(rule.ctMark, (v, opts) => patch({ ctMark: v }, opts), {
      placeholder: "0x1",
      "data-focus": focusKey([k, "ct-mark"]),
    }),
    el("label", { text: "ct helper" }),
    fieldSelect(
      rule.ctHelperId || "",
      [{ value: "", label: "(none)" }, ...(table.helpers || []).map((helper) => ({ value: helper.id, label: helper.name || helper.id }))],
      (v) => patch({ ctHelperId: v }),
      { "data-focus": focusKey([k, "ct-helper"]) }
    ),
    el("label", { text: "tcp flags" }),
    fieldSelect(rule.tcpFlags || "", [
      { value: "", label: "(none)" },
      { value: "syn", label: "syn only" },
      { value: "syn,ack", label: "syn,ack" },
      { value: "fin,syn,rst,ack", label: "fin,syn,rst,ack" },
    ], (v) => patch({ tcpFlags: v }), {
      "data-focus": focusKey([k, "tcpFlags"]),
    }),
    el("label", { text: "icmp type" }),
    textInput(rule.icmpType, (v, opts) => patch({ icmpType: v }, opts), {
      placeholder: "echo-request",
      "data-focus": focusKey([k, "icmpType"]),
    }),
    el("label", { text: "icmpv6 type" }),
    textInput(rule.icmpv6Type, (v, opts) => patch({ icmpv6Type: v }, opts), {
      placeholder: "nd-router-advert",
      "data-focus": focusKey([k, "icmpv6Type"]),
    }),
    el("label", { text: "packet mark equals" }),
    textInput(rule.metaMark, (v, opts) => patch({ metaMark: v }, opts), {
      placeholder: "0x1",
      "data-focus": focusKey([k, "metaMark"]),
    }),
    el("label", { text: "map action" }),
    fieldSelect(
      rule.mapId || "",
      [{ value: "", label: "(none)" }, ...(table.maps || []).map((map) => ({ value: map.id, label: `${map.name || map.id} (${map.valueType})` }))],
      (v) => patch({ mapId: v }),
      { "data-focus": focusKey([k, "map-id"]) }
    ),
    rule.mapId
      ? el("label", { text: "map address" })
      : null,
    rule.mapId
      ? fieldSelect(rule.mapSelector || "saddr", ["saddr", "daddr"], (v) => patch({ mapSelector: v }), {
          "data-focus": focusKey([k, "map-selector"]),
        })
      : null,
    el("label", { text: "counter" }),
    el("div", { className: "checks" }, [
      checkbox(!!rule.counter, (v) => patch({ counter: v }), "add counter", {
        "data-focus": focusKey([k, "counter"]),
      }),
    ]),
    el("label", { text: "rate limit" }),
    el("div", { className: "form-row" }, [
      fieldSelect(rule.limitMode || "none", [
        { value: "none", label: "(none)" },
        { value: "packets", label: "packets" },
        { value: "bytes", label: "bytes" },
      ], (v) => patch({ limitMode: v }), {
        style: "width: 120px",
        "data-focus": focusKey([k, "limit-mode"]),
      }),
      rule.limitMode && rule.limitMode !== "none"
        ? textInput(rule.limitRate, (v, opts) => patch({ limitRate: v }, opts), {
            placeholder: "10",
            style: "width: 90px",
            "data-focus": focusKey([k, "limit-rate"]),
          })
        : null,
      rule.limitMode === "bytes"
        ? fieldSelect(rule.limitBytesUnit || "kbytes", ["bytes", "kbytes", "mbytes"], (v) => patch({ limitBytesUnit: v }), {
            style: "width: 110px",
            "data-focus": focusKey([k, "limit-bytes-unit"]),
          })
        : null,
      rule.limitMode && rule.limitMode !== "none"
        ? fieldSelect(rule.limitUnit || "second", ["second", "minute", "hour", "day"], (v) => patch({ limitUnit: v }), {
            style: "width: 110px",
            "data-focus": focusKey([k, "limit-unit"]),
          })
        : null,
    ]),
    rule.limitMode && rule.limitMode !== "none" ? el("label", { text: "limit burst" }) : null,
    rule.limitMode && rule.limitMode !== "none"
      ? textInput(rule.limitBurst, (v, opts) => patch({ limitBurst: v }, opts), {
          placeholder: rule.limitMode === "bytes" ? "optional bytes" : "optional packets",
          "data-focus": focusKey([k, "limit-burst"]),
        })
      : null,
    el("label", { text: "log prefix" }),
    textInput(rule.logPrefix, (v, opts) => patch({ logPrefix: v }, opts), {
      placeholder: "nft-gui-drop: ",
      "data-focus": focusKey([k, "logPrefix"]),
    }),
    el("label", { text: "log flags" }),
    fieldSelect(rule.logFlags || "", [
      { value: "", label: "(none)" },
      "all",
      "tcp sequence",
      "skuid",
      "ether",
      "ip options",
    ], (v) => patch({ logFlags: v }), {
      "data-focus": focusKey([k, "logFlags"]),
    }),
    el("label", { text: "log level" }),
    fieldSelect(rule.logLevel || "", [
      { value: "", label: "(default)" },
      "emerg",
      "alert",
      "crit",
      "err",
      "warn",
      "notice",
      "info",
      "debug",
    ], (v) => patch({ logLevel: v }), {
      "data-focus": focusKey([k, "logLevel"]),
    }),
    el("label", { text: "verdict" }),
    verdictMap
      ? el("div", { className: "hint", text: "supplied by the selected verdict map" })
      : fieldSelect(rule.verdict, VERDICTS, (v) => patch({ verdict: v }), {
          "data-focus": focusKey([k, "verdict"]),
        }),
    showReject && !verdictMap ? el("label", { text: "reject type" }) : null,
    showReject && !verdictMap
      ? fieldSelect(rule.rejectType || "port-unreachable", rejectTypesForTable(table), (v) => patch({ rejectType: v }), {
          "data-focus": focusKey([k, "rejectType"]),
        })
      : null,
    showJump && !verdictMap ? el("label", { text: "target chain" }) : null,
    showJump && !verdictMap
      ? fieldSelect(
          rule.jumpChain || "",
          [{ value: "", label: "(select)" }, ...chainNames.map((n) => ({ value: n, label: n }))],
          (v) => patch({ jumpChain: v }),
          { "data-focus": focusKey([k, "jumpChain"]) }
        )
      : null,
    showNat && !verdictMap && rule.verdict !== "masquerade" && rule.verdict !== "redirect" ? el("label", { text: "nat address" }) : null,
    showNat && !verdictMap && rule.verdict !== "masquerade" && rule.verdict !== "redirect"
      ? textInput(rule.natAddr, (v, opts) => patch({ natAddr: v }, opts), {
          placeholder: "203.0.113.10",
          "data-focus": focusKey([k, "natAddr"]),
        })
      : null,
    showNat && !verdictMap ? el("label", { text: "nat port" }) : null,
    showNat && !verdictMap
      ? textInput(rule.natPort, (v, opts) => patch({ natPort: v }, opts), {
          placeholder: rule.verdict === "redirect" ? "required" : "optional",
          "data-focus": focusKey([k, "natPort"]),
        })
      : null,
    el("div", { className: "full" }, [
      verdictMap
        ? el("p", { className: "hint", text: "a verdict map supplies the verdict when an entry matches. unmatched packets continue to the next rule." })
        : null,
      renderRuleFeedback(state, table, chain, rule),
    ]),
  ]);
}

function renderChainEditor(state, table, chain) {
  if (!table || !chain) return el("div", { className: "empty", text: "chain not found" });
  const k = `chain:${chain.id}`;
  return el("div", { className: "panel-body" }, [
    el("div", { className: "section" }, [
      el("div", { className: "form-row", style: "margin-bottom:10px" }, [
        el("button", {
          className: "btn small",
          text: "add rule",
          onClick: () => {
            const id = store.addRule(table.id, chain.id);
            select("rule", { tableId: table.id, chainId: chain.id, ruleId: id });
          },
        }),
        el("button", {
          className: "btn danger small",
          text: "delete chain",
          onClick: () =>
            askConfirm(`delete chain ${chain.name}?`, () => {
              store.removeChain(table.id, chain.id);
              select("table", { tableId: table.id });
            }),
        }),
      ]),
      el("div", { className: "form-grid" }, [
        el("label", { text: "name" }),
        textInput(chain.name, (v, opts) => store.updateChain(table.id, chain.id, { name: v }, opts), {
          "data-focus": focusKey([k, "name"]),
        }),
        el("label", { text: "type" }),
        fieldSelect(chain.type, typesForTable(table), (v) => store.updateChain(table.id, chain.id, { type: v }), {
          "data-focus": focusKey([k, "type"]),
        }),
        el("label", { text: "hook" }),
        fieldSelect(
          chain.hook || "",
          hooksForTable(table).map((h) => ({ value: h, label: h || "(none / regular chain)" })),
          (v) => store.updateChain(table.id, chain.id, { hook: v }),
          { "data-focus": focusKey([k, "hook"]) }
        ),
        el("label", { text: "priority" }),
        fieldSelect(String(chain.priority), PRIORITIES, (v) => store.updateChain(table.id, chain.id, { priority: v }), {
          "data-focus": focusKey([k, "priority"]),
        }),
        chain.type === "filter" ? el("label", { text: "policy" }) : null,
        chain.type === "filter"
          ? fieldSelect(chain.policy, POLICIES, (v) => store.updateChain(table.id, chain.id, { policy: v }), {
              "data-focus": focusKey([k, "policy"]),
            })
          : null,
        table.family === "netdev" && chain.hook ? el("label", { text: "device" }) : null,
        table.family === "netdev" && chain.hook
          ? textInput(chain.device, (v, opts) => store.updateChain(table.id, chain.id, { device: v }, opts), {
              placeholder: "eth0",
              "data-focus": focusKey([k, "device"]),
            })
          : null,
        el("label", { text: "comment" }),
        textInput(chain.comment, (v, opts) => store.updateChain(table.id, chain.id, { comment: v }, opts), {
          "data-focus": focusKey([k, "comment"]),
        }),
      ]),
      el("p", {
        className: "hint",
        text: "leave hook empty for a regular chain used with jump or goto. netdev base chains need a device. nat chains use prerouting, input, output, or postrouting. forward rules need IP forwarding enabled outside nftables.",
      }),
    ]),
    el("div", { className: "section" }, [
      el("h3", { text: "rules" }),
      chain.rules.length
        ? el(
            "div",
            { className: "list" },
            chain.rules.map((rule, index) => renderRuleCard(state, table, chain, rule, index))
          )
        : el("p", { className: "hint", text: "no rules yet." }),
    ]),
  ]);
}

function renderPresets() {
  return el("div", { className: "panel-body" }, [
    el("p", { className: "hint", text: "loading a preset replaces the current ruleset stored in this browser." }),
    el(
      "div",
      { className: "presets" },
      PRESETS.map((preset) =>
        el("div", { className: "preset" }, [
          el("h3", { text: preset.name }),
          el("div", { className: "muted", text: preset.description }),
          el("div", {}, [
            el("button", {
              className: "btn primary",
              text: preset.id === "blank" ? "reset to blank" : "load preset",
              onClick: () =>
                askConfirm(`replace the current ruleset with "${preset.name}"?`, () => {
                  const built = getPreset(preset.id).build();
                  store.replaceRuleset(built);
                  ui.tab = "rules";
                  ui.selection = built.tables[0]
                    ? { kind: "table", tableId: built.tables[0].id }
                    : { kind: "welcome" };
                }),
            }),
          ]),
        ])
      )
    ),
  ]);
}

function renderWelcome() {
  return el("div", { className: "panel-body" }, [
    el("h3", { text: "nftables config builder" }),
    el("p", {
      className: "hint",
      text: "this ui only generates config text. it does not apply rules to any host.",
    }),
    el("div", { className: "list" }, [
      el("div", { className: "card", text: "1. optionally load a preset" }),
      el("div", { className: "card", text: "2. create address/port groups for reusable sets" }),
      el("div", { className: "card", text: "3. add tables, chains, and rules" }),
      el("div", { className: "card", text: "4. copy the generated config from the right panel" }),
    ]),
    el("div", { className: "form-row", style: "margin-top:14px" }, [
      el("button", {
        className: "btn primary",
        text: "add table",
        onClick: () => {
          const id = store.addTable();
          select("table", { tableId: id });
        },
      }),
      el("button", {
        className: "btn",
        text: "open presets",
        onClick: () => setTab("presets"),
      }),
    ]),
  ]);
}

function renderEditor(state) {
  let title = "editor";
  let body;

  if (ui.tab === "presets" || ui.selection.kind === "presets") {
    title = "presets";
    body = renderPresets();
  } else if (ui.selection.kind === "address") {
    title = "address group";
    body = renderAddressEditor(state, state.addressGroups.find((g) => g.id === ui.selection.id));
  } else if (ui.selection.kind === "port") {
    title = "port group";
    body = renderPortEditor(state, state.portGroups.find((g) => g.id === ui.selection.id));
  } else if (ui.selection.kind === "objects") {
    title = "groups";
    body = el("div", { className: "panel-body" }, [
      el("p", { className: "hint", text: "select or create an address/port group. groups become nft sets when a rule references them." }),
    ]);
  } else if (ui.selection.kind === "table") {
    title = "table";
    body = renderTableEditor(state, findTable(state, ui.selection.tableId));
  } else if (ui.selection.kind === "chain" || ui.selection.kind === "rule") {
    title = ui.selection.kind === "rule" ? "chain / rule" : "chain";
    body = renderChainEditor(
      state,
      findTable(state, ui.selection.tableId),
      findChain(state, ui.selection.tableId, ui.selection.chainId)
    );
  } else {
    title = "start";
    body = renderWelcome();
  }

  return el("main", { className: "editor" }, [
    el("div", { className: "panel-head" }, [el("h2", { text: title })]),
    body,
  ]);
}

function copyConfig(config) {
  navigator.clipboard.writeText(config)
    .then(() => {
      ui.copyStatus = "copied";
      render();
      setTimeout(() => {
        ui.copyStatus = "";
        render();
      }, 1500);
    })
    .catch(() => {
      const area = document.getElementById("config-output");
      if (area) {
        area.focus();
        area.select();
        ui.copyStatus = "select and copy manually";
      } else {
        ui.copyStatus = "copy failed";
      }
      render();
    });
}

function requestExport(action) {
  const result = exportData(store.getState());
  const errors = result.issues.filter((item) => item.level === "error");
  if (errors.length) {
    askConfirm(`${errors.length} error(s) are shown. invalid rules and objects will be skipped in the generated file. continue?`, () => action(result.config));
  } else {
    action(result.config);
  }
}

function renderPreview(state) {
  const { issues, config } = exportData(state);
  const errors = issues.filter((item) => item.level === "error");
  const warnings = issues.filter((item) => item.level !== "error");
  return el("section", { className: "preview" }, [
    el("div", { className: "preview-toolbar" }, [
      el("strong", { text: "generated config" }),
      el("button", {
        className: "btn primary small",
        text: "copy",
        onClick: () => requestExport(copyConfig),
      }),
      el("button", {
        className: "btn small",
        text: "download .nft",
        onClick: () => requestExport((latest) => downloadText("nftables.conf", latest)),
      }),
      el("span", { className: `status${ui.copyStatus === "copied" ? " ok" : ""}`, text: ui.copyStatus }),
    ]),
    el("div", { className: "preview-options" }, [
      checkbox(state.flushRuleset !== false, (v) => store.setFlushRuleset(v), "flush ruleset", {
        "data-focus": "flush-ruleset",
      }),
    ]),
    el(
      "div",
      { id: "warnings-box", className: issues.length ? `warnings${errors.length ? " errors" : ""}` : "warnings empty-warnings" },
      issues.length
        ? [
            el("div", { className: "warnings-title", text: `${errors.length ? `${errors.length} error(s)` : "no errors"}${warnings.length ? `, ${warnings.length} warning(s)` : ""}` }),
            ...issues.map((item) => el("div", { text: `${item.level}: ${item.message}` })),
          ]
        : [el("div", { className: "muted", text: "no errors or warnings" })]
    ),
    el("textarea", {
      id: "config-output",
      readOnly: true,
      spellcheck: "false",
      value: config,
      onCopy: (e) => {
        if (!errors.length) return;
        e.preventDefault();
        requestExport(copyConfig);
      },
    }),
  ]);
}

function renderModal() {
  if (!ui.confirm) return null;
  return el("div", { className: "modal-back" }, [
    el("div", { className: "modal", role: "dialog", "aria-modal": "true", "aria-label": "confirm action" }, [
      el("h3", { text: "confirm" }),
      el("p", { text: ui.confirm.message }),
      el("div", { className: "modal-actions" }, [
        el("button", {
          className: "btn",
          text: "cancel",
          onClick: () => {
            ui.confirm = null;
            render();
          },
        }),
        el("button", {
          className: "btn danger",
          text: "continue",
          onClick: () => {
            const fn = ui.confirm.onYes;
            ui.confirm = null;
            fn();
            render();
          },
        }),
      ]),
    ]),
  ]);
}

function refreshPreview() {
  const state = store.getState();
  const { issues, config } = exportData(state);
  const errors = issues.filter((item) => item.level === "error");
  const warnings = issues.filter((item) => item.level !== "error");

  const area = document.getElementById("config-output");
  if (area) {
    const scroll = area.scrollTop;
    area.value = config;
    area.scrollTop = scroll;
  }

  const box = document.getElementById("warnings-box");
  if (box) {
    box.className = issues.length ? `warnings${errors.length ? " errors" : ""}` : "warnings empty-warnings";
    box.replaceChildren(
      ...(issues.length
        ? [
            el("div", { className: "warnings-title", text: `${errors.length ? `${errors.length} error(s)` : "no errors"}${warnings.length ? `, ${warnings.length} warning(s)` : ""}` }),
            ...issues.map((item) => el("div", { text: `${item.level}: ${item.message}` })),
          ]
        : [el("div", { className: "muted", text: "no errors or warnings" })])
    );
  }

  if (ui.selection.kind === "rule") {
    const table = findTable(state, ui.selection.tableId);
    const chain = findChain(state, ui.selection.tableId, ui.selection.chainId);
    const rule = findRule(state, ui.selection.tableId, ui.selection.chainId, ui.selection.ruleId);
    const feedback = document.getElementById(`rule-feedback-${ui.selection.ruleId}`);
    if (table && chain && rule && feedback) feedback.replaceWith(renderRuleFeedback(state, table, chain, rule));
  }
}

function render() {
  const state = store.getState();
  const active = document.activeElement;
  const focusAttr = active && app.contains(active) ? active.getAttribute("data-focus") : null;
  const selStart = active && "selectionStart" in active ? active.selectionStart : null;
  const selEnd = active && "selectionEnd" in active ? active.selectionEnd : null;
  const scrollPreview = document.getElementById("config-output")?.scrollTop || 0;
  const scrollEditor = document.querySelector(".editor")?.scrollTop || 0;
  const scrollSidebar = document.querySelector(".sidebar")?.scrollTop || 0;

  app.replaceChildren(
    renderTopbar(),
    el("div", { className: "layout" }, [renderSidebar(state), renderEditor(state), renderPreview(state)]),
    renderModal()
  );

  const preview = document.getElementById("config-output");
  if (preview) preview.scrollTop = scrollPreview;
  const editor = document.querySelector(".editor");
  if (editor) editor.scrollTop = scrollEditor;
  const sidebar = document.querySelector(".sidebar");
  if (sidebar) sidebar.scrollTop = scrollSidebar;

  if (focusAttr) {
    const next = app.querySelector(`[data-focus="${CSS.escape(focusAttr)}"]`);
    if (next) {
      next.focus();
      if (selStart !== null && selEnd !== null && typeof next.setSelectionRange === "function") {
        try {
          next.setSelectionRange(selStart, selEnd);
        } catch {
          /* ignore non-text controls */
        }
      }
    }
  }
}

store.subscribe((_state, meta = {}) => {
  if (meta.storageError) ui.copyStatus = meta.storageError;
  if (meta.quiet) refreshPreview();
  else render();
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && ui.confirm) {
    ui.confirm = null;
    render();
  }
});
render();
