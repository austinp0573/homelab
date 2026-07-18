import { getRuleSyntax } from "./generator.js";
import { cleanSingleLine, isAddress, isDuration, isMark, isNftIdentifier, isPortSpec } from "./util.js";

function add(issues, level, message, location = {}) {
  issues.push({ level, message, ...location });
}

function label(value, fallback) {
  return cleanSingleLine(value || fallback);
}

function checkComment(issues, value, location) {
  if (/[\r\n\u2028\u2029]/.test(String(value || ""))) add(issues, "warning", "newlines are converted to spaces in generated comments", location);
}

function chainIssue(table, chain) {
  if (!isNftIdentifier(chain.name)) return "chain name must be an nft identifier";
  if (!["raw", "mangle", "dstnat", "filter", "security", "srcnat", "-300", "-200", "-100", "0", "100", "200", "300"].includes(String(chain.priority))) {
    return "choose a supported priority";
  }
  if (!chain.hook) return "";

  const hooks = {
    inet: new Set(["prerouting", "input", "forward", "output", "postrouting"]),
    ip: new Set(["prerouting", "input", "forward", "output", "postrouting"]),
    ip6: new Set(["prerouting", "input", "forward", "output", "postrouting"]),
    bridge: new Set(["prerouting", "input", "forward", "output", "postrouting"]),
    netdev: new Set(["ingress", "egress"]),
  };

  if (!hooks[table.family]?.has(chain.hook)) return `${chain.hook} is not a valid ${table.family} hook`;
  if (table.family === "netdev" && chain.type !== "filter") return "netdev base chains must use the filter type";
  if (table.family === "netdev" && !String(chain.device || "").trim()) return "netdev base chains need a device";
  if (table.family === "bridge" && chain.type !== "filter") return "bridge base chains must use the filter type";
  if (chain.type === "nat" && !["inet", "ip", "ip6"].includes(table.family)) return "nat chains need an inet, ip, or ip6 table";
  if (chain.type === "nat" && !["prerouting", "input", "output", "postrouting"].includes(chain.hook)) return "nat chains need a NAT-capable hook";
  if (chain.type === "route" && !["inet", "ip", "ip6"].includes(table.family)) return "route chains need an inet, ip, or ip6 table";
  if (chain.type === "route" && chain.hook !== "output") return "route chains can only use the output hook";
  return "";
}

function mapIsValid(map) {
  if (!isNftIdentifier(map.name) || !["ipv4_addr", "ipv6_addr"].includes(map.keyType) || !["verdict", "mark"].includes(map.valueType)) {
    return false;
  }
  if (!map.entries?.length) return false;
  const keys = new Set();
  return map.entries.every((entry) => {
    if (!isAddress(entry.key, map.keyType === "ipv6_addr" ? "ipv6" : "ipv4")) return false;
    if (keys.has(entry.key)) return false;
    keys.add(entry.key);
    return map.valueType === "mark" ? isMark(entry.value) : ["accept", "drop", "return"].includes(entry.value);
  });
}

export function collectValidation(state) {
  const issues = [];
  const objectNames = new Map();

  for (const group of state.addressGroups || []) {
    const location = { groupId: group.id };
    const groupLabel = label(group.name, group.id);
    if (!isNftIdentifier(group.name)) add(issues, "error", `address group "${groupLabel}" needs a valid name`, location);
    if (!["ipv4", "ipv6"].includes(group.addrType)) add(issues, "error", `address group "${groupLabel}" has an invalid address type`, location);
    const elements = (group.elements || []).filter(Boolean);
    if (!elements.length) add(issues, "error", `address group "${groupLabel}" has no elements`, location);
    else if (elements.some((element) => !isAddress(element, group.addrType))) {
      add(issues, "error", `address group "${groupLabel}" has an invalid address or CIDR`, location);
    }
    if (group.timeout && !isDuration(group.timeout)) add(issues, "error", `address group "${groupLabel}" timeout needs a value such as 10m or 1h`, location);
    checkComment(issues, group.comment, location);
    if (isNftIdentifier(group.name)) {
      if (objectNames.has(group.name)) add(issues, "error", `object name "${group.name}" is used by more than one group`, location);
      else objectNames.set(group.name, group.id);
    }
  }

  for (const group of state.portGroups || []) {
    const location = { groupId: group.id };
    const groupLabel = label(group.name, group.id);
    if (!isNftIdentifier(group.name)) add(issues, "error", `port group "${groupLabel}" needs a valid name`, location);
    const elements = (group.elements || []).filter(Boolean);
    if (!elements.length) add(issues, "error", `port group "${groupLabel}" has no elements`, location);
    else if (elements.some((element) => !isPortSpec(element))) {
      add(issues, "error", `port group "${groupLabel}" has an invalid port or range`, location);
    }
    if (group.timeout && !isDuration(group.timeout)) add(issues, "error", `port group "${groupLabel}" timeout needs a value such as 10m or 1h`, location);
    checkComment(issues, group.comment, location);
    if (isNftIdentifier(group.name)) {
      if (objectNames.has(group.name)) add(issues, "error", `object name "${group.name}" is used by more than one group`, location);
      else objectNames.set(group.name, group.id);
    }
  }

  const tableKeys = new Set();
  for (const table of state.tables || []) {
    const location = { tableId: table.id };
    const tableLabel = label(table.name, table.id);
    if (!["inet", "ip", "ip6", "bridge", "netdev"].includes(table.family)) add(issues, "error", `table "${tableLabel}" has an unsupported family`, location);
    if (!isNftIdentifier(table.name)) add(issues, "error", `table "${tableLabel}" needs a valid name`, location);
    const key = `${table.family}:${table.name}`;
    if (tableKeys.has(key)) add(issues, "error", `duplicate table "${table.family} ${table.name}"`, location);
    else tableKeys.add(key);
    checkComment(issues, table.comment, location);

    const names = new Map();
    function claim(name, kind, loc) {
      if (!isNftIdentifier(name)) return;
      if (names.has(name)) add(issues, "error", `table "${tableLabel}" uses "${name}" as both ${names.get(name)} and ${kind}`, loc);
      else names.set(name, kind);
    }

    for (const map of table.maps || []) {
      const mapLocation = { ...location, mapId: map.id };
      if (!mapIsValid(map)) add(issues, "error", `map "${label(map.name, map.id)}" has an invalid name, type, or entry`, mapLocation);
      claim(map.name, "map", mapLocation);
      if ((table.family === "ip" && map.keyType === "ipv6_addr") || (table.family === "ip6" && map.keyType === "ipv4_addr")) {
        add(issues, "error", `map "${label(map.name, map.id)}" does not match the table family`, mapLocation);
      }
      checkComment(issues, map.comment, mapLocation);
    }

    for (const helper of table.helpers || []) {
      const helperLocation = { ...location, helperId: helper.id };
      const expectedProtocol = helper.type === "ftp" ? "tcp" : "udp";
      if (!isNftIdentifier(helper.name) || !["ftp", "tftp"].includes(helper.type) || helper.protocol !== expectedProtocol || !["ip", "ip6"].includes(helper.l3proto)) {
        add(issues, "error", `connection tracking helper "${label(helper.name, helper.id)}" has an invalid definition`, helperLocation);
      }
      claim(helper.name, "helper", helperLocation);
      if ((table.family === "ip" && helper.l3proto === "ip6") || (table.family === "ip6" && helper.l3proto === "ip")) {
        add(issues, "error", `connection tracking helper "${label(helper.name, helper.id)}" does not match the table family`, helperLocation);
      }
      checkComment(issues, helper.comment, helperLocation);
    }

    const chainNames = new Set();
    for (const chain of table.chains || []) {
      const chainLocation = { ...location, chainId: chain.id };
      const chainLabel = label(chain.name, chain.id);
      const error = chainIssue(table, chain);
      if (error) add(issues, "error", `chain "${chainLabel}": ${error}`, chainLocation);
      if (isNftIdentifier(chain.name)) {
        if (chainNames.has(chain.name)) add(issues, "error", `table "${tableLabel}" has duplicate chain "${chain.name}"`, chainLocation);
        else {
          chainNames.add(chain.name);
          claim(chain.name, "chain", chainLocation);
        }
      }
      checkComment(issues, chain.comment, chainLocation);

      for (const rule of chain.rules || []) {
        const ruleLocation = { ...chainLocation, ruleId: rule.id };
        const rendered = getRuleSyntax(state, table, chain, rule);
        for (const ruleIssue of rendered.issues) {
          add(issues, ruleIssue.level, `rule "${label(rule.comment, rule.id)}": ${ruleIssue.message}`, ruleLocation);
        }
      }
    }

    const addrById = new Map((state.addressGroups || []).map((group) => [group.id, group]));
    const portById = new Map((state.portGroups || []).map((group) => [group.id, group]));
    const claimedSets = new Set();
    for (const chain of table.chains || []) {
      for (const rule of chain.rules || []) {
        for (const [mode, groupId] of [
          [rule.saddrMode, rule.saddrGroupId],
          [rule.daddrMode, rule.daddrGroupId],
        ]) {
          if (mode !== "group" || claimedSets.has(groupId)) continue;
          const group = addrById.get(groupId);
          if (group && isNftIdentifier(group.name)) {
            claimedSets.add(groupId);
            claim(group.name, "set", { ...location, groupId: group.id });
          }
        }
        for (const [mode, groupId] of [
          [rule.sportMode, rule.sportGroupId],
          [rule.dportMode, rule.dportGroupId],
        ]) {
          if (mode !== "group" || claimedSets.has(groupId)) continue;
          const group = portById.get(groupId);
          if (group && isNftIdentifier(group.name)) {
            claimedSets.add(groupId);
            claim(group.name, "set", { ...location, groupId: group.id });
          }
        }
      }
    }
  }
  return issues;
}

export function ruleIssues(state, table, chain, rule) {
  return getRuleSyntax(state, table, chain, rule).issues;
}
