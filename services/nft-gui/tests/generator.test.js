import assert from "node:assert/strict";
import test from "node:test";

import {
  emptyAddressGroup,
  emptyChain,
  emptyMap,
  emptyMapEntry,
  emptyRule,
  emptyTable,
  normalizeRuleset,
} from "../web/js/store.js";
import { generateConfig, getRuleSyntax } from "../web/js/generator.js";
import { collectValidation } from "../web/js/validate.js";
import { getPreset } from "../web/js/presets.js";

function basicState() {
  const table = { ...emptyTable(), id: "table_1", name: "filter", family: "inet" };
  const chain = { ...emptyChain(), id: "chain_1", name: "input", type: "filter", hook: "input", policy: "drop", rules: [] };
  table.chains = [chain];
  return { version: 2, flushRuleset: true, addressGroups: [], portGroups: [], tables: [table] };
}

test("invalid jump rules are skipped instead of emitted", () => {
  const state = basicState();
  const rule = { ...emptyRule(), id: "rule_1", verdict: "jump", jumpChain: "" };
  state.tables[0].chains[0].rules = [rule];

  const rendered = getRuleSyntax(state, state.tables[0], state.tables[0].chains[0], rule);
  assert.equal(rendered.line, "");
  assert.match(rendered.issues[0].message, /needs a chain/);

  const config = generateConfig(state, collectValidation(state));
  assert.match(config, /skipped invalid rule/);
  assert.doesNotMatch(config, /INVALID_CHAIN/);
});

test("verdict maps emit typed lookup expressions", () => {
  const state = basicState();
  const map = {
    ...emptyMap(),
    id: "map_1",
    name: "client_policy",
    keyType: "ipv4_addr",
    valueType: "verdict",
    entries: [{ ...emptyMapEntry(), id: "entry_1", key: "192.0.2.10", value: "drop" }],
  };
  const rule = { ...emptyRule(), id: "rule_1", mapId: map.id, mapSelector: "saddr", verdict: "accept" };
  state.tables[0].maps = [map];
  state.tables[0].chains[0].rules = [rule];

  const rendered = getRuleSyntax(state, state.tables[0], state.tables[0].chains[0], rule);
  assert.equal(rendered.line, "ip saddr vmap @client_policy");

  const config = generateConfig(state, []);
  assert.match(config, /type ipv4_addr : verdict/);
  assert.match(config, /192\.0\.2\.10 : drop/);
});

test("set timeouts and forwarding guidance are emitted", () => {
  const state = basicState();
  const group = {
    ...emptyAddressGroup(),
    id: "addr_1",
    name: "trusted_hosts",
    timeout: "1h",
    elements: ["192.0.2.10"],
  };
  const chain = { ...emptyChain(), id: "chain_1", name: "forward", type: "filter", hook: "forward", policy: "drop", rules: [] };
  const rule = { ...emptyRule(), id: "rule_1", saddrMode: "group", saddrGroupId: group.id, verdict: "accept" };
  chain.rules = [rule];
  state.addressGroups = [group];
  state.tables[0].chains = [chain];

  const config = generateConfig(state, []);
  assert.match(config, /flags interval,timeout/);
  assert.match(config, /timeout 1h/);
  assert.match(config, /net\.ipv4\.ip_forward=1/);
  assert.match(config, /net\.ipv6\.conf\.all\.forwarding=1/);
});

test("normalization removes raw expressions and bounds imports to supported fields", () => {
  const state = normalizeRuleset({
    version: 1,
    flushRuleset: true,
    addressGroups: [],
    portGroups: [],
    tables: [{
      id: "table_1",
      name: "filter",
      family: "inet",
      chains: [{
        id: "chain_1",
        name: "input",
        rules: [{ id: "rule_1", rawMatch: "flush ruleset", verdict: "accept" }],
      }],
    }],
  });

  assert.equal(state.version, 2);
  assert.equal("rawMatch" in state.tables[0].chains[0].rules[0], false);
});

test("the LAN routing preset generates a NAT table without validation errors", () => {
  const state = getPreset("lan-router").build();
  assert.deepEqual(collectValidation(state), []);

  const config = generateConfig(state, []);
  assert.match(config, /table ip nat/);
  assert.match(config, /masquerade/);
  assert.match(config, /net\.ipv4\.ip_forward=1/);
});
