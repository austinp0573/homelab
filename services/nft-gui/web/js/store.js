import { deepClone, uid } from "./util.js";

const STORAGE_KEY = "nft-gui.ruleset.v2";
const MAX_ITEMS = 200;
const MAX_TEXT = 500;

function text(value, max = MAX_TEXT) {
  return typeof value === "string" ? value.slice(0, max) : "";
}

function list(value, mapper, max = MAX_ITEMS) {
  return Array.isArray(value) ? value.slice(0, max).map(mapper) : [];
}

function id(value, prefix) {
  return typeof value === "string" && value.length > 0 && value.length <= 120 ? value : uid(prefix);
}

export function emptyRuleset() {
  return {
    version: 2,
    flushRuleset: true,
    addressGroups: [],
    portGroups: [],
    tables: [],
  };
}

export function emptyAddressGroup() {
  return {
    id: uid("addr"),
    name: "",
    addrType: "ipv4",
    comment: "",
    timeout: "",
    elements: [],
  };
}

export function emptyPortGroup() {
  return {
    id: uid("port"),
    name: "",
    comment: "",
    timeout: "",
    elements: [],
  };
}

export function emptyMapEntry() {
  return {
    id: uid("map_entry"),
    key: "",
    value: "accept",
  };
}

export function emptyMap() {
  return {
    id: uid("map"),
    name: "policy_map",
    keyType: "ipv4_addr",
    valueType: "verdict",
    comment: "",
    entries: [],
  };
}

export function emptyHelper() {
  return {
    id: uid("helper"),
    name: "ftp_helper",
    type: "ftp",
    protocol: "tcp",
    l3proto: "ip",
    comment: "",
  };
}

export function emptyTable() {
  return {
    id: uid("table"),
    name: "filter",
    family: "inet",
    comment: "",
    maps: [],
    helpers: [],
    chains: [],
  };
}

export function emptyChain() {
  return {
    id: uid("chain"),
    name: "input",
    type: "filter",
    hook: "input",
    priority: "filter",
    policy: "drop",
    device: "",
    comment: "",
    rules: [],
  };
}

export function emptyRule() {
  return {
    id: uid("rule"),
    enabled: true,
    comment: "",
    iifname: "",
    oifname: "",
    l4proto: "",
    saddrMode: "none",
    saddrValue: "",
    saddrGroupId: "",
    daddrMode: "none",
    daddrValue: "",
    daddrGroupId: "",
    sportMode: "none",
    sportValue: "",
    sportGroupId: "",
    dportMode: "none",
    dportValue: "",
    dportGroupId: "",
    ctState: [],
    ctStatus: [],
    ctDirection: "",
    ctMark: "",
    ctHelperId: "",
    tcpFlags: "",
    icmpType: "",
    icmpv6Type: "",
    metaMark: "",
    mapId: "",
    mapSelector: "saddr",
    counter: false,
    limitMode: "none",
    limitRate: "",
    limitUnit: "second",
    limitBytesUnit: "kbytes",
    limitBurst: "",
    logPrefix: "",
    logFlags: "",
    logLevel: "",
    verdict: "accept",
    rejectType: "port-unreachable",
    jumpChain: "",
    natAddr: "",
    natPort: "",
  };
}

function normalizeAddressGroup(value) {
  const base = emptyAddressGroup();
  return {
    ...base,
    id: id(value?.id, "addr"),
    name: text(value?.name, 80),
    addrType: value?.addrType === "ipv6" ? "ipv6" : "ipv4",
    comment: text(value?.comment),
    timeout: text(value?.timeout, 20),
    elements: list(value?.elements, (item) => text(item, 120)),
  };
}

function normalizePortGroup(value) {
  const base = emptyPortGroup();
  return {
    ...base,
    id: id(value?.id, "port"),
    name: text(value?.name, 80),
    comment: text(value?.comment),
    timeout: text(value?.timeout, 20),
    elements: list(value?.elements, (item) => text(item, 80)),
  };
}

function normalizeMapEntry(value) {
  const base = emptyMapEntry();
  return {
    ...base,
    id: id(value?.id, "map_entry"),
    key: text(value?.key, 120),
    value: text(value?.value, 80),
  };
}

function normalizeMap(value) {
  const base = emptyMap();
  return {
    ...base,
    id: id(value?.id, "map"),
    name: text(value?.name, 80),
    keyType: value?.keyType === "ipv6_addr" ? "ipv6_addr" : "ipv4_addr",
    valueType: value?.valueType === "mark" ? "mark" : "verdict",
    comment: text(value?.comment),
    entries: list(value?.entries, normalizeMapEntry),
  };
}

function normalizeHelper(value) {
  const base = emptyHelper();
  const allowedTypes = new Set(["ftp", "tftp"]);
  return {
    ...base,
    id: id(value?.id, "helper"),
    name: text(value?.name, 80),
    type: allowedTypes.has(value?.type) ? value.type : "ftp",
    protocol: value?.protocol === "udp" ? "udp" : "tcp",
    l3proto: value?.l3proto === "ip6" ? "ip6" : "ip",
    comment: text(value?.comment),
  };
}

function normalizeRule(value) {
  const base = emptyRule();
  const modes = new Set(["none", "value", "group"]);
  const verdicts = new Set(["accept", "drop", "reject", "return", "jump", "goto", "masquerade", "snat", "dnat", "redirect"]);
  const limitModes = new Set(["none", "packets", "bytes"]);
  const limitUnits = new Set(["second", "minute", "hour", "day"]);
  const bytesUnits = new Set(["bytes", "kbytes", "mbytes"]);

  return {
    ...base,
    id: id(value?.id, "rule"),
    enabled: value?.enabled !== false,
    comment: text(value?.comment),
    iifname: text(value?.iifname, 120),
    oifname: text(value?.oifname, 120),
    l4proto: text(value?.l4proto, 30),
    saddrMode: modes.has(value?.saddrMode) ? value.saddrMode : "none",
    saddrValue: text(value?.saddrValue, 250),
    saddrGroupId: text(value?.saddrGroupId, 120),
    daddrMode: modes.has(value?.daddrMode) ? value.daddrMode : "none",
    daddrValue: text(value?.daddrValue, 250),
    daddrGroupId: text(value?.daddrGroupId, 120),
    sportMode: modes.has(value?.sportMode) ? value.sportMode : "none",
    sportValue: text(value?.sportValue, 150),
    sportGroupId: text(value?.sportGroupId, 120),
    dportMode: modes.has(value?.dportMode) ? value.dportMode : "none",
    dportValue: text(value?.dportValue, 150),
    dportGroupId: text(value?.dportGroupId, 120),
    ctState: list(value?.ctState, (item) => text(item, 30), 10),
    ctStatus: list(value?.ctStatus, (item) => text(item, 30), 10),
    ctDirection: value?.ctDirection === "original" || value?.ctDirection === "reply" ? value.ctDirection : "",
    ctMark: text(value?.ctMark, 30),
    ctHelperId: text(value?.ctHelperId, 120),
    tcpFlags: text(value?.tcpFlags, 80),
    icmpType: text(value?.icmpType, 80),
    icmpv6Type: text(value?.icmpv6Type, 80),
    metaMark: text(value?.metaMark, 30),
    mapId: text(value?.mapId, 120),
    mapSelector: value?.mapSelector === "daddr" ? "daddr" : "saddr",
    counter: value?.counter === true,
    limitMode: limitModes.has(value?.limitMode) ? value.limitMode : "none",
    limitRate: text(value?.limitRate, 20),
    limitUnit: limitUnits.has(value?.limitUnit) ? value.limitUnit : "second",
    limitBytesUnit: bytesUnits.has(value?.limitBytesUnit) ? value.limitBytesUnit : "kbytes",
    limitBurst: text(value?.limitBurst, 20),
    logPrefix: text(value?.logPrefix, 160),
    logFlags: ["", "all", "tcp sequence", "skuid", "ether", "ip options"].includes(value?.logFlags) ? value.logFlags : "",
    logLevel: ["", "emerg", "alert", "crit", "err", "warn", "notice", "info", "debug"].includes(value?.logLevel) ? value.logLevel : "",
    verdict: verdicts.has(value?.verdict) ? value.verdict : "accept",
    rejectType: text(value?.rejectType, 60),
    jumpChain: text(value?.jumpChain, 80),
    natAddr: text(value?.natAddr, 120),
    natPort: text(value?.natPort, 30),
  };
}

function normalizeChain(value) {
  const base = emptyChain();
  const priorities = new Set(["raw", "mangle", "dstnat", "filter", "security", "srcnat", "-300", "-200", "-100", "0", "100", "200", "300"]);
  return {
    ...base,
    id: id(value?.id, "chain"),
    name: text(value?.name, 80),
    type: ["filter", "nat", "route"].includes(value?.type) ? value.type : "filter",
    hook: text(value?.hook, 30),
    priority: priorities.has(String(value?.priority)) ? String(value.priority) : "filter",
    policy: value?.policy === "drop" ? "drop" : "accept",
    device: text(value?.device, 80),
    comment: text(value?.comment),
    rules: list(value?.rules, normalizeRule),
  };
}

function normalizeTable(value) {
  const base = emptyTable();
  return {
    ...base,
    id: id(value?.id, "table"),
    name: text(value?.name, 80),
    family: ["inet", "ip", "ip6", "bridge", "netdev"].includes(value?.family) ? value.family : "inet",
    comment: text(value?.comment),
    maps: list(value?.maps, normalizeMap),
    helpers: list(value?.helpers, normalizeHelper),
    chains: list(value?.chains, normalizeChain),
  };
}

export function normalizeRuleset(parsed) {
  if (!parsed || typeof parsed !== "object") return emptyRuleset();
  return {
    version: 2,
    flushRuleset: parsed.flushRuleset !== false,
    addressGroups: list(parsed.addressGroups, normalizeAddressGroup),
    portGroups: list(parsed.portGroups, normalizePortGroup),
    tables: list(parsed.tables, normalizeTable, 80),
  };
}

function loadRaw() {
  try {
    const rawV2 = localStorage.getItem(STORAGE_KEY);
    const rawV1 = localStorage.getItem("nft-gui.ruleset.v1");
    const raw = rawV2 || rawV1;
    if (!raw) return emptyRuleset();
    const normalized = normalizeRuleset(JSON.parse(raw));
    if (!rawV2 && rawV1) {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(normalized));
      localStorage.removeItem("nft-gui.ruleset.v1");
    }
    return normalized;
  } catch {
    return emptyRuleset();
  }
}

function clearReferences(tables, key, groupId) {
  return tables.map((table) => ({
    ...table,
    chains: table.chains.map((chain) => ({
      ...chain,
      rules: chain.rules.map((rule) => {
        if (rule[key] !== groupId) return rule;
        const modeKey = key.startsWith("saddr") ? "saddrMode" : key.startsWith("daddr") ? "daddrMode" : key.startsWith("sport") ? "sportMode" : "dportMode";
        return { ...rule, [key]: "", [modeKey]: "none" };
      }),
    })),
  }));
}

export function createStore(onChange) {
  let state = loadRaw();
  let saveTimer = null;
  const listeners = new Set();
  if (typeof onChange === "function") listeners.add(onChange);

  function save() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
      return "";
    } catch {
      return "browser storage is unavailable or full";
    }
  }

  function emit(opts = {}) {
    let storageError = "";
    if (opts.quiet) {
      clearTimeout(saveTimer);
      saveTimer = setTimeout(() => {
        const err = save();
        if (err) {
          for (const fn of listeners) fn(getState(), { quiet: true, storageError: err });
        }
      }, 250);
    } else {
      clearTimeout(saveTimer);
      storageError = save();
    }
    for (const fn of listeners) fn(getState(), { quiet: !!opts.quiet, storageError });
  }

  function getState() {
    return deepClone(state);
  }

  function setState(next, opts) {
    state = normalizeRuleset(next);
    emit(opts);
  }

  function replaceRuleset(ruleset, opts) {
    setState(deepClone(ruleset), opts);
  }

  function clearAll(opts) {
    setState(emptyRuleset(), opts);
  }

  function subscribe(fn) {
    listeners.add(fn);
    return () => listeners.delete(fn);
  }

  function updateAddressGroup(groupId, patch, opts) {
    state.addressGroups = state.addressGroups.map((group) => (group.id === groupId ? normalizeAddressGroup({ ...group, ...patch }) : group));
    emit(opts);
  }

  function addAddressGroup(group = emptyAddressGroup(), opts) {
    const next = normalizeAddressGroup(group);
    state.addressGroups = [...state.addressGroups, next];
    emit(opts);
    return next.id;
  }

  function removeAddressGroup(groupId, opts) {
    state.addressGroups = state.addressGroups.filter((group) => group.id !== groupId);
    state.tables = clearReferences(clearReferences(state.tables, "saddrGroupId", groupId), "daddrGroupId", groupId);
    emit(opts);
  }

  function updatePortGroup(groupId, patch, opts) {
    state.portGroups = state.portGroups.map((group) => (group.id === groupId ? normalizePortGroup({ ...group, ...patch }) : group));
    emit(opts);
  }

  function addPortGroup(group = emptyPortGroup(), opts) {
    const next = normalizePortGroup(group);
    state.portGroups = [...state.portGroups, next];
    emit(opts);
    return next.id;
  }

  function removePortGroup(groupId, opts) {
    state.portGroups = state.portGroups.filter((group) => group.id !== groupId);
    state.tables = clearReferences(clearReferences(state.tables, "sportGroupId", groupId), "dportGroupId", groupId);
    emit(opts);
  }

  function setFlushRuleset(value, opts) {
    state.flushRuleset = !!value;
    emit(opts);
  }

  function addTable(table = emptyTable(), opts) {
    const next = normalizeTable(table);
    state.tables = [...state.tables, next];
    emit(opts);
    return next.id;
  }

  function updateTable(tableId, patch, opts) {
    state.tables = state.tables.map((table) => (table.id === tableId ? normalizeTable({ ...table, ...patch }) : table));
    emit(opts);
  }

  function removeTable(tableId, opts) {
    state.tables = state.tables.filter((table) => table.id !== tableId);
    emit(opts);
  }

  function updateNestedTableObject(tableId, key, objectId, patch, opts) {
    state.tables = state.tables.map((table) => {
      if (table.id !== tableId) return table;
      const normalizer = key === "maps" ? normalizeMap : normalizeHelper;
      return { ...table, [key]: table[key].map((item) => (item.id === objectId ? normalizer({ ...item, ...patch }) : item)) };
    });
    emit(opts);
  }

  function addMap(tableId, map = emptyMap(), opts) {
    const next = normalizeMap(map);
    state.tables = state.tables.map((table) => (table.id === tableId ? { ...table, maps: [...table.maps, next] } : table));
    emit(opts);
    return next.id;
  }

  function updateMap(tableId, mapId, patch, opts) {
    updateNestedTableObject(tableId, "maps", mapId, patch, opts);
  }

  function removeMap(tableId, mapId, opts) {
    state.tables = state.tables.map((table) => {
      if (table.id !== tableId) return table;
      return {
        ...table,
        maps: table.maps.filter((map) => map.id !== mapId),
        chains: table.chains.map((chain) => ({
          ...chain,
          rules: chain.rules.map((rule) => (rule.mapId === mapId ? { ...rule, mapId: "" } : rule)),
        })),
      };
    });
    emit(opts);
  }

  function addMapEntry(tableId, mapId, entry = emptyMapEntry(), opts) {
    const next = normalizeMapEntry(entry);
    state.tables = state.tables.map((table) => {
      if (table.id !== tableId) return table;
      return { ...table, maps: table.maps.map((map) => (map.id === mapId ? { ...map, entries: [...map.entries, next] } : map)) };
    });
    emit(opts);
    return next.id;
  }

  function updateMapEntry(tableId, mapId, entryId, patch, opts) {
    state.tables = state.tables.map((table) => {
      if (table.id !== tableId) return table;
      return {
        ...table,
        maps: table.maps.map((map) =>
          map.id === mapId ? { ...map, entries: map.entries.map((entry) => (entry.id === entryId ? normalizeMapEntry({ ...entry, ...patch }) : entry)) } : map
        ),
      };
    });
    emit(opts);
  }

  function removeMapEntry(tableId, mapId, entryId, opts) {
    state.tables = state.tables.map((table) => {
      if (table.id !== tableId) return table;
      return {
        ...table,
        maps: table.maps.map((map) => (map.id === mapId ? { ...map, entries: map.entries.filter((entry) => entry.id !== entryId) } : map)),
      };
    });
    emit(opts);
  }

  function addHelper(tableId, helper = emptyHelper(), opts) {
    const next = normalizeHelper(helper);
    state.tables = state.tables.map((table) => (table.id === tableId ? { ...table, helpers: [...table.helpers, next] } : table));
    emit(opts);
    return next.id;
  }

  function updateHelper(tableId, helperId, patch, opts) {
    updateNestedTableObject(tableId, "helpers", helperId, patch, opts);
  }

  function removeHelper(tableId, helperId, opts) {
    state.tables = state.tables.map((table) => {
      if (table.id !== tableId) return table;
      return {
        ...table,
        helpers: table.helpers.filter((helper) => helper.id !== helperId),
        chains: table.chains.map((chain) => ({
          ...chain,
          rules: chain.rules.map((rule) => (rule.ctHelperId === helperId ? { ...rule, ctHelperId: "" } : rule)),
        })),
      };
    });
    emit(opts);
  }

  function addChain(tableId, chain = emptyChain(), opts) {
    const next = normalizeChain(chain);
    state.tables = state.tables.map((table) => (table.id === tableId ? { ...table, chains: [...table.chains, next] } : table));
    emit(opts);
    return next.id;
  }

  function updateChain(tableId, chainId, patch, opts) {
    state.tables = state.tables.map((table) => {
      if (table.id !== tableId) return table;
      return { ...table, chains: table.chains.map((chain) => (chain.id === chainId ? normalizeChain({ ...chain, ...patch }) : chain)) };
    });
    emit(opts);
  }

  function removeChain(tableId, chainId, opts) {
    state.tables = state.tables.map((table) => {
      if (table.id !== tableId) return table;
      return { ...table, chains: table.chains.filter((chain) => chain.id !== chainId) };
    });
    emit(opts);
  }

  function addRule(tableId, chainId, rule = emptyRule(), opts) {
    const next = normalizeRule(rule);
    state.tables = state.tables.map((table) => {
      if (table.id !== tableId) return table;
      return {
        ...table,
        chains: table.chains.map((chain) => (chain.id === chainId ? { ...chain, rules: [...chain.rules, next] } : chain)),
      };
    });
    emit(opts);
    return next.id;
  }

  function updateRule(tableId, chainId, ruleId, patch, opts) {
    state.tables = state.tables.map((table) => {
      if (table.id !== tableId) return table;
      return {
        ...table,
        chains: table.chains.map((chain) =>
          chain.id === chainId ? { ...chain, rules: chain.rules.map((rule) => (rule.id === ruleId ? normalizeRule({ ...rule, ...patch }) : rule)) } : chain
        ),
      };
    });
    emit(opts);
  }

  function removeRule(tableId, chainId, ruleId, opts) {
    state.tables = state.tables.map((table) => {
      if (table.id !== tableId) return table;
      return {
        ...table,
        chains: table.chains.map((chain) => (chain.id === chainId ? { ...chain, rules: chain.rules.filter((rule) => rule.id !== ruleId) } : chain)),
      };
    });
    emit(opts);
  }

  function duplicateRule(tableId, chainId, ruleId, opts) {
    const source = state.tables
      .find((table) => table.id === tableId)
      ?.chains.find((chain) => chain.id === chainId)
      ?.rules.find((rule) => rule.id === ruleId);
    if (!source) return "";
    const next = normalizeRule({ ...deepClone(source), id: uid("rule"), comment: source.comment ? `${source.comment} copy` : "copy" });
    state.tables = state.tables.map((table) => {
      if (table.id !== tableId) return table;
      return {
        ...table,
        chains: table.chains.map((chain) => {
          if (chain.id !== chainId) return chain;
          const index = chain.rules.findIndex((rule) => rule.id === ruleId);
          return { ...chain, rules: [...chain.rules.slice(0, index + 1), next, ...chain.rules.slice(index + 1)] };
        }),
      };
    });
    emit(opts);
    return next.id;
  }

  function moveRule(tableId, chainId, ruleId, direction, opts) {
    state.tables = state.tables.map((table) => {
      if (table.id !== tableId) return table;
      return {
        ...table,
        chains: table.chains.map((chain) => {
          if (chain.id !== chainId) return chain;
          const rules = [...chain.rules];
          const index = rules.findIndex((rule) => rule.id === ruleId);
          const target = direction === "up" ? index - 1 : index + 1;
          if (index < 0 || target < 0 || target >= rules.length) return chain;
          [rules[index], rules[target]] = [rules[target], rules[index]];
          return { ...chain, rules };
        }),
      };
    });
    emit(opts);
  }

  if (typeof window !== "undefined") {
    window.addEventListener("pagehide", () => {
      clearTimeout(saveTimer);
      save();
    });
  }

  return {
    getState,
    setState,
    replaceRuleset,
    clearAll,
    subscribe,
    setFlushRuleset,
    addAddressGroup,
    updateAddressGroup,
    removeAddressGroup,
    addPortGroup,
    updatePortGroup,
    removePortGroup,
    addTable,
    updateTable,
    removeTable,
    addMap,
    updateMap,
    removeMap,
    addMapEntry,
    updateMapEntry,
    removeMapEntry,
    addHelper,
    updateHelper,
    removeHelper,
    addChain,
    updateChain,
    removeChain,
    addRule,
    updateRule,
    removeRule,
    duplicateRule,
    moveRule,
  };
}
