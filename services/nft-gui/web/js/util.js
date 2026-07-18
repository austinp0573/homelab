export function uid(prefix = "id") {
  return `${prefix}_${Math.random().toString(36).slice(2, 10)}${Date.now().toString(36).slice(-4)}`;
}

export function deepClone(value) {
  return JSON.parse(JSON.stringify(value));
}

export function isNftIdentifier(value) {
  return /^[a-zA-Z_][a-zA-Z0-9_]*$/.test(String(value || ""));
}

export function cleanSingleLine(value) {
  return String(value || "")
    .replace(/[\r\n\u2028\u2029]+/g, " ")
    .replace(/[\u0000-\u001f\u007f]/g, " ")
    .trim();
}

export function isDuration(value) {
  return /^\d+(?:ms|s|m|h|d|w)$/.test(String(value || "").trim());
}

export function isMark(value) {
  return /^(?:0x[0-9a-fA-F]+|\d+)$/.test(String(value || "").trim());
}

export function isPortSpec(value) {
  const parts = String(value || "").trim().split("-");
  if (parts.length > 2 || parts.some((part) => !/^\d+$/.test(part))) return false;
  const numbers = parts.map(Number);
  return numbers.every((part) => part >= 0 && part <= 65535) && (numbers.length === 1 || numbers[0] <= numbers[1]);
}

export function isAddress(value, type = "") {
  const raw = String(value || "").trim();
  if (!raw || /[\s,{};]/.test(raw)) return false;
  const [address, prefix] = raw.split("/");
  if (raw.split("/").length > 2) return false;

  if (address.includes(":")) {
    if (type === "ipv4" || !isIpv6(address)) return false;
    if (prefix !== undefined && (!/^\d+$/.test(prefix) || Number(prefix) > 128)) return false;
    return true;
  }

  if (type === "ipv6") return false;
  const octets = address.split(".");
  if (octets.length !== 4 || octets.some((part) => !/^\d+$/.test(part) || Number(part) > 255)) return false;
  if (prefix !== undefined && (!/^\d+$/.test(prefix) || Number(prefix) > 32)) return false;
  return true;
}

function isIpv6(address) {
  if (!/^[0-9a-fA-F:.]+$/.test(address) || address.includes(":::") || address.split("::").length > 2) return false;
  const hasCompression = address.includes("::");
  const pieces = address.split(":");
  let groups = 0;

  for (let index = 0; index < pieces.length; index += 1) {
    const piece = pieces[index];
    if (!piece) continue;
    if (piece.includes(".")) {
      if (index !== pieces.length - 1 || !isAddress(piece, "ipv4")) return false;
      groups += 2;
      continue;
    }
    if (!/^[0-9a-fA-F]{1,4}$/.test(piece)) return false;
    groups += 1;
  }
  return hasCompression ? groups < 8 : groups === 8;
}

export function addressTypeForValue(value) {
  return String(value || "").includes(":") ? "ipv6" : "ipv4";
}
