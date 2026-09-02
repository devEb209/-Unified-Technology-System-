#!/usr/bin/env node
"use strict";

/**
 * Agente nativo KÄIRŌS — rode no COMPUTADOR que você quer controlar.
 *   node agent/kairos-agent.js [ws://HUB:4173/ws]
 *
 * Injeta teclado/mouse via xdotool (Linux), osascript (macOS) ou PowerShell (Windows).
 * Sem o agente, a TV/PC ainda pode receber jogos e teclado se abrir /receiver no navegador.
 */

const os = require("os");
const { spawn, execFile } = require("child_process");
const { WebSocket } = require("ws");

const HUB = process.argv[2] || process.env.KAIROS_HUB || "ws://127.0.0.1:4173/ws";
const NAME = process.env.KAIROS_NAME || os.hostname();

function run(cmd, args, stdin) {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, { stdio: ["pipe", "pipe", "pipe"] });
    let out = "";
    let err = "";
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (err += d));
    if (stdin) child.stdin.end(stdin);
    else child.stdin.end();
    child.on("close", (code) => resolve({ code, out, err }));
    child.on("error", (e) => resolve({ code: -1, out, err: e.message }));
  });
}

const XDOTOOL_KEYS = {
  Enter: "Return",
  Backspace: "BackSpace",
  Escape: "Escape",
  Tab: "Tab",
  ArrowUp: "Up",
  ArrowDown: "Down",
  ArrowLeft: "Left",
  ArrowRight: "Right",
  " ": "space",
  Space: "space",
  Control: "ctrl",
  Alt: "alt",
  Shift: "shift",
  Meta: "super",
  Delete: "Delete",
  Home: "Home",
  End: "End",
  PageUp: "Page_Up",
  PageDown: "Page_Down",
};

async function injectKey(data) {
  const key = data.key || data.text;
  if (!key) return { ok: false };
  if (process.platform === "linux") {
    if (data.text && data.text.length > 1) {
      return run("xdotool", ["type", "--", data.text]);
    }
    const k = XDOTOOL_KEYS[key] || key;
    const mods = [];
    if (data.ctrl) mods.push("ctrl");
    if (data.alt) mods.push("alt");
    if (data.shift) mods.push("shift");
    const combo = mods.length ? `${mods.join("+")}+${k}` : k;
    if (data.type === "up") return run("xdotool", ["keyup", combo]);
    if (data.type === "down") return run("xdotool", ["keydown", combo]);
    return run("xdotool", ["key", combo]);
  }
  if (process.platform === "win32") {
    const map = { Enter: "{ENTER}", Backspace: "{BACKSPACE}", Escape: "{ESC}", Tab: "{TAB}", ArrowUp: "{UP}", ArrowDown: "{DOWN}", ArrowLeft: "{LEFT}", ArrowRight: "{RIGHT}" };
    const send = map[key] || (data.text || key);
    const ps = `Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('${String(send).replace(/'/g, "''")}')`;
    return run("powershell", ["-NoProfile", "-Command", ps]);
  }
  if (process.platform === "darwin") {
    const map = { Enter: "return", Backspace: "delete", Escape: "escape", Tab: "tab", ArrowUp: "up arrow", ArrowDown: "down arrow", ArrowLeft: "left arrow", ArrowRight: "right arrow" };
    const k = map[key] || key.toLowerCase();
    return run("osascript", ["-e", `tell application "System Events" to keystroke "${k}"`]);
  }
  return { ok: false, err: "plataforma sem injeção" };
}

async function injectMouse(data) {
  if (process.platform === "linux") {
    if (data.dx || data.dy) await run("xdotool", ["mousemove_relative", "--", String(data.dx || 0), String(data.dy || 0)]);
    if (data.x != null && data.y != null) await run("xdotool", ["mousemove", String(data.x), String(data.y)]);
    if (data.button && data.kind === "down") await run("xdotool", ["mousedown", String(data.button)]);
    if (data.button && data.kind === "up") await run("xdotool", ["mouseup", String(data.button)]);
    if (data.button && data.kind === "click") await run("xdotool", ["click", String(data.button)]);
    if (data.wheel) await run("xdotool", ["click", data.wheel > 0 ? "4" : "5"]);
    return { ok: true };
  }
  return { ok: false, err: "mouse nativo só no Linux (xdotool) nesta versão" };
}

async function processes() {
  if (process.platform === "win32") {
    const r = await run("tasklist", ["/FO", "CSV", "/NH"]);
    return r.out
      .split(/\r?\n/)
      .filter(Boolean)
      .slice(0, 40)
      .map((line) => {
        const cols = line.split('","').map((s) => s.replace(/"/g, ""));
        return { name: cols[0], pid: cols[1], mem: cols[4] };
      });
  }
  const r = await run("ps", ["-eo", "pid,pcpu,pmem,comm", "--sort=-pcpu"]);
  return r.out
    .trim()
    .split(/\n/)
    .slice(1, 41)
    .map((line) => {
      const p = line.trim().split(/\s+/);
      return { pid: p[0], cpu: p[1], mem: p[2], name: p.slice(3).join(" ") };
    });
}

function connect() {
  const ws = new WebSocket(HUB);
  ws.on("open", () => {
    ws.send(
      JSON.stringify({
        type: "hello",
        role: "agent",
        name: `PC · ${NAME}`,
        type: "computer",
        hostname: os.hostname(),
        os: `${os.platform()} ${os.release()}`,
        capabilities: ["keyboard", "gamepad", "touchpad", "processes", "power", "screenshot"],
      })
    );
    console.log("KÄIRŌS Agent ligado em", HUB);
  });
  ws.on("message", async (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return;
    }
    if (msg.type === "welcome") {
      console.log("Emparelhe no celular com o código:", msg.pairCode);
      return;
    }
    if (msg.type === "input") {
      if (msg.action === "keyboard" || msg.action === "text") await injectKey(msg.data || {});
      if (msg.action === "mouse") await injectMouse(msg.data || {});
      if (msg.action === "gamepad") {
        const g = msg.data || {};
        if (g.hat === "up") await injectKey({ key: "ArrowUp" });
        if (g.hat === "down") await injectKey({ key: "ArrowDown" });
        if (g.hat === "left") await injectKey({ key: "ArrowLeft" });
        if (g.hat === "right") await injectKey({ key: "ArrowRight" });
        if (g.btn === "a") await injectKey({ key: "Enter" });
        if (g.btn === "b") await injectKey({ key: "Escape" });
      }
    }
    if (msg.type === "command") {
      if (msg.action === "processes") {
        const list = await processes();
        ws.send(JSON.stringify({ type: "agent-result", action: "processes", ok: true, data: list, taskId: msg.taskId }));
      }
      if (msg.action === "power") {
        ws.send(JSON.stringify({ type: "agent-result", action: "power", ok: true, detail: "pedido recebido — confirme no SO", taskId: msg.taskId }));
      }
    }
  });
  ws.on("close", () => setTimeout(connect, 2000));
  ws.on("error", (e) => console.error("agent ws", e.message));
}

connect();
