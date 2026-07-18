import {
  addressTypeForValue,
  cleanSingleLine,
  isAddress,
  isDuration,
  isMark,
  isNftIdentifier,
  isPortSpec,
} from "./util.js";

const PROTOCOLS = new Set(["", "tcp", "udp", "icmp", "icmpv6", "gre", "esp", "ah", "sctp"]);
const CT_STATES = new Set(["new", "established", "related", "invalid", "untracked"]);
const CT_STATUS = new Set(["expected", "seen-reply", "assured", "confirmed", "snat", "dnat"]);
const TCP_FLAG_MATCHES = new Set(["", "syn", "syn,ack", "fin,syn,rst,ack"]);
const LOG_FLAGS = new Set(["", "all", "tcp sequence", "skuid", "ether", "ip options"]);
const LOG_LEVELS = new Set(["", "emerg", "alert", "crit", "err", "warn", "notice", "info", "debug"]);
const REJECT_TYPES_IP = new Set(["port-unreachable", "admin-prohibited", "no-route", "host-unreachable", "prot-unreachable"]);
const REJECT_TYPES_IP6 = new Set(["port-unreachable", "admin-prohibited", "no-route"]);
const NAT_HOOKS = {
  masquerade: new Set(["postrouting"]),
  snat: new Set(["postrouting", "input"]),
  dnat: new Set(["prerouting", "output"]),
  redirect: new Set(["prerouting", "output"]),
};
const VERDICTS = new Set(["accept", "drop", "reject", "return", "jump", "goto", "masquerade", "snat", "dnat", "redirect"]);
const PRIORITIES = new Set(["raw", "mangle", "dstnat", "filter", "security", "srcnat", "-300", "-200", "-100", "0", "100", "200", "300"]);

function issue(message, level = "error") {
  return { level, message };
}

function cleanComment(value) {
  return cleanSingleLine(value);
}

function quoteString(value) {
  return `"${cleanSingleLine(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
}

function splitList(value) {
  return String(value || "")
    .split(/[\s,]+/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function quoteInterface(value) {
  const name = String(value || "").trim();
  if (!name) return "";
  if (/^[a-zA-Z0-9_./@-]+$/.test(name)) return name;
  return quoteString(name);
}

function listMatch(kind, value) {
  const values = splitList(value);
  if (!values.length) return "";
  const quoted = values.map(quoteInterface);
  return quoted.length === 1 ? `${kind} ${quoted[0]}` : `${kind} { ${quoted.join(", ")} }`;
}

function groupMap(items) {
  return new Map((items || []).map((item) => [item.id, item]));
}

function familyForAddress(value, group) {
  if (group?.addrType === "ipv6") return "ip6";
  if (group?.addrType === "ipv4") return "ip";
  return addressTypeForValue(value) === "ipv6" ? "ip6" : "ip";
}

function formatList(values) {
  return values.length === 1 ? values[0] : `{ ${values.join(", ")} }`;
}

function validAddressGroup(group) {
  const elements = (group?.elements || []).filter(Boolean);
  return group && isNftIdentifier(group.name) && elements.length > 0 && (!group.timeout || isDuration(group.timeout)) &&
    elements.every((element) => isAddress(element, group.addrType));
}

function validPortGroup(group) {
  const elements = (group?.elements || []).filter(Boolean);
  return group && isNftIdentifier(group.name) && elements.length > 0 && (!group.timeout || isDuration(group.timeout)) &&
    elements.every((element) => isPortSpec(element));
}

function validMap(map) {
  if (!map || !isNftIdentifier(map.name) || !["ipv4_addr", "ipv6_addr"].includes(map.keyType) || !["verdict", "mark"].includes(map.valueType)) {
    return false;
  }
  const keys = new Set();
  return (map.entries || []).length > 0 && map.entries.every((entry) => {
    if (!isAddress(entry.key, map.keyType === "ipv6_addr" ? "ipv6" : "ipv4")) return false;
    if (keys.has(entry.key)) return false;
    keys.add(entry.key);
    return map.valueType === "mark" ? isMark(entry.value) : ["accept", "drop", "return"].includes(entry.value);
  });
}

function validHelper(helper) {
  const protocol = helper?.type === "ftp" ? "tcp" : helper?.type === "tftp" ? "udp" : "";
  return helper && isNftIdentifier(helper.name) && protocol === helper.protocol && ["ip", "ip6"].includes(helper.l3proto);
}

function addressMatch(side, mode, value, groupId, groups, tableFamily, errors) {
  if (mode === "none" || !mode) return "";
  if (mode === "group") {
    const group = groups.get(groupId);
    if (!validAddressGroup(group)) {
      errors.push(issue(`${side} address group is missing or invalid`));
      return "";
    }
    if ((tableFamily === "ip" && group.addrType === "ipv6") || (tableFamily === "ip6" && group.addrType === "ipv4")) {
      errors.push(issue(`${side} address group does not match the table family`));
      return "";
    }
    return `${familyForAddress("", group)} ${side} @${group.name}`;
  }

  const values = splitList(value);
  if (!values.length || values.some((item) => !isAddress(item))) {
    errors.push(issue(`${side} address is not a valid IP address or CIDR`));
    return "";
  }
  const types = new Set(values.map(addressTypeForValue));
  if (types.size !== 1) {
    errors.push(issue(`${side} address values cannot mix IPv4 and IPv6`));
    return "";
  }
  const type = [...types][0];
  if ((tableFamily === "ip" && type === "ipv6") || (tableFamily === "ip6" && type === "ipv4")) {
    errors.push(issue(`${side} address does not match the table family`));
    return "";
  }
  const prefix = type === "ipv6" ? "ip6" : "ip";
  return `${prefix} ${side} ${formatList(values)}`;
}

function portMatch(side, mode, value, groupId, groups, protocol, errors) {
  if (mode === "none" || !mode) return "";
  const portProtocol = ["tcp", "udp", "sctp"].includes(protocol) ? protocol : "th";
  if (mode === "group") {
    const group = groups.get(groupId);
    if (!validPortGroup(group)) {
      errors.push(issue(`${side} port group is missing or invalid`));
      return "";
    }
    return `${portProtocol} ${side} @${group.name}`;
  }

  const values = splitList(value);
  if (!values.length || values.some((item) => !isPortSpec(item))) {
    errors.push(issue(`${side} port is not a valid port or range`));
    return "";
  }
  return `${portProtocol} ${side} ${formatList(values)}`;
}

function usedSetNames(state, table) {
  const names = new Set();
  const addr = groupMap(state.addressGroups);
  const ports = groupMap(state.portGroups);
  for (const chain of table.chains || []) {
    for (const rule of chain.rules || []) {
      if (rule.saddrMode === "group" && addr.get(rule.saddrGroupId)?.name) names.add(addr.get(rule.saddrGroupId).name);
      if (rule.daddrMode === "group" && addr.get(rule.daddrGroupId)?.name) names.add(addr.get(rule.daddrGroupId).name);
      if (rule.sportMode === "group" && ports.get(rule.sportGroupId)?.name) names.add(ports.get(rule.sportGroupId).name);
      if (rule.dportMode === "group" && ports.get(rule.dportGroupId)?.name) names.add(ports.get(rule.dportGroupId).name);
    }
  }
  return names;
}

function buildVerdict(rule, table, chain, chainNames, errors) {
  const verdict = rule.verdict || "accept";
  if (!VERDICTS.has(verdict)) {
    errors.push(issue("choose a supported verdict"));
    return "";
  }
  if (verdict === "accept" || verdict === "drop" || verdict === "return") return verdict;

  if (verdict === "reject") {
    if (!["inet", "ip", "ip6"].includes(table.family)) {
      errors.push(issue("reject is only supported in inet, ip, and ip6 tables"));
      return "";
    }
    const allowed = table.family === "ip" ? REJECT_TYPES_IP : REJECT_TYPES_IP6;
    if (!allowed.has(rule.rejectType || "port-unreachable")) {
      errors.push(issue("choose a supported reject type for this table family"));
      return "";
    }
    const protocol = table.family === "ip" ? "icmp" : table.family === "ip6" ? "icmpv6" : "icmpx";
    return `reject with ${protocol} type ${rule.rejectType || "port-unreachable"}`;
  }

  if (verdict === "jump" || verdict === "goto") {
    if (!isNftIdentifier(rule.jumpChain) || !chainNames.has(rule.jumpChain)) {
      errors.push(issue(`${verdict} needs a chain in this table`));
      return "";
    }
    if (rule.jumpChain === chain.name) {
      errors.push(issue(`${verdict} cannot target the same chain`));
      return "";
    }
    return `${verdict} ${rule.jumpChain}`;
  }

  if (!["ip", "ip6", "inet"].includes(table.family) || chain.type !== "nat") {
    errors.push(issue(`${verdict} needs an ip, ip6, or inet nat chain`));
    return "";
  }
  if (!NAT_HOOKS[verdict]?.has(chain.hook)) {
    errors.push(issue(`${verdict} needs a ${[...NAT_HOOKS[verdict]].join(" or ")} hook`));
    return "";
  }
  if (verdict === "masquerade") {
    if (rule.natPort) {
      if (!isPortSpec(rule.natPort)) {
        errors.push(issue("masquerade port is not a valid port or range"));
        return "";
      }
      return `masquerade to :${rule.natPort}`;
    }
    return "masquerade";
  }
  if (verdict === "redirect") {
    if (!isPortSpec(rule.natPort)) {
      errors.push(issue("redirect needs a valid destination port"));
      return "";
    }
    return `redirect to :${rule.natPort}`;
  }
  if (!isAddress(rule.natAddr)) {
    errors.push(issue(`${verdict} needs a valid address`));
    return "";
  }
  const addressType = addressTypeForValue(rule.natAddr);
  if ((table.family === "ip" && addressType === "ipv6") || (table.family === "ip6" && addressType === "ipv4")) {
    errors.push(issue(`${verdict} address does not match the table family`));
    return "";
  }
  if (rule.natPort && !isPortSpec(rule.natPort)) {
    errors.push(issue("NAT port is not a valid port or range"));
    return "";
  }
  if (rule.natPort && addressType === "ipv6") {
    return `${verdict} to [${rule.natAddr}]:${rule.natPort}`;
  }
  return rule.natPort ? `${verdict} to ${rule.natAddr}:${rule.natPort}` : `${verdict} to ${rule.natAddr}`;
}

function mapAction(rule, table, maps, setNames, errors) {
  if (!rule.mapId) return { expression: "", controlsVerdict: false };
  const map = maps.get(rule.mapId);
  if (!validMap(map)) {
    errors.push(issue("selected map is missing or invalid"));
    return { expression: "", controlsVerdict: false };
  }
  if (setNames.has(map.name) || (table.helpers || []).some((helper) => helper.name === map.name) || (table.chains || []).some((item) => item.name === map.name)) {
    errors.push(issue(`map name "${map.name}" conflicts with another object in this table`));
    return { expression: "", controlsVerdict: false };
  }
  const mapFamily = map.keyType === "ipv6_addr" ? "ip6" : "ip";
  if ((table.family === "ip" && mapFamily === "ip6") || (table.family === "ip6" && mapFamily === "ip")) {
    errors.push(issue("selected map does not match the table family"));
    return { expression: "", controlsVerdict: false };
  }
  const side = rule.mapSelector === "daddr" ? "daddr" : "saddr";
  const source = `${mapFamily} ${side}`;
  if (map.valueType === "verdict") return { expression: `${source} vmap @${map.name}`, controlsVerdict: true };
  return { expression: `meta mark set ${source} map @${map.name}`, controlsVerdict: false };
}

export function getRuleSyntax(state, table, chain, rule) {
  if (rule.enabled === false) {
    return { line: `# disabled: ${cleanComment(rule.comment || rule.id)}`, issues: [] };
  }

  const errors = [];
  const warnings = [];
  const parts = [];
  const addressGroups = groupMap(state.addressGroups);
  const portGroups = groupMap(state.portGroups);
  const maps = groupMap(table.maps);
  const helpers = groupMap(table.helpers);
  const setNames = usedSetNames(state, table);
  const protocol = String(rule.l4proto || "").toLowerCase();

  if (!PROTOCOLS.has(protocol)) errors.push(issue("choose a supported protocol"));
  if (/[\r\n\u2028\u2029]/.test(String(rule.comment || ""))) warnings.push(issue("comment newlines are converted to spaces", "warning"));
  if (/[\r\n\u2028\u2029]/.test(String(rule.logPrefix || ""))) warnings.push(issue("log prefix newlines are converted to spaces", "warning"));

  if (rule.iifname) parts.push(listMatch("iifname", rule.iifname));
  if (rule.oifname) parts.push(listMatch("oifname", rule.oifname));

  const hasPorts = (rule.sportMode && rule.sportMode !== "none") || (rule.dportMode && rule.dportMode !== "none");
  if (hasPorts && protocol && !["tcp", "udp", "sctp"].includes(protocol)) {
    errors.push(issue("port matches need TCP, UDP, SCTP, or no selected protocol"));
  }
  if (protocol === "icmp" && table.family === "ip6") errors.push(issue("ICMP is not valid in an ip6 table"));
  if (protocol === "icmpv6" && table.family === "ip") errors.push(issue("ICMPv6 is not valid in an ip table"));
  if (protocol === "icmp") parts.push("ip protocol icmp");
  else if (protocol === "icmpv6") parts.push("ip6 nexthdr icmpv6");
  else if (protocol && !["tcp", "udp"].includes(protocol)) parts.push(`meta l4proto ${protocol}`);
  else if (protocol && !hasPorts) parts.push(`meta l4proto ${protocol}`);

  const saddr = addressMatch("saddr", rule.saddrMode, rule.saddrValue, rule.saddrGroupId, addressGroups, table.family, errors);
  const daddr = addressMatch("daddr", rule.daddrMode, rule.daddrValue, rule.daddrGroupId, addressGroups, table.family, errors);
  const sport = portMatch("sport", rule.sportMode, rule.sportValue, rule.sportGroupId, portGroups, protocol, errors);
  const dport = portMatch("dport", rule.dportMode, rule.dportValue, rule.dportGroupId, portGroups, protocol, errors);
  if (saddr) parts.push(saddr);
  if (daddr) parts.push(daddr);
  if (sport) parts.push(sport);
  if (dport) parts.push(dport);

  const states = (rule.ctState || []).filter((stateName) => CT_STATES.has(stateName));
  if (states.length !== (rule.ctState || []).length) errors.push(issue("ct state has an unsupported value"));
  if (states.length) parts.push(`ct state ${formatList(states)}`);

  const statuses = (rule.ctStatus || []).filter((status) => CT_STATUS.has(status));
  if (statuses.length !== (rule.ctStatus || []).length) errors.push(issue("ct status has an unsupported value"));
  if (statuses.length) parts.push(`ct status ${formatList(statuses)}`);

  if (rule.ctDirection) {
    if (!["original", "reply"].includes(rule.ctDirection)) errors.push(issue("ct direction must be original or reply"));
    else parts.push(`ct direction ${rule.ctDirection}`);
  }
  if (rule.ctMark) {
    if (!isMark(rule.ctMark)) errors.push(issue("ct mark must be decimal or hexadecimal"));
    else parts.push(`ct mark ${rule.ctMark}`);
  }
  if (rule.ctHelperId) {
    const helper = helpers.get(rule.ctHelperId);
    if (!validHelper(helper)) errors.push(issue("selected connection tracking helper is missing or invalid"));
    else if ((table.family === "ip" && helper.l3proto === "ip6") || (table.family === "ip6" && helper.l3proto === "ip")) {
      errors.push(issue("selected connection tracking helper does not match the table family"));
    } else if (setNames.has(helper.name) || (table.maps || []).some((map) => map.name === helper.name) || (table.chains || []).some((item) => item.name === helper.name)) {
      errors.push(issue(`helper name "${helper.name}" conflicts with another object in this table`));
    }
    else parts.push(`ct helper set ${quoteString(helper.name)}`);
  }

  if (rule.tcpFlags) {
    if (!TCP_FLAG_MATCHES.has(rule.tcpFlags)) errors.push(issue("choose a supported TCP flag match"));
    else if (rule.tcpFlags === "syn") parts.push("tcp flags syn / syn,rst,ack");
    else parts.push(`tcp flags ${rule.tcpFlags}`);
  }
  if (rule.icmpType) {
    if (protocol !== "icmp" || !/^[a-z0-9-]+$/i.test(rule.icmpType)) errors.push(issue("ICMP type needs the ICMP protocol and a simple type name"));
    else parts.push(`icmp type ${rule.icmpType}`);
  }
  if (rule.icmpv6Type) {
    if (protocol !== "icmpv6" || !/^[a-z0-9-]+$/i.test(rule.icmpv6Type)) errors.push(issue("ICMPv6 type needs the ICMPv6 protocol and a simple type name"));
    else parts.push(`icmpv6 type ${rule.icmpv6Type}`);
  }
  if (rule.metaMark) {
    if (!isMark(rule.metaMark)) errors.push(issue("packet mark must be decimal or hexadecimal"));
    else parts.push(`meta mark ${rule.metaMark}`);
  }

  const selectedMap = mapAction(rule, table, maps, setNames, errors);
  if (selectedMap.expression) parts.push(selectedMap.expression);

  if (rule.counter) parts.push("counter");
  if (rule.limitMode && rule.limitMode !== "none") {
    if (!/^\d+$/.test(String(rule.limitRate || "")) || Number(rule.limitRate) < 1) {
      errors.push(issue("rate limit needs a positive whole-number rate"));
    } else if (!["second", "minute", "hour", "day"].includes(rule.limitUnit)) {
      errors.push(issue("choose a supported rate unit"));
    } else if (rule.limitMode === "packets") {
      const burst = rule.limitBurst ? ` burst ${rule.limitBurst} packets` : "";
      if (rule.limitBurst && (!/^\d+$/.test(rule.limitBurst) || Number(rule.limitBurst) < 1)) errors.push(issue("packet burst must be a positive whole number"));
      parts.push(`limit rate ${rule.limitRate}/${rule.limitUnit}${burst}`);
    } else if (rule.limitMode === "bytes" && ["bytes", "kbytes", "mbytes"].includes(rule.limitBytesUnit)) {
      const burst = rule.limitBurst ? ` burst ${rule.limitBurst} ${rule.limitBytesUnit}` : "";
      if (rule.limitBurst && (!/^\d+$/.test(rule.limitBurst) || Number(rule.limitBurst) < 1)) errors.push(issue("byte burst must be a positive whole number"));
      parts.push(`limit rate ${rule.limitRate} ${rule.limitBytesUnit}/${rule.limitUnit}${burst}`);
    } else {
      errors.push(issue("choose a supported byte rate unit"));
    }
  }

  if (rule.logPrefix || rule.logFlags || rule.logLevel) {
    if (!LOG_FLAGS.has(rule.logFlags || "") || !LOG_LEVELS.has(rule.logLevel || "")) {
      errors.push(issue("choose supported log flags and level"));
    } else {
      const fields = ["log"];
      if (rule.logPrefix) fields.push(`prefix ${quoteString(rule.logPrefix)}`);
      if (rule.logLevel) fields.push(`level ${rule.logLevel}`);
      if (rule.logFlags) fields.push(`flags ${rule.logFlags}`);
      parts.push(fields.join(" "));
    }
  }

  const chainNames = new Set((table.chains || []).map((item) => item.name).filter(isNftIdentifier));
  if ((rule.verdict === "snat" || rule.verdict === "dnat" || rule.verdict === "redirect" || rule.verdict === "masquerade") && rule.natPort) {
    if (!["tcp", "udp", "sctp"].includes(protocol)) {
      errors.push(issue("NAT with a port needs TCP, UDP, or SCTP selected"));
    } else if (!hasPorts && (protocol === "tcp" || protocol === "udp")) {
      // ensure protocol is present for :port rewriting
      if (!parts.includes(`meta l4proto ${protocol}`)) parts.push(`meta l4proto ${protocol}`);
    }
  }
  if (!selectedMap.controlsVerdict) {
    const verdict = buildVerdict(rule, table, chain, chainNames, errors);
    if (verdict) parts.push(verdict);
  }

  return {
    line: errors.length ? "" : parts.join(" "),
    issues: [...errors, ...warnings],
  };
}

function emitAddressSet(group) {
  const lines = [];
  const comment = cleanComment(group.comment);
  if (comment) lines.push(`\t# ${comment}`);
  const flags = group.timeout ? "interval,timeout" : "interval";
  lines.push(`\tset ${group.name} {`);
  lines.push(`\t\ttype ${group.addrType === "ipv6" ? "ipv6_addr" : "ipv4_addr"}`);
  lines.push(`\t\tflags ${flags}`);
  if (group.timeout) lines.push(`\t\ttimeout ${group.timeout}`);
  lines.push(`\t\telements = { ${(group.elements || []).filter(Boolean).join(", ")} }`);
  lines.push("\t}");
  return lines;
}

function emitPortSet(group) {
  const lines = [];
  const comment = cleanComment(group.comment);
  if (comment) lines.push(`\t# ${comment}`);
  const flags = group.timeout ? "interval,timeout" : "interval";
  lines.push(`\tset ${group.name} {`);
  lines.push("\t\ttype inet_service");
  lines.push(`\t\tflags ${flags}`);
  if (group.timeout) lines.push(`\t\ttimeout ${group.timeout}`);
  lines.push(`\t\telements = { ${(group.elements || []).filter(Boolean).join(", ")} }`);
  lines.push("\t}");
  return lines;
}

function emitMap(map) {
  const lines = [];
  const comment = cleanComment(map.comment);
  if (comment) lines.push(`\t# ${comment}`);
  lines.push(`\tmap ${map.name} {`);
  lines.push(`\t\ttype ${map.keyType} : ${map.valueType === "mark" ? "mark" : "verdict"}`);
  lines.push(`\t\telements = { ${(map.entries || []).map((entry) => `${entry.key} : ${entry.value}`).join(", ")} }`);
  lines.push("\t}");
  return lines;
}

function emitHelper(helper) {
  const lines = [];
  const comment = cleanComment(helper.comment);
  if (comment) lines.push(`\t# ${comment}`);
  lines.push(`\tct helper ${helper.name} {`);
  lines.push(`\t\ttype ${quoteString(helper.type)} protocol ${helper.protocol}; l3proto ${helper.l3proto};`);
  lines.push("\t}");
  return lines;
}

function validChainForTable(table, chain) {
  const hooks = {
    inet: new Set(["prerouting", "input", "forward", "output", "postrouting"]),
    ip: new Set(["prerouting", "input", "forward", "output", "postrouting"]),
    ip6: new Set(["prerouting", "input", "forward", "output", "postrouting"]),
    bridge: new Set(["prerouting", "input", "forward", "output", "postrouting"]),
    netdev: new Set(["ingress", "egress"]),
  };
  if (!isNftIdentifier(chain.name)) return false;
  if (!PRIORITIES.has(String(chain.priority || ""))) return false;
  if (!chain.hook) return true;
  if (!hooks[table.family]?.has(chain.hook)) return false;
  if (table.family === "netdev" && chain.type !== "filter") return false;
  if (table.family === "netdev" && !String(chain.device || "").trim()) return false;
  if (table.family === "bridge" && chain.type !== "filter") return false;
  if (chain.type === "nat" && !["inet", "ip", "ip6"].includes(table.family)) return false;
  if (chain.type === "nat" && !["prerouting", "input", "output", "postrouting"].includes(chain.hook)) return false;
  if (chain.type === "route" && !["inet", "ip", "ip6"].includes(table.family)) return false;
  if (chain.type === "route" && chain.hook !== "output") return false;
  return true;
}

function emitChain(state, table, chain) {
  const lines = [];
  const comment = cleanComment(chain.comment);
  if (comment) lines.push(`\t# ${comment}`);
  if (!validChainForTable(table, chain)) {
    lines.push(`\t# skipped invalid chain: ${cleanComment(chain.name || "(unnamed)")}`);
    return lines;
  }
  lines.push(`\tchain ${chain.name} {`);
  if (chain.hook) {
    let base = `\t\ttype ${chain.type} hook ${chain.hook} priority ${chain.priority || "filter"};`;
    if (table.family === "netdev") base = `\t\ttype ${chain.type} hook ${chain.hook} device ${quoteInterface(chain.device)} priority ${chain.priority || "filter"};`;
    if (chain.type === "filter") base += ` policy ${chain.policy === "drop" ? "drop" : "accept"};`;
    lines.push(base);
    if (chain.hook === "forward" && ["inet", "ip", "ip6"].includes(table.family)) {
      if (table.family === "inet" || table.family === "ip") lines.push("\t\t# forwarding needs: sysctl -w net.ipv4.ip_forward=1");
      if (table.family === "inet" || table.family === "ip6") lines.push("\t\t# forwarding needs: sysctl -w net.ipv6.conf.all.forwarding=1");
    }
  } else {
    lines.push("\t\t# regular chain");
  }

  for (const rule of chain.rules || []) {
    const rendered = getRuleSyntax(state, table, chain, rule);
    const commentText = cleanComment(rule.comment);
    if (commentText) lines.push(`\t\t# ${commentText}`);
    if (rendered.line) lines.push(`\t\t${rendered.line}`);
    else lines.push(`\t\t# skipped invalid rule: ${rendered.issues.filter((item) => item.level === "error").map((item) => cleanComment(item.message)).join("; ")}`);
  }
  lines.push("\t}");
  return lines;
}

function message(issueValue) {
  return cleanComment(typeof issueValue === "string" ? issueValue : issueValue.message);
}

export function generateConfig(state, issues = []) {
  const lines = [
    "#!/usr/sbin/nft -f",
    "# generated by nft-gui",
    "# check before applying: nft --check --file nftables.conf",
  ];
  const visibleIssues = (issues || []).map(message).filter(Boolean);
  if (visibleIssues.length) {
    lines.push("# review:");
    for (const item of visibleIssues) lines.push(`#   ${item}`);
  }
  lines.push(state.flushRuleset !== false ? "flush ruleset" : "# flush ruleset omitted");
  lines.push("");

  const seenTables = new Set();
  for (const table of state.tables || []) {
    const identity = `${table.family}:${table.name}`;
    if (!isNftIdentifier(table.name) || !["inet", "ip", "ip6", "bridge", "netdev"].includes(table.family) || seenTables.has(identity)) {
      lines.push(`# skipped invalid or duplicate table: ${cleanComment(table.name || "(unnamed)")}`);
      lines.push("");
      continue;
    }
    seenTables.add(identity);
    const comment = cleanComment(table.comment);
    if (comment) lines.push(`# ${comment}`);
    lines.push(`table ${table.family} ${table.name} {`);

    const usedAddrGroups = new Set();
    const usedPortGroups = new Set();
    for (const chain of table.chains || []) {
      for (const rule of chain.rules || []) {
        if (rule.saddrMode === "group") usedAddrGroups.add(rule.saddrGroupId);
        if (rule.daddrMode === "group") usedAddrGroups.add(rule.daddrGroupId);
        if (rule.sportMode === "group") usedPortGroups.add(rule.sportGroupId);
        if (rule.dportMode === "group") usedPortGroups.add(rule.dportGroupId);
      }
    }

    const objectNames = new Set();
    for (const group of (state.addressGroups || []).filter((item) => usedAddrGroups.has(item.id))) {
      if (!validAddressGroup(group) || objectNames.has(group.name) ||
        (table.family === "ip" && group.addrType === "ipv6") || (table.family === "ip6" && group.addrType === "ipv4")) continue;
      objectNames.add(group.name);
      lines.push(...emitAddressSet(group), "");
    }
    for (const group of (state.portGroups || []).filter((item) => usedPortGroups.has(item.id))) {
      if (!validPortGroup(group) || objectNames.has(group.name)) continue;
      objectNames.add(group.name);
      lines.push(...emitPortSet(group), "");
    }
    for (const map of table.maps || []) {
      if (!validMap(map) || objectNames.has(map.name) ||
        (table.family === "ip" && map.keyType === "ipv6_addr") || (table.family === "ip6" && map.keyType === "ipv4_addr")) continue;
      objectNames.add(map.name);
      lines.push(...emitMap(map), "");
    }
    for (const helper of table.helpers || []) {
      if (!validHelper(helper) || objectNames.has(helper.name) ||
        (table.family === "ip" && helper.l3proto === "ip6") || (table.family === "ip6" && helper.l3proto === "ip")) continue;
      objectNames.add(helper.name);
      lines.push(...emitHelper(helper), "");
    }

    const chainNames = new Set();
    for (const chain of table.chains || []) {
      if (chainNames.has(chain.name) || objectNames.has(chain.name)) {
        lines.push(`\t# skipped chain with duplicate name: ${cleanComment(chain.name || "(unnamed)")}`, "");
        continue;
      }
      chainNames.add(chain.name);
      objectNames.add(chain.name);
      lines.push(...emitChain(state, table, chain), "");
    }
    lines.push("}", "");
  }
  return lines.join("\n");
}

export function summarizeRule(rule, state, table) {
  if (rule.enabled === false) return "(disabled)";
  const bits = [];
  if (rule.comment) bits.push(cleanComment(rule.comment));
  if (rule.iifname) bits.push(`in:${cleanSingleLine(rule.iifname)}`);
  if (rule.oifname) bits.push(`out:${cleanSingleLine(rule.oifname)}`);
  if (rule.l4proto) bits.push(rule.l4proto);
  if (rule.dportMode === "value" && rule.dportValue) bits.push(`dport ${cleanSingleLine(rule.dportValue)}`);
  if (rule.dportMode === "group") {
    const group = (state.portGroups || []).find((item) => item.id === rule.dportGroupId);
    bits.push(`dport @${group ? group.name : "?"}`);
  }
  if (rule.mapId) {
    const map = (table?.maps || []).find((item) => item.id === rule.mapId);
    bits.push(map ? `map @${map.name}` : "map ?");
  }
  bits.push(rule.verdict || "accept");
  return bits.join("; ");
}
