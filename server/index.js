"use strict";

const http = require("http");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const os = require("os");
const { WebSocketServer } = require("ws");
const { scanOnce, localSubnets } = require("./discovery");

const PORT = Number(process.env.PORT || 4173);
const HOST = process.env.HOST || "0.0.0.0";
const CENSUS_MS = 7 * 60 * 1000;
const PUBLIC = path.join(__dirname, "..", "public");
const DATA_DIR = path.join(__dirname, "..", "data");

if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".webp": "image/webp",
  ".ico": "image/x-icon",
  ".webmanifest": "application/manifest+json",
  ".woff2": "font/woff2",
};

/** @type {Map<string, any>} */
const devices = new Map();
/** @type {Map<import('ws'), {id:string, role:string}>} */
const sockets = new Map();
/** @type {Map<string, import('ws')>} */
const byId = new Map();
/** @type {Map<string, {code:string, deviceId:string, expires:number}>} */
const pairCodes = new Map();
/** @type {Map<string, string>} commanderId -> targetId */
const controlLinks = new Map();

let census = {
  last: 0,
  next: 0,
  durationMs: 0,
  scanning: false,
  error: null,
  found: 0,
};
let scanProgress = null;
const tasks = new Map();

function uid(prefix = "dev") {
  return `${prefix}_${crypto.randomBytes(6).toString("hex")}`;
}

function send(ws, msg) {
  if (ws && ws.readyState === 1) ws.send(JSON.stringify(msg));
}

function broadcast(msg, filter) {
  const raw = JSON.stringify(msg);
  for (const [ws, meta] of sockets) {
    if (ws.readyState !== 1) continue;
    if (filter && !filter(meta, ws)) continue;
    ws.send(raw);
  }
}

function publicDevice(d) {
  return {
    id: d.id,
    name: d.name,
    type: d.type,
    ip: d.ip || null,
    hostname: d.hostname || null,
    ports: d.ports || [],
    source: d.source,
    status: d.status,
    capabilities: d.capabilities || [],
    lastSeen: d.lastSeen,
    paired: !!d.paired,
    controllable: !!d.controllable,
    owner: d.owner || null,
    meta: d.meta || {},
    volume: d.volume ?? 50,
    power: d.power ?? "on",
    battery: d.battery ?? null,
    os: d.os || null,
    agent: !!d.agent,
    display: !!d.display,
  };
}

function snapshot() {
  return {
    type: "snapshot",
    serverTime: Date.now(),
    census,
    scanProgress,
    devices: [...devices.values()].map(publicDevice),
    tasks: [...tasks.values()].slice(-80),
    hub: hubInfo(),
  };
}

function hubInfo() {
  const nets = localSubnets();
  return {
    hostname: os.hostname(),
    platform: os.platform(),
    ifaces: nets,
    port: PORT,
  };
}

function upsertLan(list) {
  const seenIps = new Set(list.map((d) => d.ip));
  for (const d of list) {
    const prev = devices.get(d.id) || [...devices.values()].find((x) => x.ip === d.ip && x.source !== "session");
    const id = prev?.id || d.id;
    devices.set(id, {
      ...(prev || {}),
      ...d,
      id,
      status: "online",
      lastSeen: Date.now(),
      controllable: prev?.controllable || false,
      paired: prev?.paired || false,
    });
  }
  for (const [id, d] of devices) {
    if (d.source === "lan-scan" || d.source === "ssdp") {
      if (d.ip && !seenIps.has(d.ip) && !d.agent && !byId.has(id)) {
        d.status = "offline";
        devices.set(id, d);
      }
    }
  }
}

function addTask(partial) {
  const t = {
    id: uid("task"),
    createdAt: Date.now(),
    status: "running",
    ...partial,
  };
  tasks.set(t.id, t);
  broadcast({ type: "task", task: t });
  return t;
}

function finishTask(id, patch) {
  const t = tasks.get(id);
  if (!t) return;
  Object.assign(t, patch, { finishedAt: Date.now() });
  broadcast({ type: "task", task: t });
}

async function runCensus(reason = "schedule") {
  if (census.scanning) return census;
  census.scanning = true;
  census.error = null;
  scanProgress = { scanned: 0, total: 0, found: 0 };
  const task = addTask({
    kind: "census",
    title: "Censo da rede local",
    detail: reason === "manual" ? "Atualização manual" : "Atualização automática a cada 7 minutos",
    status: "running",
  });
  broadcast({ type: "census", census, scanProgress });
  try {
    const result = await scanOnce((p) => {
      scanProgress = p;
      broadcast({ type: "scan-progress", progress: p });
    });
    upsertLan(result.devices);
    census.last = result.at;
    census.next = result.at + CENSUS_MS;
    census.durationMs = result.durationMs;
    census.found = result.devices.length;
    finishTask(task.id, {
      status: "done",
      detail: `${result.devices.length} host(s) com portas abertas · ${result.durationMs} ms`,
    });
  } catch (err) {
    census.error = String(err.message || err);
    finishTask(task.id, { status: "error", detail: census.error });
  } finally {
    census.scanning = false;
    scanProgress = null;
    census.next = Date.now() + CENSUS_MS;
    broadcast(snapshot());
  }
  return census;
}

function pairCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function registerSession(ws, payload) {
  const role = payload.role || "commander";
  const id = payload.id || uid(role);
  const name =
    payload.name ||
    (role === "receiver"
      ? "Tela KÄIRŌS"
      : role === "agent"
        ? "Agente do computador"
        : "Comandante");
  const type =
    payload.type ||
    (role === "receiver" ? "tv" : role === "agent" ? "computer" : "phone");

  const device = {
    id,
    name,
    type,
    role,
    ip: payload.ip || null,
    hostname: payload.hostname || os.hostname(),
    ports: payload.ports || [],
    source: "session",
    status: "online",
    capabilities: payload.capabilities || defaultCaps(role, type),
    lastSeen: Date.now(),
    paired: role !== "commander",
    controllable: role === "receiver" || role === "agent",
    owner: payload.owner || null,
    meta: payload.meta || {},
    volume: 50,
    power: "on",
    battery: payload.battery ?? null,
    os: payload.os || null,
    agent: role === "agent",
    display: role === "receiver" || role === "commander",
    ws,
  };
  devices.set(id, device);
  sockets.set(ws, { id, role });
  byId.set(id, ws);

  let code = null;
  if (role === "receiver" || role === "agent") {
    code = pairCode();
    pairCodes.set(code, { code, deviceId: id, expires: Date.now() + 10 * 60 * 1000 });
  }

  send(ws, {
    type: "welcome",
    id,
    role,
    pairCode: code,
    hub: hubInfo(),
    snapshot: snapshot(),
  });
  broadcast({ type: "device", device: publicDevice(device) });
  return { id, role, code };
}

function defaultCaps(role, type) {
  if (role === "commander") return ["keyboard", "gamepad", "cast-source", "touchpad"];
  if (role === "receiver") return ["display", "keyboard", "gamepad", "touchpad", "cast", "volume", "remote"];
  if (role === "agent")
    return ["keyboard", "gamepad", "touchpad", "processes", "power", "volume", "files", "screenshot", "cast"];
  if (type === "tv") return ["remote", "volume", "power"];
  return ["status"];
}

function relay(fromId, toId, msg) {
  const target = byId.get(toId);
  if (!target) return false;
  send(target, { ...msg, from: fromId });
  return true;
}

function handleCommand(fromId, payload) {
  const { deviceId, action, data } = payload;
  const dev = devices.get(deviceId);
  if (!dev) return { ok: false, error: "Dispositivo não encontrado" };

  const task = addTask({
    kind: "command",
    title: `${action} → ${dev.name}`,
    deviceId,
    status: "running",
  });

  if (action === "rename") {
    dev.name = String(data?.name || dev.name).slice(0, 64);
    devices.set(dev.id, dev);
    finishTask(task.id, { status: "done" });
    broadcast({ type: "device", device: publicDevice(dev) });
    return { ok: true };
  }

  if (action === "volume") {
    dev.volume = Math.max(0, Math.min(100, Number(data?.volume ?? 50)));
    relay(fromId, deviceId, { type: "command", action, data });
    finishTask(task.id, { status: "done" });
    broadcast({ type: "device", device: publicDevice(dev) });
    return { ok: true, volume: dev.volume };
  }

  if (action === "power") {
    const mode = data?.mode || "toggle";
    if (mode === "off") dev.power = "off";
    else if (mode === "on") dev.power = "on";
    else dev.power = dev.power === "on" ? "off" : "on";
    const ok = relay(fromId, deviceId, { type: "command", action, data: { ...data, mode } });
    finishTask(task.id, {
      status: ok || !dev.agent ? "done" : "pending",
      detail: ok ? "Comando entregue ao agente" : "Sem agente — estado local atualizado",
    });
    broadcast({ type: "device", device: publicDevice(dev) });
    return { ok: true, power: dev.power, delivered: ok };
  }

  if (["keyboard", "gamepad", "mouse", "remote", "text", "media"].includes(action)) {
    const ok = relay(fromId, deviceId, { type: "input", action, data });
    finishTask(task.id, {
      status: ok ? "done" : "error",
      detail: ok ? "Input entregue" : "Receptor/agente offline",
    });
    return { ok, delivered: ok };
  }

  if (action === "processes" || action === "screenshot" || action === "files" || action === "shell") {
    const ok = relay(fromId, deviceId, { type: "command", action, data, taskId: task.id });
    if (!ok) {
      finishTask(task.id, { status: "error", detail: "Agente KÄIRŌS não está ligado neste dispositivo" });
      return { ok: false, error: "Requer o Agente KÄIRŌS no computador" };
    }
    return { ok: true, taskId: task.id };
  }

  finishTask(task.id, { status: "error", detail: "Ação desconhecida" });
  return { ok: false, error: "Ação desconhecida" };
}

const server = http.createServer((req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  res.setHeader("Cache-Control", "no-cache");

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);

  if (url.pathname === "/api/health") {
    json(res, 200, { ok: true, name: "KÄIRŌS TASK MANAGER", census });
    return;
  }
  if (url.pathname === "/api/snapshot") {
    json(res, 200, snapshot());
    return;
  }
  if (url.pathname === "/api/census" && req.method === "POST") {
    runCensus("manual");
    json(res, 202, { ok: true, census });
    return;
  }

  let filePath = url.pathname;
  if (filePath === "/") filePath = "/index.html";
  if (filePath === "/receiver") filePath = "/receiver.html";
  if (filePath === "/agent") filePath = "/agent.html";

  const abs = path.normalize(path.join(PUBLIC, filePath));
  if (!abs.startsWith(PUBLIC)) {
    res.writeHead(403);
    res.end("forbidden");
    return;
  }
  fs.readFile(abs, (err, buf) => {
    if (err) {
      res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("Não encontrado");
      return;
    }
    const ext = path.extname(abs).toLowerCase();
    res.writeHead(200, { "Content-Type": MIME[ext] || "application/octet-stream" });
    res.end(buf);
  });
});

function json(res, code, obj) {
  res.writeHead(code, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(obj));
}

const wss = new WebSocketServer({ server, path: "/ws" });

wss.on("connection", (ws) => {
  ws.on("message", (raw, isBinary) => {
    if (isBinary) {
      const meta = sockets.get(ws);
      if (!meta) return;
      const targetId = controlLinks.get(meta.id);
      const target = targetId && byId.get(targetId);
      if (target && target.readyState === 1) target.send(raw, { binary: true });
      return;
    }
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return;
    }
    const meta = sockets.get(ws);

    if (msg.type === "hello") {
      registerSession(ws, msg);
      return;
    }
    if (!meta) {
      send(ws, { type: "error", error: "Envie hello primeiro" });
      return;
    }

    const me = devices.get(meta.id);
    if (me) {
      me.lastSeen = Date.now();
      me.status = "online";
    }

    switch (msg.type) {
      case "census":
        runCensus("manual");
        break;
      case "snapshot":
        send(ws, snapshot());
        break;
      case "pair": {
        const rec = pairCodes.get(String(msg.code || "").trim());
        if (!rec || rec.expires < Date.now()) {
          send(ws, { type: "pair-result", ok: false, error: "Código inválido ou expirado" });
          break;
        }
        const target = devices.get(rec.deviceId);
        if (!target) {
          send(ws, { type: "pair-result", ok: false, error: "Dispositivo saiu do ar" });
          break;
        }
        target.paired = true;
        target.controllable = true;
        target.owner = meta.id;
        controlLinks.set(meta.id, target.id);
        controlLinks.set(target.id, meta.id);
        send(ws, { type: "pair-result", ok: true, device: publicDevice(target) });
        relay(meta.id, target.id, { type: "paired", commander: publicDevice(me) });
        broadcast({ type: "device", device: publicDevice(target) });
        addTask({
          kind: "pair",
          title: `Emparelhado: ${target.name}`,
          status: "done",
          deviceId: target.id,
        });
        break;
      }
      case "control":
        controlLinks.set(meta.id, msg.deviceId);
        send(ws, { type: "control-set", deviceId: msg.deviceId });
        break;
      case "command":
        send(ws, { type: "command-result", ...handleCommand(meta.id, msg), req: msg.req });
        break;
      case "input":
        relay(meta.id, msg.deviceId, { type: "input", action: msg.action, data: msg.data });
        break;
      case "signal":
        relay(meta.id, msg.deviceId, { type: "signal", data: msg.data });
        break;
      case "cast-frame":
        relay(meta.id, msg.deviceId, { type: "cast-frame", data: msg.data, mime: msg.mime || "image/jpeg" });
        break;
      case "agent-result": {
        if (msg.taskId) finishTask(msg.taskId, { status: msg.ok ? "done" : "error", detail: msg.detail, data: msg.data });
        const commander = [...controlLinks.entries()].find(([, t]) => t === meta.id)?.[0];
        if (commander) relay(meta.id, commander, { type: "agent-result", ...msg });
        broadcast({ type: "agent-result", from: meta.id, ok: msg.ok, action: msg.action, data: msg.data });
        break;
      }
      case "rename-self":
        if (me) {
          me.name = String(msg.name || me.name).slice(0, 64);
          broadcast({ type: "device", device: publicDevice(me) });
        }
        break;
      default:
        break;
    }
  });

  ws.on("close", () => {
    const meta = sockets.get(ws);
    sockets.delete(ws);
    if (!meta) return;
    byId.delete(meta.id);
    const d = devices.get(meta.id);
    if (d && d.source === "session") {
      d.status = "offline";
      d.lastSeen = Date.now();
      broadcast({ type: "device", device: publicDevice(d) });
    }
  });
});

setInterval(() => {
  const now = Date.now();
  for (const [code, rec] of pairCodes) {
    if (rec.expires < now) pairCodes.delete(code);
  }
}, 30_000);

server.listen(PORT, HOST, () => {
  console.log(`KÄIRŌS TASK MANAGER hub em http://${HOST}:${PORT}`);
  census.next = Date.now() + 4000;
  setTimeout(() => runCensus("boot"), 1500);
  setInterval(() => runCensus("schedule"), CENSUS_MS);
});
