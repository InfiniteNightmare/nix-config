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

const literal = (value) => JSON.stringify(value);

process.stdout.write(`function main(config, profileName) {
  const proxyName = ${literal(client.name)};
  const aiGroupName = "AI-US";
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

  config.proxies = Array.isArray(config.proxies) ? config.proxies : [];
  const existingProxyIndex = config.proxies.findIndex(
    (proxy) => proxy && proxy.name === proxyName,
  );
  if (existingProxyIndex === -1) {
    config.proxies.unshift(vpsProxy);
  } else {
    config.proxies[existingProxyIndex] = vpsProxy;
  }

  config["proxy-groups"] = Array.isArray(config["proxy-groups"])
    ? config["proxy-groups"]
    : [];

  // Remove the old script's injection from subscription-wide groups. A dead
  // private node must not take down unrelated traffic.
  for (const group of config["proxy-groups"]) {
    if (
      group &&
      ["宝贝云", "自动选择", "延迟最低"].includes(group.name) &&
      Array.isArray(group.proxies)
    ) {
      group.proxies = group.proxies.filter((name) => name !== proxyName);
    }
  }

  const fallbackProxyGroup = ["宝贝云", "PROXY", "Proxy", "自动选择"].find(
    (name) => config["proxy-groups"].some((group) => group && group.name === name),
  );
  const aiGroupProxies = [
    proxyName,
    ...(fallbackProxyGroup ? [fallbackProxyGroup] : []),
    "DIRECT",
  ];
  const aiGroupConfig = {
    name: aiGroupName,
    type: "fallback",
    url: "https://cp.cloudflare.com/generate_204",
    interval: 300,
    proxies: aiGroupProxies,
  };
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
