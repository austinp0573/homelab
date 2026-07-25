export function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

export function downloadBlob(filename, blob) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export function field(label, input) {
  const wrap = document.createElement("label");
  wrap.className = "field";
  const title = document.createElement("span");
  title.className = "field-label";
  title.textContent = label;
  wrap.append(title, input);
  return wrap;
}

export function textInput(value, onInput, attrs = {}) {
  const input = document.createElement(attrs.multiline ? "textarea" : "input");
  if (!attrs.multiline) input.type = attrs.type || "text";
  input.value = value ?? "";
  if (attrs.rows) input.rows = attrs.rows;
  if (attrs.placeholder) input.placeholder = attrs.placeholder;
  if (attrs.className) input.className = attrs.className;
  if (attrs.spellcheck === false) input.spellcheck = false;
  input.addEventListener("input", () => onInput(input.value));
  return input;
}

export function checkbox(checked, onChange, labelText) {
  const wrap = document.createElement("label");
  wrap.className = "check";
  const input = document.createElement("input");
  input.type = "checkbox";
  input.checked = !!checked;
  input.addEventListener("change", () => onChange(input.checked));
  wrap.append(input, document.createTextNode(" " + labelText));
  return wrap;
}

export function selectInput(value, options, onChange) {
  const select = document.createElement("select");
  for (const opt of options) {
    const o = document.createElement("option");
    o.value = opt.value;
    o.textContent = opt.label;
    if (opt.value === value) o.selected = true;
    select.append(o);
  }
  select.addEventListener("change", () => onChange(select.value));
  return select;
}
