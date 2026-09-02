"use strict";

const os = require("os");
const net = require("net");
const dgram = require("dgram");
const http = require("http");

const SCAN_PORTS = [
  { port: 8008, hint: "chromecast" },
  { port: 8009, hint: "chromecast" },
  { port: 8443, hint: "chromecast" },
  { port: 8060, hint: "roku" },
  { port: 9080, hint: "smart-tv" },
  { port: 1925, hint: "philips-tv" },
  { port: 1926, hint: "philips-tv" },
  { port: 55000, hint: "samsung-tv" },
  { port: 8001, hint: "samsung-tv" },
  { port: 32400, hint: "plex" },
  { port: 3389, hint: "rdp" },
  { port: 5900, hint: "vnc" },
  { port: 22, hint: "ssh" },
  { port: 445, hint: "smb" },
  { port: 139, hint: "smb" },
  { port: 80, hint: "http" },
  { port: 443, hint: "https" },
  { port: 8080, hint: "http" },
  { port: 9100, hint: "printer" },
  { port: 631, hint: "ipp-printer" },
  { port: 1883, hint: "mqtt" },
  { port: 5353, hint: "mdns" },
  { port: 7676, hint: "kairos-agent" },
  { port: 32469, hint: "dlna" },
  { port: 8200, hint: "minidlna" },
];

const TYPE_FROM_HINT = {
  chromecast: "tv",
  roku: "tv",
  "smart-tv": "tv",
  "philips-tv": "tv",
  "samsung-tv": "tv",
  plex: "media",
  rdp: "computer",
  vnc: "computer",
  ssh: "computer",
  smb: "computer",
  http: "network",
  https: "network",
  printer: "printer",
  "ipp-printer": "printer",
  mqtt: "iot",
  mdns: "network",
  "kairos-agent": "computer",
  dlna: "media",
  minidlna: "media",
};

function localSubnets() {
  const nets = os.networkInterfaces();
  const out = [];
  for (const list of Object.values(nets)) {
    for (const n of list || []) {
      if (n.internal || n.family !== "IPv4") continue;
      const parts = n.address.split(".").map(Number);
      if (parts[0] === 127) continue;
      out.push({
        ip: n.address,
        netmask: n.netmask,
        mac: n.mac,
        prefix: `${parts[0]}.${parts[1]}.${parts[2]}`,
        iface: n.address,
      });
    }
  }
  return out;
}

function probeTcp(host, port, timeout = 220) {
  return new Promise((resolve) => {
    const socket = net.connect({ host, port, family: 4 });
    let done = false;
    const finish = (ok) => {
      if (done) return;
      done = true;
      socket.destroy();
      resolve(ok);
    };
    socket.setTimeout(timeout);
    socket.on("connect", () => finish(true));
    socket.on("timeout", () => finish(false));
    socket.on("error", () => finish(false));
  });
}

function classify(ports) {
  const hints = ports.map((p) => p.hint);
  if (hints.some((h) => /tv|chromecast|roku/.test(h))) return "tv";
  if (hints.some((h) => /rdp|vnc|ssh|smb|kairos/.test(h))) return "computer";
  if (hints.some((h) => /printer|ipp/.test(h))) return "printer";
  if (hints.some((h) => /plex|dlna/.test(h))) return "media";
  if (hints.some((h) => /mqtt/.test(h))) return "iot";
  return "network";
}

function nameFor(ip, type, ports) {
  const hint = ports[0]?.hint || type;
  const last = ip.split(".").pop();
  const labels = {
    tv: "Televisor",
    computer: "Computador",
    printer: "Impressora",
    media: "Servidor de mídia",
    iot: "Dispositivo IoT",
    network: "Host na rede",
  };
  return `${labels[type] || "Dispositivo"} · ${hint} · .${last}`;
}

async function scanSubnet(prefix, selfIp, onProgress) {
  const found = new Map();
  const hosts = [];
  for (let i = 1; i < 255; i++) {
    const ip = `${prefix}.${i}`;
    if (ip === selfIp) continue;
    hosts.push(ip);
  }

  const concurrency = 48;
  let index = 0;
  let scanned = 0;

  async function worker() {
    while (index < hosts.length) {
      const ip = hosts[index++];
      const open = [];
      for (const spec of SCAN_PORTS) {
        // Skip noisy/slow combos on every host: only probe likely ports first
        const ok = await probeTcp(ip, spec.port);
        if (ok) open.push({ port: spec.port, hint: spec.hint });
      }
      scanned++;
      if (onProgress && scanned % 12 === 0) {
        onProgress({ scanned, total: hosts.length, found: found.size });
      }
      if (open.length) {
        const type = classify(open);
        found.set(ip, {
          id: `lan:${ip}`,
          name: nameFor(ip, type, open),
          type,
          ip,
          ports: open,
          source: "lan-scan",
          status: "online",
          capabilities: inferCaps(type, open),
          lastSeen: Date.now(),
        });
      }
    }
  }

  // Fast pass: probe a smaller high-signal port set first, then expand hits
  const FAST = [8008, 8009, 8060, 3389, 5900, 22, 80, 445, 32400, 9100, 8001, 7676];
  const fastSet = new Set(FAST);

  async function fastWorker() {
    while (index < hosts.length) {
      const ip = hosts[index++];
      const open = [];
      await Promise.all(
        SCAN_PORTS.filter((s) => fastSet.has(s.port)).map(async (spec) => {
          if (await probeTcp(ip, spec.port, 160)) open.push({ port: spec.port, hint: spec.hint });
        })
      );
      scanned++;
      if (open.length) {
        // expand
        for (const spec of SCAN_PORTS) {
          if (fastSet.has(spec.port)) continue;
          if (await probeTcp(ip, spec.port, 180)) open.push({ port: spec.port, hint: spec.hint });
        }
        const type = classify(open);
        found.set(ip, {
          id: `lan:${ip}`,
          name: nameFor(ip, type, open),
          type,
          ip,
          ports: open,
          source: "lan-scan",
          status: "online",
          capabilities: inferCaps(type, open),
          lastSeen: Date.now(),
        });
      }
      if (onProgress && scanned % 20 === 0) {
        onProgress({ scanned, total: hosts.length, found: found.size });
      }
    }
  }

  index = 0;
  scanned = 0;
  await Promise.all(Array.from({ length: concurrency }, () => fastWorker()));
  return [...found.values()];
}

function inferCaps(type, ports) {
  const hints = new Set(ports.map((p) => p.hint));
  const caps = ["status"];
  if (type === "tv") caps.push("remote", "volume", "power");
  if (type === "computer") caps.push("keyboard", "gamepad", "touchpad", "cast");
  if (hints.has("rdp") || hints.has("vnc")) caps.push("desktop");
  if (hints.has("plex") || hints.has("dlna")) caps.push("media");
  if (type === "printer") caps.push("print");
  return caps;
}

function ssdpDiscover(ms = 2500) {
  return new Promise((resolve) => {
    const devices = [];
    let socket;
    try {
      socket = dgram.createSocket({ type: "udp4", reuseAddr: true });
    } catch {
      resolve(devices);
      return;
    }

    const query = Buffer.from(
      "M-SEARCH * HTTP/1.1\r\n" +
        "HOST: 239.255.255.250:1900\r\n" +
        'MAN: "ssdp:discover"\r\n' +
        "MX: 2\r\n" +
        "ST: ssdp:all\r\n" +
        "\r\n"
    );

    socket.on("message", (msg, rinfo) => {
      const text = msg.toString("utf8");
      const headers = {};
      for (const line of text.split(/\r?\n/)) {
        const i = line.indexOf(":");
        if (i > 0) headers[line.slice(0, i).trim().toLowerCase()] = line.slice(i + 1).trim();
      }
      const server = (headers.server || "").toLowerCase();
      const st = (headers.st || headers.nt || "").toLowerCase();
      let type = "network";
      if (/tv|dlnadoc|roku|dial|chromecast|google/.test(server + st)) type = "tv";
      else if (/media|renderer|plex/.test(st)) type = "media";
      else if (/printer|ipp/.test(st)) type = "printer";
      else if (/igd|upnp:root/.test(st)) type = "router";
      devices.push({
        id: `ssdp:${rinfo.address}:${headers.usn || headers.location || rinfo.port}`,
        name: headers.server ? `${headers.server.split(" ")[0]} · ${rinfo.address}` : `UPnP · ${rinfo.address}`,
        type: type === "router" ? "network" : type,
        ip: rinfo.address,
        ports: [{ port: 1900, hint: "ssdp" }],
        location: headers.location || null,
        source: "ssdp",
        status: "online",
        capabilities: inferCaps(type === "router" ? "network" : type, [{ hint: type }]),
        lastSeen: Date.now(),
        meta: { st: headers.st || headers.nt, usn: headers.usn },
      });
    });

    socket.on("error", () => {
      try {
        socket.close();
      } catch {
        /* ignore */
      }
      resolve(dedupe(devices));
    });

    socket.bind(0, () => {
      try {
        socket.setBroadcast(true);
        socket.send(query, 1900, "239.255.255.250");
        socket.send(query, 1900, "255.255.255.255");
      } catch {
        /* multicast may be blocked */
      }
    });

    setTimeout(() => {
      try {
        socket.close();
      } catch {
        /* ignore */
      }
      resolve(dedupe(devices));
    }, ms);
  });
}

function dedupe(list) {
  const map = new Map();
  for (const d of list) {
    const key = d.ip + "::" + (d.meta?.usn || d.name);
    if (!map.has(key)) map.set(key, d);
  }
  return [...map.values()];
}

function gatewayGuess(ip) {
  const p = ip.split(".");
  return `${p[0]}.${p[1]}.${p[2]}.1`;
}

async function identifyHttp(ip) {
  return new Promise((resolve) => {
    const req = http.request(
      { host: ip, port: 80, path: "/", method: "HEAD", timeout: 400 },
      (res) => {
        resolve({
          server: res.headers.server || null,
          title: null,
        });
        res.resume();
      }
    );
    req.on("timeout", () => {
      req.destroy();
      resolve(null);
    });
    req.on("error", () => resolve(null));
    req.end();
  });
}

async function scanOnce(onProgress) {
  const ifaces = localSubnets();
  const started = Date.now();
  const ssdp = await ssdpDiscover(2200);
  const lan = [];
  for (const netInfo of ifaces) {
    const hosts = await scanSubnet(netInfo.prefix, netInfo.ip, onProgress);
    lan.push(...hosts);
  }

  const merged = new Map();
  for (const d of [...ssdp, ...lan]) {
    const prev = merged.get(d.ip);
    if (!prev) {
      merged.set(d.ip, d);
    } else {
      const ports = [...(prev.ports || []), ...(d.ports || [])];
      const seen = new Set();
      const uniq = [];
      for (const p of ports) {
        const k = p.port + p.hint;
        if (seen.has(k)) continue;
        seen.add(k);
        uniq.push(p);
      }
      merged.set(d.ip, {
        ...prev,
        ...d,
        name: d.source === "ssdp" ? d.name : prev.name,
        ports: uniq,
        capabilities: Array.from(new Set([...(prev.capabilities || []), ...(d.capabilities || [])])),
        lastSeen: Date.now(),
      });
    }
  }

  return {
    at: Date.now(),
    durationMs: Date.now() - started,
    interfaces: ifaces,
    devices: [...merged.values()],
  };
}

module.exports = {
  localSubnets,
  scanOnce,
  probeTcp,
  classify,
  SCAN_PORTS,
  TYPE_FROM_HINT,
  gatewayGuess,
  identifyHttp,
};
