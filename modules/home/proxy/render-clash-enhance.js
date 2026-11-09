#!/usr/bin/env node

const fs = require("node:fs");

const secretPath = process.argv[2];
if (!secretPath) {
  throw new Error("usage: render-clash-enhance.js CLIENT_JSON");
}

const secretJson =
  secretPath === "-"
    ? fs.readFileSync(0, "utf8")
    : fs.readFileSync(secretPath, "utf8");
const client = JSON.parse(secretJson);
const requiredStrings = [
  "name",
  "server",
  "uuid",
  "publicKey",
  "shortId",
  "serverName",
  "clientFingerprint",
  "flow",
  "network",
];

for (const field of requiredStrings) {
  if (typeof client[field] !== "string" || client[field].length === 0) {
    throw new Error(`invalid or missing client field: ${field}`);
  }
}

if (!Number.isInteger(client.port) || client.port < 1 || client.port > 65535) {
  throw new Error("invalid client port");
}

if (typeof client.udp !== "boolean") {
  throw new Error("invalid client field: udp must be a boolean");
}

if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(client.uuid)) {
  throw new Error("invalid client UUID");
}

if (!/^[A-Za-z0-9_-]{43}$/.test(client.publicKey)) {
  throw new Error("invalid Reality public key");
}

if (!/^[0-9a-f]+$/i.test(client.shortId) || client.shortId.length > 16 || client.shortId.length % 2 !== 0) {
  throw new Error("invalid Reality short ID");
}

if (client.flow !== "xtls-rprx-vision" || client.network !== "tcp") {
  throw new Error("unsupported VLESS flow or network");
}

// Optional WireGuard tunnel on the same server: the UDP transport survives
// evening return-path congestion that freezes every TCP exit.
const wg = client.wg;
if (wg !== undefined) {
  if (typeof wg !== "object" || wg === null || Array.isArray(wg)) {
    throw new Error("invalid client field: wg must be an object");
  }
  for (const field of ["name", "localIp", "privateKey", "serverPublicKey"]) {
    if (typeof wg[field] !== "string" || wg[field].length === 0) {
      throw new Error(`invalid or missing wg field: ${field}`);
    }
  }
  if (!Number.isInteger(wg.port) || wg.port < 1 || wg.port > 65535) {
    throw new Error("invalid wg port");
  }
  for (const keyField of ["privateKey", "serverPublicKey"]) {
    if (!/^[A-Za-z0-9+/]{43}=$/.test(wg[keyField])) {
      throw new Error(`invalid wg ${keyField}`);
    }
  }
  if (wg.mtu !== undefined && (!Number.isInteger(wg.mtu) || wg.mtu < 1200 || wg.mtu > 1500)) {
    throw new Error("invalid wg mtu");
  }
}

const literal = (value) => JSON.stringify(value);

process.stdout.write(`function main(config, profileName) {
  const proxyName = ${literal(client.name)};
  const wgConfig = ${literal(wg || null)};
  const wgName = wgConfig ? wgConfig.name : null;
  const aiGroupName = "AI-US";
  const aiAutoGroupName = "AI-自动";
  const vpsProxy = {
    name: proxyName,
    type: "vless",
    server: ${literal(client.server)},
    port: ${client.port},
    uuid: ${literal(client.uuid)},
    udp: ${client.udp},
    tls: true,
    "skip-cert-verify": false,
    flow: ${literal(client.flow)},
    "client-fingerprint": ${literal(client.clientFingerprint)},
    servername: ${literal(client.serverName)},
    "reality-opts": {
      "public-key": ${literal(client.publicKey)},
      "short-id": ${literal(client.shortId)},
    },
    network: ${literal(client.network)},
  };
  const wgProxy = wgConfig
    ? {
        name: wgConfig.name,
        type: "wireguard",
        server: ${literal(client.server)},
        port: wgConfig.port,
        ip: wgConfig.localIp,
        "private-key": wgConfig.privateKey,
        "public-key": wgConfig.serverPublicKey,
        mtu: wgConfig.mtu,
        "persistent-keepalive": 25,
        udp: true,
      }
    : null;

  config.proxies = Array.isArray(config.proxies) ? config.proxies : [];
  const upsertProxy = (proxy) => {
    const existingIndex = config.proxies.findIndex(
      (candidate) => candidate && candidate.name === proxy.name,
    );
    if (existingIndex === -1) {
      config.proxies.unshift(proxy);
    } else {
      config.proxies[existingIndex] = proxy;
    }
  };
  upsertProxy(vpsProxy);
  if (wgProxy) {
    upsertProxy(wgProxy);
  }

  config["proxy-groups"] = Array.isArray(config["proxy-groups"])
    ? config["proxy-groups"]
    : [];

  // Subscription info nodes pass URL tests but forward no traffic; the private
  // node must not linger in subscription-wide groups either.
  const junkNodePattern = /剩余流量|套餐|到期|过期|官网|重置|无法使用/;
  for (const group of config["proxy-groups"]) {
    if (group && Array.isArray(group.proxies)) {
      group.proxies = group.proxies.filter(
        (name) =>
          name !== proxyName &&
          name !== wgName &&
          !junkNodePattern.test(name),
      );
      // Url-test groups stick to a dead relay until the subscription's own
      // slow re-probe fires; tighten the cadence so outages self-heal.
      if (group.type === "url-test") {
        group.interval = 60;
        group.timeout = 2000;
      }
    }
  }

  // Chain every subscription-wide group so a dead manual pick in the main
  // selector cannot strand the fallback. WG first: the UDP tunnel carries
  // streams through the evening return-path congestion that freezes every
  // TCP exit (2026-11-04 22:14: WG held 500KB @ 235KB/s while VLESS/airport
  // streams froze). Airport and raw VLESS stay as fallbacks for WG outages.
  const fallbackGroups = ["宝贝云", "PROXY", "Proxy", "自动选择"].filter(
    (name) => config["proxy-groups"].some((group) => group && group.name === name),
  );
  const aiAutoConfig = {
    name: aiAutoGroupName,
    type: "fallback",
    // Probe chatgpt.com itself; a generic 204 URL passes even when the path
    // to OpenAI is broken.
    url: "https://chatgpt.com/cdn-cgi/trace",
    "expected-status": "200",
    interval: 30,
    "max-failed-times": 1,
    proxies: [
      ...(wgName ? [wgName] : []),
      ...fallbackGroups,
      proxyName,
      "DIRECT",
    ],
  };
  const aiGroupConfig = {
    name: aiGroupName,
    // Manual override lives here; AI-自动 keeps the fallback chain as the
    // default pick.
    type: "select",
    proxies: [
      aiAutoGroupName,
      ...(wgName ? [wgName] : []),
      ...fallbackGroups,
      proxyName,
      "DIRECT",
    ],
  };
  const aiAutoGroup = config["proxy-groups"].find(
    (group) => group && group.name === aiAutoGroupName,
  );
  if (aiAutoGroup) {
    Object.assign(aiAutoGroup, aiAutoConfig);
  } else {
    config["proxy-groups"].unshift(aiAutoConfig);
  }
  const aiGroup = config["proxy-groups"].find(
    (group) => group && group.name === aiGroupName,
  );
  if (aiGroup) {
    Object.assign(aiGroup, aiGroupConfig);
  } else {
    config["proxy-groups"].unshift(aiGroupConfig);
  }

  config.dns = config.dns || {};
  const existingFallback = Array.isArray(config.dns.fallback)
    ? config.dns.fallback
    : [];
  const dohFallback = [
    "https://1.1.1.1/dns-query",
    "https://dns.google/dns-query",
  ];
  config.dns.fallback = [
    ...dohFallback,
    ...existingFallback.filter((server) => !dohFallback.includes(server)),
  ];

  config.rules = Array.isArray(config.rules) ? config.rules : [];
  const priorityRules = [
    "IP-CIDR,223.5.5.5/32,DIRECT,no-resolve",
    "IP-CIDR,119.29.29.29/32,DIRECT,no-resolve",
    "IP-CIDR,114.114.114.114/32,DIRECT,no-resolve",
    // DoH fallback must ride the AI chain: the subscription pins these IPs to
    // the airport, and a dead airport then starves resolution too.
    "IP-CIDR,1.1.1.1/32," + aiGroupName + ",no-resolve",
    "IP-CIDR,8.8.8.8/32," + aiGroupName + ",no-resolve",
    "DOMAIN-SUFFIX,ipinfo.io," + aiGroupName,
    "DOMAIN-SUFFIX,claude.ai," + aiGroupName,
    "DOMAIN-SUFFIX,anthropic.com," + aiGroupName,
    "DOMAIN-SUFFIX,claudeusercontent.com," + aiGroupName,
    "DOMAIN-SUFFIX,chatgpt.com," + aiGroupName,
    "DOMAIN-SUFFIX,openai.com," + aiGroupName,
    "DOMAIN-SUFFIX,oaistatic.com," + aiGroupName,
    "DOMAIN-SUFFIX,oaiusercontent.com," + aiGroupName,
    "DOMAIN-SUFFIX,intercomcdn.com," + aiGroupName,
    "DOMAIN-SUFFIX,intercom.io," + aiGroupName,
    "DOMAIN-SUFFIX,intercomassets.com," + aiGroupName,
    "DOMAIN-SUFFIX,sentry.io," + aiGroupName,
    "DOMAIN-SUFFIX,segment.io," + aiGroupName,
  ];
  config.rules = [
    ...priorityRules.filter((rule) => !config.rules.includes(rule)),
    ...config.rules,
  ];

  return config;
}
`);
