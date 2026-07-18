import {
  emptyAddressGroup,
  emptyPortGroup,
  emptyTable,
  emptyChain,
  emptyRule,
} from "./store.js";
import { uid } from "./util.js";

function rule(partial) {
  return { ...emptyRule(), id: uid("rule"), ...partial };
}

function chain(partial, rules = []) {
  return { ...emptyChain(), id: uid("chain"), ...partial, rules };
}

function table(partial, chains = []) {
  return { ...emptyTable(), id: uid("table"), ...partial, chains };
}

function addr(partial, elements) {
  return { ...emptyAddressGroup(), id: uid("addr"), elements, ...partial };
}

function ports(partial, elements) {
  return { ...emptyPortGroup(), id: uid("port"), elements, ...partial };
}

export const PRESETS = [
  {
    id: "blank",
    name: "blank ruleset",
    description: "clear everything and start empty",
    build() {
      return {
        version: 1,
        flushRuleset: true,
        addressGroups: [],
        portGroups: [],
        tables: [],
      };
    },
  },
  {
    id: "host-server",
    name: "basic host firewall",
    description: "inet filter with drop input, allow established, ssh, http/https",
    build() {
      const sshHttp = ports({ name: "svc_web_ssh", comment: "ssh and web" }, ["22", "80", "443"]);
      return {
        version: 1,
        flushRuleset: true,
        addressGroups: [],
        portGroups: [sshHttp],
        tables: [
          table(
            { name: "filter", family: "inet", comment: "host firewall" },
            [
              chain(
                { name: "input", type: "filter", hook: "input", priority: "filter", policy: "drop" },
                [
                  rule({
                    comment: "allow loopback",
                    iifname: "lo",
                    verdict: "accept",
                  }),
                  rule({
                    comment: "allow established and related",
                    ctState: ["established", "related"],
                    verdict: "accept",
                  }),
                  rule({
                    comment: "drop invalid",
                    ctState: ["invalid"],
                    counter: true,
                    verdict: "drop",
                  }),
                  rule({
                    comment: "allow icmp",
                    l4proto: "icmp",
                    verdict: "accept",
                  }),
                  rule({
                    comment: "allow icmpv6",
                    l4proto: "icmpv6",
                    verdict: "accept",
                  }),
                  rule({
                    comment: "allow ssh and web",
                    l4proto: "tcp",
                    dportMode: "group",
                    dportGroupId: sshHttp.id,
                    ctState: ["new"],
                    counter: true,
                    verdict: "accept",
                  }),
                ]
              ),
              chain(
                { name: "forward", type: "filter", hook: "forward", priority: "filter", policy: "drop" },
                []
              ),
              chain(
                { name: "output", type: "filter", hook: "output", priority: "filter", policy: "accept" },
                []
              ),
            ]
          ),
        ],
      };
    },
  },
  {
    id: "lan-router",
    name: "lan nat gateway",
    description: "forward lan traffic and masquerade out the wan interface",
    build() {
      const lan = addr(
        { name: "lan_nets", addrType: "ipv4", comment: "private lan ranges" },
        ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12"]
      );
      return {
        version: 1,
        flushRuleset: true,
        addressGroups: [lan],
        portGroups: [],
        tables: [
          table(
            { name: "filter", family: "inet", comment: "forwarding filter" },
            [
              chain(
                { name: "input", type: "filter", hook: "input", priority: "filter", policy: "drop" },
                [
                  rule({ comment: "loopback", iifname: "lo", verdict: "accept" }),
                  rule({
                    comment: "established",
                    ctState: ["established", "related"],
                    verdict: "accept",
                  }),
                  rule({
                    comment: "ssh from lan",
                    iifname: "eth1",
                    l4proto: "tcp",
                    dportMode: "value",
                    dportValue: "22",
                    saddrMode: "group",
                    saddrGroupId: lan.id,
                    verdict: "accept",
                  }),
                ]
              ),
              chain(
                { name: "forward", type: "filter", hook: "forward", priority: "filter", policy: "drop" },
                [
                  rule({
                    comment: "established forward",
                    ctState: ["established", "related"],
                    verdict: "accept",
                  }),
                  rule({
                    comment: "lan to wan",
                    iifname: "eth1",
                    oifname: "eth0",
                    saddrMode: "group",
                    saddrGroupId: lan.id,
                    counter: true,
                    verdict: "accept",
                  }),
                ]
              ),
              chain(
                { name: "output", type: "filter", hook: "output", priority: "filter", policy: "accept" },
                []
              ),
            ]
          ),
          table(
            { name: "nat", family: "ip", comment: "source nat" },
            [
              chain(
                {
                  name: "postrouting",
                  type: "nat",
                  hook: "postrouting",
                  priority: "srcnat",
                  policy: "accept",
                },
                [
                  rule({
                    comment: "masquerade lan out wan",
                    oifname: "eth0",
                    saddrMode: "group",
                    saddrGroupId: lan.id,
                    verdict: "masquerade",
                  }),
                ]
              ),
            ]
          ),
        ],
      };
    },
  },
  {
    id: "wg-endpoint",
    name: "wireguard endpoint",
    description: "allow wg port and forward tunnel traffic with a peer set",
    build() {
      const peers = addr(
        { name: "wg_peers", addrType: "ipv4", comment: "allowed wireguard peer tunnel ips" },
        ["10.10.0.2", "10.10.0.3"]
      );
      return {
        version: 1,
        flushRuleset: true,
        addressGroups: [peers],
        portGroups: [],
        tables: [
          table(
            { name: "filter", family: "inet", comment: "wireguard host" },
            [
              chain(
                { name: "input", type: "filter", hook: "input", priority: "filter", policy: "drop" },
                [
                  rule({ comment: "loopback", iifname: "lo", verdict: "accept" }),
                  rule({
                    comment: "established",
                    ctState: ["established", "related"],
                    verdict: "accept",
                  }),
                  rule({
                    comment: "ssh",
                    l4proto: "tcp",
                    dportMode: "value",
                    dportValue: "22",
                    ctState: ["new"],
                    verdict: "accept",
                  }),
                  rule({
                    comment: "wireguard listen",
                    l4proto: "udp",
                    dportMode: "value",
                    dportValue: "51820",
                    counter: true,
                    verdict: "accept",
                  }),
                ]
              ),
              chain(
                { name: "forward", type: "filter", hook: "forward", priority: "filter", policy: "drop" },
                [
                  rule({
                    comment: "established forward",
                    ctState: ["established", "related"],
                    verdict: "accept",
                  }),
                  rule({
                    comment: "wg peers through tunnel",
                    iifname: "wg0",
                    saddrMode: "group",
                    saddrGroupId: peers.id,
                    verdict: "accept",
                  }),
                  rule({
                    comment: "to wg peers",
                    oifname: "wg0",
                    daddrMode: "group",
                    daddrGroupId: peers.id,
                    verdict: "accept",
                  }),
                ]
              ),
              chain(
                { name: "output", type: "filter", hook: "output", priority: "filter", policy: "accept" },
                []
              ),
            ]
          ),
        ],
      };
    },
  },
  {
    id: "ssh-host",
    name: "ssh-only host",
    description: "drop input, allow loopback, established traffic, icmp, and ssh",
    build() {
      return {
        version: 1,
        flushRuleset: true,
        addressGroups: [],
        portGroups: [],
        tables: [
          table(
            { name: "filter", family: "inet", comment: "ssh host firewall" },
            [
              chain(
                { name: "input", type: "filter", hook: "input", priority: "filter", policy: "drop" },
                [
                  rule({ comment: "loopback", iifname: "lo", verdict: "accept" }),
                  rule({ comment: "established", ctState: ["established", "related"], verdict: "accept" }),
                  rule({ comment: "drop invalid", ctState: ["invalid"], counter: true, verdict: "drop" }),
                  rule({ comment: "icmp", l4proto: "icmp", verdict: "accept" }),
                  rule({ comment: "icmpv6", l4proto: "icmpv6", verdict: "accept" }),
                  rule({
                    comment: "ssh",
                    l4proto: "tcp",
                    dportMode: "value",
                    dportValue: "22",
                    ctState: ["new"],
                    counter: true,
                    verdict: "accept",
                  }),
                ]
              ),
              chain(
                { name: "output", type: "filter", hook: "output", priority: "filter", policy: "accept" },
                []
              ),
            ]
          ),
        ],
      };
    },
  },
  {
    id: "lan-dns",
    name: "lan dns resolver",
    description: "allow lan clients to query a local dns resolver over tcp and udp",
    build() {
      const lan = addr({ name: "lan_clients", addrType: "ipv4", comment: "local clients" }, ["192.168.1.0/24"]);
      const dnsPorts = ports({ name: "dns_ports", comment: "dns tcp and udp" }, ["53"]);
      return {
        version: 1,
        flushRuleset: true,
        addressGroups: [lan],
        portGroups: [dnsPorts],
        tables: [
          table(
            { name: "filter", family: "inet", comment: "local dns resolver" },
            [
              chain(
                { name: "input", type: "filter", hook: "input", priority: "filter", policy: "drop" },
                [
                  rule({ comment: "loopback", iifname: "lo", verdict: "accept" }),
                  rule({ comment: "established", ctState: ["established", "related"], verdict: "accept" }),
                  rule({
                    comment: "dns udp from lan",
                    l4proto: "udp",
                    saddrMode: "group",
                    saddrGroupId: lan.id,
                    dportMode: "group",
                    dportGroupId: dnsPorts.id,
                    verdict: "accept",
                  }),
                  rule({
                    comment: "dns tcp from lan",
                    l4proto: "tcp",
                    saddrMode: "group",
                    saddrGroupId: lan.id,
                    dportMode: "group",
                    dportGroupId: dnsPorts.id,
                    verdict: "accept",
                  }),
                ]
              ),
              chain(
                { name: "output", type: "filter", hook: "output", priority: "filter", policy: "accept" },
                []
              ),
            ]
          ),
        ],
      };
    },
  },
  {
    id: "web-port-forward",
    name: "web port forward",
    description: "forward wan tcp 443 to a lan web server and masquerade lan traffic",
    build() {
      const lan = addr({ name: "lan_nets", addrType: "ipv4", comment: "private lan" }, ["192.168.1.0/24"]);
      return {
        version: 1,
        flushRuleset: true,
        addressGroups: [lan],
        portGroups: [],
        tables: [
          table(
            { name: "filter", family: "inet", comment: "forwarding filter" },
            [
              chain(
                { name: "forward", type: "filter", hook: "forward", priority: "filter", policy: "drop" },
                [
                  rule({ comment: "established forward", ctState: ["established", "related"], verdict: "accept" }),
                  rule({ comment: "accept dnat traffic", ctStatus: ["dnat"], counter: true, verdict: "accept" }),
                  rule({
                    comment: "lan to wan",
                    iifname: "eth1",
                    oifname: "eth0",
                    saddrMode: "group",
                    saddrGroupId: lan.id,
                    verdict: "accept",
                  }),
                ]
              ),
            ]
          ),
          table(
            { name: "nat", family: "ip", comment: "web port forward and source nat" },
            [
              chain(
                { name: "prerouting", type: "nat", hook: "prerouting", priority: "dstnat", policy: "accept" },
                [
                  rule({
                    comment: "wan https to web server",
                    iifname: "eth0",
                    l4proto: "tcp",
                    dportMode: "value",
                    dportValue: "443",
                    verdict: "dnat",
                    natAddr: "192.168.1.10",
                    natPort: "443",
                  }),
                ]
              ),
              chain(
                { name: "postrouting", type: "nat", hook: "postrouting", priority: "srcnat", policy: "accept" },
                [
                  rule({
                    comment: "masquerade lan out wan",
                    oifname: "eth0",
                    saddrMode: "group",
                    saddrGroupId: lan.id,
                    verdict: "masquerade",
                  }),
                ]
              ),
            ]
          ),
        ],
      };
    },
  },
  {
    id: "guest-network",
    name: "guest network gateway",
    description: "allow a guest subnet to reach the wan without access to the lan",
    build() {
      const guest = addr({ name: "guest_net", addrType: "ipv4", comment: "guest subnet" }, ["192.168.50.0/24"]);
      return {
        version: 1,
        flushRuleset: true,
        addressGroups: [guest],
        portGroups: [],
        tables: [
          table(
            { name: "filter", family: "inet", comment: "guest forwarding filter" },
            [
              chain(
                { name: "forward", type: "filter", hook: "forward", priority: "filter", policy: "drop" },
                [
                  rule({ comment: "established forward", ctState: ["established", "related"], verdict: "accept" }),
                  rule({
                    comment: "guest to wan",
                    iifname: "eth2",
                    oifname: "eth0",
                    saddrMode: "group",
                    saddrGroupId: guest.id,
                    counter: true,
                    verdict: "accept",
                  }),
                ]
              ),
            ]
          ),
          table(
            { name: "nat", family: "ip", comment: "guest source nat" },
            [
              chain(
                { name: "postrouting", type: "nat", hook: "postrouting", priority: "srcnat", policy: "accept" },
                [
                  rule({
                    comment: "masquerade guest out wan",
                    oifname: "eth0",
                    saddrMode: "group",
                    saddrGroupId: guest.id,
                    verdict: "masquerade",
                  }),
                ]
              ),
            ]
          ),
        ],
      };
    },
  },
  {
    id: "wg-gateway",
    name: "wireguard internet gateway",
    description: "allow wireguard clients to reach the wan with source nat",
    build() {
      const peers = addr({ name: "wg_peers", addrType: "ipv4", comment: "wireguard peer addresses" }, ["10.10.0.0/24"]);
      return {
        version: 1,
        flushRuleset: true,
        addressGroups: [peers],
        portGroups: [],
        tables: [
          table(
            { name: "filter", family: "inet", comment: "wireguard gateway filter" },
            [
              chain(
                { name: "input", type: "filter", hook: "input", priority: "filter", policy: "drop" },
                [
                  rule({ comment: "loopback", iifname: "lo", verdict: "accept" }),
                  rule({ comment: "established", ctState: ["established", "related"], verdict: "accept" }),
                  rule({
                    comment: "wireguard listen",
                    l4proto: "udp",
                    dportMode: "value",
                    dportValue: "51820",
                    counter: true,
                    verdict: "accept",
                  }),
                ]
              ),
              chain(
                { name: "forward", type: "filter", hook: "forward", priority: "filter", policy: "drop" },
                [
                  rule({ comment: "established forward", ctState: ["established", "related"], verdict: "accept" }),
                  rule({
                    comment: "wireguard peers to wan",
                    iifname: "wg0",
                    oifname: "eth0",
                    saddrMode: "group",
                    saddrGroupId: peers.id,
                    counter: true,
                    verdict: "accept",
                  }),
                ]
              ),
            ]
          ),
          table(
            { name: "nat", family: "ip", comment: "wireguard source nat" },
            [
              chain(
                { name: "postrouting", type: "nat", hook: "postrouting", priority: "srcnat", policy: "accept" },
                [
                  rule({
                    comment: "masquerade wireguard peers",
                    oifname: "eth0",
                    saddrMode: "group",
                    saddrGroupId: peers.id,
                    verdict: "masquerade",
                  }),
                ]
              ),
            ]
          ),
        ],
      };
    },
  },
];

export function getPreset(id) {
  return PRESETS.find((p) => p.id === id) || null;
}
