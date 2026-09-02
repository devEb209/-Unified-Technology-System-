import { GAMES, createGame } from "./games.js";

const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];

const state = {
  id: localStorage.getItem("kairos.id") || "",
  pin: "",
  unlocked: false,
  ws: null,
  devices: [],
  tasks: [],
  census: { last: 0, next: 0, scanning: false, found: 0 },
  selected: null,
  view: "devices",
  connected: false,
  hub: null,
  targetId: localStorage.getItem("kairos.target") || "",
  processes: [],
  game: null,
  gameId: null,
  castTimer: 0,
  input: {
    left: { x: 0, y: 0 },
    right: { x: 0, y: 0 },
    buttons: {},
  },
};

const ICONS = {
  tv: `<svg viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="12" rx="2"/><path d="M8 21h8M12 17v4"/></svg>`,
  computer: `<svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/></svg>`,
  phone: `<svg viewBox="0 0 24 24"><rect x="7" y="2" width="10" height="20" rx="2"/><path d="M11 18h2"/></svg>`,
  printer: `<svg viewBox="0 0 24 24"><rect x="6" y="3" width="12" height="6"/><rect x="4" y="9" width="16" height="8" rx="1"/><rect x="7" y="13" width="10" height="8"/></svg>`,
  media: `<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M10 8l6 4-6 4z"/></svg>`,
  iot: `<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="2"/><path d="M12 5v2M12 17v2M5 12h2M17 12h2M7 7l1.5 1.5M15.5 15.5L17 17M17 7l-1.5 1.5M7 17l1.5-1.5"/></svg>`,
  network: `<svg viewBox="0 0 24 24"><circle cx="6" cy="12" r="2"/><circle cx="18" cy="6" r="2"/><circle cx="18" cy="18" r="2"/><path d="M8 12h8M16.5 7.5l-8 3.5M16.5 16.5l-8-3.5"/></svg>`,
};

function toast(msg) {
  const el = $("#toast");
  el.textContent = msg;
  el.classList.add("show");
  setTimeout(() => el.classList.remove("show"), 2400);
}

function wsUrl() {
  const proto = location.protocol === "https:" ? "wss:" : "ws:";
  return `${proto}//${location.host}/ws`;
}

function connect() {
  const ws = new WebSocket(wsUrl());
  state.ws = ws;
  ws.onopen = () => {
    state.connected = true;
    ws.send(
      JSON.stringify({
        type: "hello",
        role: "commander",
        id: state.id || undefined,
        name: "Celular · Comandante KÄIRŌS",
        type: "phone",
        capabilities: ["keyboard", "gamepad", "cast-source", "touchpad"],
      })
    );
    renderStatus();
  };
  ws.onclose = () => {
    state.connected = false;
    renderStatus();
    setTimeout(connect, 1500);
  };
  ws.onerror = () => {};
  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    onMsg(msg);
  };
}

function send(msg) {
  if (state.ws && state.ws.readyState === 1) state.ws.send(JSON.stringify(msg));
}

function onMsg(msg) {
  if (msg.type === "welcome") {
    state.id = msg.id;
    localStorage.setItem("kairos.id", msg.id);
    applySnapshot(msg.snapshot);
  }
  if (msg.type === "snapshot") applySnapshot(msg);
  if (msg.type === "census") {
    state.census = msg.census;
    renderCensus();
  }
  if (msg.type === "scan-progress") {
    $("#scanBar").style.width = msg.progress.total ? `${(msg.progress.scanned / msg.progress.total) * 100}%` : "10%";
  }
  if (msg.type === "device") {
    const i = state.devices.findIndex((d) => d.id === msg.device.id);
    if (i >= 0) state.devices[i] = msg.device;
    else state.devices.push(msg.device);
    renderDevices();
    if (state.selected === msg.device.id) renderDevice();
  }
  if (msg.type === "task") {
    const i = state.tasks.findIndex((t) => t.id === msg.task.id);
    if (i >= 0) state.tasks[i] = msg.task;
    else state.tasks.unshift(msg.task);
    renderTasks();
  }
  if (msg.type === "pair-result") {
    if (msg.ok) {
      toast("Dispositivo emparelhado");
      state.targetId = msg.device.id;
      localStorage.setItem("kairos.target", state.targetId);
      showView("device");
      state.selected = msg.device.id;
      renderDevice();
    } else toast(msg.error || "Falha no emparelhamento");
  }
  if (msg.type === "agent-result") {
    if (msg.action === "processes" && msg.data) {
      state.processes = msg.data;
      renderProcesses();
    }
  }
  if (msg.type === "command-result" && msg.error) toast(msg.error);
}

function applySnapshot(snap) {
  if (!snap) return;
  state.devices = snap.devices || [];
  state.tasks = snap.tasks || [];
  state.census = snap.census || state.census;
  state.hub = snap.hub;
  renderAll();
}

function renderStatus() {
  $("#connDot").className = "dot " + (state.connected ? "live" : "off");
  $("#connLbl").textContent = state.connected ? "HUB ONLINE" : "RECONECTANDO";
}

function fmtRemain(ms) {
  if (ms < 0) ms = 0;
  const s = Math.floor(ms / 1000);
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${String(m).padStart(2, "0")}:${String(r).padStart(2, "0")}`;
}

function renderCensus() {
  const c = state.census;
  const remain = (c.next || 0) - Date.now();
  $("#censusClock").textContent = c.scanning ? "SCAN" : fmtRemain(remain);
  const last = c.last ? new Date(c.last).toLocaleTimeString() : "—";
  $("#censusMeta").innerHTML = c.scanning
    ? "Varrendo a rede local em busca de TVs, PCs, impressoras e mídia…"
    : `Último censo ${last} · ${c.found || 0} host(s) · próximo em 7 min`;
  const total = CENSUS_MS;
  const used = total - Math.max(0, remain);
  $("#scanBar").style.width = c.scanning ? "35%" : `${Math.min(100, (used / total) * 100)}%`;
}
const CENSUS_MS = 7 * 60 * 1000;

function typeLabel(t) {
  return (
    {
      tv: "Televisor",
      computer: "Computador",
      phone: "Celular",
      printer: "Impressora",
      media: "Mídia",
      iot: "IoT",
      network: "Rede",
    }[t] || t
  );
}

function renderDevices() {
  const list = $("#deviceList");
  const online = state.devices.filter((d) => d.status === "online");
  const offline = state.devices.filter((d) => d.status !== "online");
  $("#devCount").textContent = `${online.length} ONLINE`;
  if (!state.devices.length) {
    list.innerHTML = `<div class="empty">Nenhum aparelho ainda. Abra <b>/receiver</b> na TV ou no PC, ou rode o agente no computador. O censo a cada 7 minutos também lista hosts da sua rede.</div>`;
    return;
  }
  list.innerHTML = [...online, ...offline]
    .map(
      (d) => `
      <button class="device-card" data-id="${d.id}">
        <div class="glyph">${ICONS[d.type] || ICONS.network}</div>
        <div>
          <h3>${d.id === state.id ? "Este celular" : esc(d.name)}</h3>
          <small>${typeLabel(d.type)} · ${d.ip || d.hostname || d.source}${d.controllable ? " · controlável" : ""}${d.id === state.id ? " · comandante" : ""}</small>
        </div>
        <span class="badge ${d.status === "online" ? "on" : "off"}">${d.status === "online" ? "LINK" : "OFF"}</span>
      </button>`
    )
    .join("");
  $$("#deviceList .device-card").forEach((el) =>
    el.addEventListener("click", () => {
      state.selected = el.dataset.id;
      showView("device");
      renderDevice();
    })
  );
}

function selectedDevice() {
  return state.devices.find((d) => d.id === state.selected);
}

function renderDevice() {
  const d = selectedDevice();
  const root = $("#deviceView");
  if (!d) {
    root.innerHTML = `<div class="empty">Selecione um dispositivo.</div>`;
    return;
  }
  const caps = (d.capabilities || []).join(" · ") || "status";
  root.innerHTML = `
    <button class="btn" id="backDev">← Dispositivos</button>
    <div class="hero-device">
      <p class="tag">${typeLabel(d.type)}</p>
      <h2>${esc(d.name)}</h2>
      <div class="kv">
        <div>Estado<b>${d.status} / ${d.power || "on"}</b></div>
        <div>Endereço<b>${esc(d.ip || "sessão local")}</b></div>
        <div>Origem<b>${esc(d.source)}</b></div>
        <div>Volume<b id="volLbl">${d.volume ?? 50}%</b></div>
      </div>
      <p style="margin-top:10px;color:var(--mute);font-size:12px">${esc(caps)}</p>
    </div>
    <div class="actions">
      <button class="btn primary" data-act="set-target">Usar como alvo</button>
      <button class="btn" data-act="keyboard">Teclado</button>
      <button class="btn" data-act="gamepad">Gamepad</button>
      <button class="btn" data-act="touchpad">Touchpad</button>
      <button class="btn" data-act="remote">Controle TV</button>
      <button class="btn" data-act="processes">Processos</button>
      <button class="btn" data-act="power-off">Standby / Off</button>
      <button class="btn" data-act="power-on">Ligar</button>
    </div>
    <div class="field">
      <label>VOLUME</label>
      <input type="range" min="0" max="100" value="${d.volume ?? 50}" id="vol" class="slider"/>
    </div>
    <div class="field">
      <label>RENOMEAR NESTE HUB</label>
      <input id="rename" value="${esc(d.name)}"/>
    </div>
    <button class="btn" id="saveName">Salvar nome</button>
    <div id="procBox" style="margin-top:16px"></div>
    ${
      !d.controllable
        ? `<p class="hint" style="margin-top:14px">Este host foi visto na rede, mas ainda não tem o Receptor/Agente KÄIRŌS. Abra <code>http://[este-hub]:4173/receiver</code> no aparelho e emparelhe com o código.</p>`
        : ""
    }
  `;
  $("#backDev").onclick = () => showView("devices");
  $("#vol").oninput = (e) => {
    $("#volLbl").textContent = e.target.value + "%";
    send({ type: "command", deviceId: d.id, action: "volume", data: { volume: Number(e.target.value) } });
  };
  $("#saveName").onclick = () => {
    send({ type: "command", deviceId: d.id, action: "rename", data: { name: $("#rename").value } });
    toast("Nome atualizado");
  };
  $$("#deviceView [data-act]").forEach((b) => (b.onclick = () => act(b.dataset.act, d)));
}

function act(kind, d) {
  if (kind === "set-target") {
    state.targetId = d.id;
    localStorage.setItem("kairos.target", d.id);
    send({ type: "control", deviceId: d.id });
    toast("Alvo de controle: " + d.name);
  }
  if (kind === "keyboard") openOverlay("keyboard");
  if (kind === "gamepad") openOverlay("gamepad");
  if (kind === "touchpad") openOverlay("touchpad");
  if (kind === "remote") openOverlay("remote");
  if (kind === "processes") {
    send({ type: "command", deviceId: d.id, action: "processes", data: {} });
    toast("Pedindo lista ao agente…");
  }
  if (kind === "power-off") {
    if (confirm("Enviar desligar/standby para " + d.name + "?"))
      send({ type: "command", deviceId: d.id, action: "power", data: { mode: "off" } });
  }
  if (kind === "power-on") send({ type: "command", deviceId: d.id, action: "power", data: { mode: "on" } });
}

function renderProcesses() {
  const box = $("#procBox");
  if (!box) return;
  if (!state.processes.length) return;
  box.innerHTML = `<div class="section-title">PROCESSOS</div>` +
    state.processes
      .slice(0, 24)
      .map((p) => `<div class="task"><div class="row"><b>${esc(p.name || "")}</b><span>${esc(p.pid || "")} · CPU ${esc(p.cpu || p.mem || "")}</span></div></div>`)
      .join("");
}

function renderTasks() {
  const el = $("#taskList");
  if (!state.tasks.length) {
    el.innerHTML = `<div class="empty">Nenhuma tarefa ainda. O censo da rede, emparelhamentos e comandos aparecem aqui.</div>`;
    return;
  }
  el.innerHTML = [...state.tasks]
    .sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0))
    .map((t) => {
      const st = t.status === "done" ? "on" : t.status === "error" ? "off" : "";
      return `<article class="task">
        <div class="row"><b>${esc(t.title)}</b><span class="badge ${st}">${esc(t.status)}</span></div>
        <div style="color:var(--mute);font-size:12px;margin-top:4px">${esc(t.detail || t.kind || "")}</div>
        <time>${t.createdAt ? new Date(t.createdAt).toLocaleTimeString() : ""}</time>
      </article>`;
    })
    .join("");
}

function renderGames() {
  $("#gameList").innerHTML = GAMES.map(
    (g) => `<button class="game-card" data-game="${g.id}">
      <div><h3>${g.name}</h3><small>${g.blurb}</small></div>
      <span class="badge on">PLAY</span>
    </button>`
  ).join("");
  $$("#gameList [data-game]").forEach((b) => (b.onclick = () => startGame(b.dataset.game)));
  const sel = $("#castTarget");
  const casts = state.devices.filter((d) => d.status === "online" && (d.display || d.controllable || d.type === "tv" || d.type === "computer"));
  sel.innerHTML = `<option value="">Só neste celular</option>` + casts.map((d) => `<option value="${d.id}" ${d.id === state.targetId ? "selected" : ""}>${esc(d.name)}</option>`).join("");
}

function renderSettings() {
  const url = location.origin;
  $("#setHub").textContent = url;
  $("#setIfaces").innerHTML = (state.hub?.ifaces || [])
    .map((i) => `<div class="task">${esc(i.ip)} · máscara ${esc(i.netmask)}</div>`)
    .join("") || `<div class="empty">Sem IPv4 de LAN detectado neste hub.</div>`;
  $("#recvUrl").textContent = url + "/receiver";
}

function renderAll() {
  renderStatus();
  renderCensus();
  renderDevices();
  renderTasks();
  renderGames();
  renderSettings();
  if (state.view === "device") renderDevice();
}

function showView(name) {
  state.view = name;
  $$(".view").forEach((v) => v.classList.toggle("active", v.dataset.view === name));
  $$(".nav button").forEach((b) => b.classList.toggle("active", b.dataset.view === name));
  if (name === "device") renderDevice();
  if (name === "games") renderGames();
  if (name === "tasks") renderTasks();
  if (name === "settings") renderSettings();
}

function esc(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/"/g, "&quot;");
}

/* PIN */
function pinStorage() {
  return localStorage.getItem("kairos.pin") || "";
}
async function hashPin(p) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode("kairos:" + p));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function setupLock() {
  let buf = "";
  const renderDots = () => {
    $$(".pin-dot").forEach((d, i) => d.classList.toggle("on", i < buf.length));
  };
  $$(".pad [data-k]").forEach((b) => {
    b.onclick = async () => {
      const k = b.dataset.k;
      if (k === "ok") {
        if (buf.length < 4) return;
        const h = await hashPin(buf);
        const saved = pinStorage();
        if (!saved) {
          localStorage.setItem("kairos.pin", h);
          unlock();
          toast("PIN criado");
        } else if (h === saved) unlock();
        else {
          toast("PIN incorreto");
          buf = "";
          renderDots();
        }
        return;
      }
      if (k === "del") buf = buf.slice(0, -1);
      else if (buf.length < 6) buf += k;
      renderDots();
    };
  });
}

function unlock() {
  state.unlocked = true;
  sessionStorage.setItem("kairos.unlocked", "1");
  $("#lock").classList.add("hidden");
  $("#splash").classList.add("hidden");
  $("#app").style.visibility = "visible";
}

/* OVERLAYS */
function openOverlay(name) {
  $$(".overlay").forEach((o) => o.classList.toggle("show", o.id === "ov-" + name));
  if (name === "keyboard") $("#kbHint").textContent = targetName();
  if (name === "gamepad") $("#gpHint").textContent = targetName();
}
function closeOverlays() {
  $$(".overlay").forEach((o) => o.classList.remove("show"));
}
function targetId() {
  return state.targetId || state.selected || "";
}
function targetName() {
  const d = state.devices.find((x) => x.id === targetId());
  return d ? d.name : "Nenhum alvo — escolha um dispositivo";
}

function sendInput(action, data) {
  const id = targetId();
  if (!id) return;
  send({ type: "input", deviceId: id, action, data });
}

/* KEYBOARD */
const ROWS = [
  ["Esc", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "Backspace"],
  ["Tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "´"],
  ["Caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", "Ç", "Enter"],
  ["Shift", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "-", "Shift"],
  ["Ctrl", "Alt", "Space", "←", "↑", "↓", "→"],
];
let shift = false;
function buildKeyboard() {
  const root = $("#keyboard");
  root.innerHTML = "";
  for (const row of ROWS) {
    const r = document.createElement("div");
    r.className = "krow";
    for (const k of row) {
      const b = document.createElement("button");
      b.className = "key";
      b.textContent = k === "Space" ? "" : k;
      if (["Backspace", "Enter", "Shift", "Caps", "Tab", "Ctrl", "Alt"].includes(k)) b.classList.add("wide", "fn");
      if (k === "Space") b.classList.add("space");
      b.onpointerdown = (e) => {
        e.preventDefault();
        handleKey(k, "down");
        b.classList.add("down");
      };
      b.onpointerup = () => {
        handleKey(k, "up");
        b.classList.remove("down");
      };
      r.appendChild(b);
    }
    root.appendChild(r);
  }
}
function handleKey(k, phase) {
  if (k === "Shift" && phase === "down") shift = !shift;
  const map = { "←": "ArrowLeft", "→": "ArrowRight", "↑": "ArrowUp", "↓": "ArrowDown", Space: " " };
  const key = map[k] || k;
  sendInput("keyboard", { key, type: phase, shift, text: k.length === 1 ? (shift ? k : k.toLowerCase()) : undefined });
}

/* GAMEPAD */
function setupStick(el, side) {
  const nub = el.querySelector(".nub");
  let pid = null;
  function set(x, y) {
    const nx = Math.max(-1, Math.min(1, x));
    const ny = Math.max(-1, Math.min(1, y));
    state.input[side] = { x: nx, y: ny };
    nub.style.left = `${29 + nx * 28}%`;
    nub.style.top = `${29 + ny * 28}%`;
    sendInput("gamepad", { stick: side, x: nx, y: ny });
  }
  function pos(e) {
    const r = el.getBoundingClientRect();
    const dx = (e.clientX - (r.left + r.width / 2)) / (r.width / 2);
    const dy = (e.clientY - (r.top + r.height / 2)) / (r.height / 2);
    const m = Math.hypot(dx, dy) || 1;
    const c = Math.min(1, m);
    set((dx / m) * c, (dy / m) * c);
  }
  el.addEventListener("pointerdown", (e) => {
    pid = e.pointerId;
    el.setPointerCapture(pid);
    pos(e);
  });
  el.addEventListener("pointermove", (e) => {
    if (pid === e.pointerId) pos(e);
  });
  el.addEventListener("pointerup", () => {
    pid = null;
    set(0, 0);
  });
}

function setupGamepadButtons() {
  $$("[data-gp]").forEach((b) => {
    const sendB = (down) => {
      const v = b.dataset.gp;
      state.input.buttons[v] = down;
      sendInput("gamepad", { btn: v, down, hat: ["up", "down", "left", "right"].includes(v) ? v : undefined });
    };
    b.onpointerdown = (e) => {
      e.preventDefault();
      sendB(true);
    };
    b.onpointerup = () => sendB(false);
  });
}

function setupTouchpad() {
  const pad = $("#touchpad");
  let last = null;
  pad.addEventListener("pointerdown", (e) => {
    last = { x: e.clientX, y: e.clientY };
    pad.setPointerCapture(e.pointerId);
  });
  pad.addEventListener("pointermove", (e) => {
    if (!last) return;
    const dx = e.clientX - last.x;
    const dy = e.clientY - last.y;
    last = { x: e.clientX, y: e.clientY };
    sendInput("mouse", { dx, dy, kind: "move" });
  });
  pad.addEventListener("pointerup", () => (last = null));
  $$("[data-mouse]").forEach((b) => {
    b.onclick = () => sendInput("mouse", { button: Number(b.dataset.mouse), kind: "click" });
  });
}

function setupRemote() {
  $$("[data-remote]").forEach((b) => {
    b.onclick = () => sendInput("remote", { key: b.dataset.remote });
  });
}

/* GAMES + CAST */
function startGame(id) {
  const canvas = $("#gameCanvas");
  if (state.game) state.game.stop();
  state.gameId = id;
  state.game = createGame(id, canvas, state.input);
  $("#gameLayer").classList.add("show");
  state.game.start();
  const target = $("#castTarget").value;
  if (target) {
    state.targetId = target;
    startCast(target, canvas);
    toast("Projetando no dispositivo alvo");
  }
}
function stopGame() {
  stopCast();
  if (state.game) state.game.stop();
  state.game = null;
  $("#gameLayer").classList.remove("show");
}
function startCast(deviceId, canvas) {
  stopCast();
  state.castTimer = setInterval(() => {
    try {
      const data = canvas.toDataURL("image/jpeg", 0.55);
      send({ type: "cast-frame", deviceId, data });
    } catch {
      /* ignore */
    }
  }, 120);
}
function stopCast() {
  if (state.castTimer) clearInterval(state.castTimer);
  state.castTimer = 0;
}

function setupNav() {
  $$(".nav button").forEach((b) => {
    b.onclick = () => showView(b.dataset.view);
  });
  $("#btnCensus").onclick = () => send({ type: "census" });
  $("#btnPair").onclick = () => {
    const code = $("#pairCode").value.trim();
    send({ type: "pair", code });
  };
  $("#btnAddOpen").onclick = () => showView("settings");
  const goGames = $("#goGames");
  if (goGames) goGames.onclick = () => showView("games");
}

function splashThenLock() {
  setTimeout(() => {
    $("#splash").classList.add("hidden");
    if (sessionStorage.getItem("kairos.unlocked") === "1") unlock();
  }, 1600);
}

window.addEventListener("load", () => {
  setupLock();
  setupNav();
  buildKeyboard();
  setupStick($("#stickL"), "left");
  setupStick($("#stickR"), "right");
  setupGamepadButtons();
  setupTouchpad();
  setupRemote();
  $$("[data-close]").forEach((b) => (b.onclick = closeOverlays));
  $("#btnExitGame").onclick = stopGame;
  $("#btnRestartGame").onclick = () => state.game && state.game.restart();
  $("#btnKbFromGame").onclick = () => openOverlay("gamepad");
  connect();
  splashThenLock();
  setInterval(renderCensus, 1000);
  if ("serviceWorker" in navigator) navigator.serviceWorker.register("/sw.js").catch(() => {});
});

document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") send({ type: "snapshot" });
});
