import {
  STORAGE_KEY,
  emptyDraft,
  emptySecrets,
  applyProfileDefaults,
  defaultEnv,
  defaultCompose,
  defaultPrune,
  defaultOptions,
  DEFAULT_INCLUDES,
  DEFAULT_EXCLUDES,
} from "./defaults.js";

function deepMerge(base, patch) {
  if (!patch || typeof patch !== "object") return structuredClone(base);
  const out = structuredClone(base);
  for (const [k, v] of Object.entries(patch)) {
    if (v && typeof v === "object" && !Array.isArray(v) && typeof out[k] === "object" && out[k]) {
      out[k] = deepMerge(out[k], v);
    } else if (v !== undefined) {
      out[k] = v;
    }
  }
  return out;
}

function normalizeDraft(raw) {
  const base = emptyDraft();
  if (!raw || typeof raw !== "object") return base;
  const merged = deepMerge(base, {
    profile: raw.profile,
    env: raw.env,
    includes: raw.includes,
    excludes: raw.excludes,
    compose: raw.compose,
    prune: raw.prune,
    options: raw.options,
  });
  if (!merged.includes) merged.includes = DEFAULT_INCLUDES;
  if (!merged.excludes) merged.excludes = DEFAULT_EXCLUDES;
  if (!merged.env) merged.env = defaultEnv();
  if (!merged.compose) merged.compose = defaultCompose();
  if (!merged.prune) merged.prune = defaultPrune();
  if (!merged.options) merged.options = defaultOptions();
  return merged;
}

export function createStore() {
  let draft = loadDraft();
  let secrets = emptySecrets();
  const listeners = new Set();

  function notify() {
    for (const fn of listeners) fn();
  }

  function persist() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(draft));
    } catch {
      // ignore quota / private mode
    }
  }

  return {
    getDraft() {
      return draft;
    },
    getSecrets() {
      return secrets;
    },
    subscribe(fn) {
      listeners.add(fn);
      return () => listeners.delete(fn);
    },
    setDraft(next) {
      draft = normalizeDraft(next);
      persist();
      notify();
    },
    patchDraft(patch) {
      draft = normalizeDraft({ ...draft, ...patch });
      persist();
      notify();
    },
    patchEnv(patch) {
      draft = normalizeDraft({ ...draft, env: { ...draft.env, ...patch } });
      persist();
      notify();
    },
    patchCompose(patch) {
      draft = normalizeDraft({ ...draft, compose: { ...draft.compose, ...patch } });
      persist();
      notify();
    },
    patchPrune(patch) {
      draft = normalizeDraft({ ...draft, prune: { ...draft.prune, ...patch } });
      persist();
      notify();
    },
    patchOptions(patch) {
      draft = normalizeDraft({ ...draft, options: { ...draft.options, ...patch } });
      persist();
      notify();
    },
    setProfile(profile) {
      draft = applyProfileDefaults(draft, profile);
      persist();
      notify();
    },
    setIncludes(text) {
      draft = { ...draft, includes: text };
      persist();
      notify();
    },
    setExcludes(text) {
      draft = { ...draft, excludes: text };
      persist();
      notify();
    },
    setSecret(key, value) {
      secrets = { ...secrets, [key]: value };
      notify();
    },
    forgetSecrets() {
      secrets = emptySecrets();
      notify();
    },
    resetDraft() {
      draft = emptyDraft();
      secrets = emptySecrets();
      persist();
      notify();
    },
  };
}

function loadDraft() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return emptyDraft();
    return normalizeDraft(JSON.parse(raw));
  } catch {
    return emptyDraft();
  }
}
