const $ = (s) => document.querySelector(s);

function wsUrl() {
  const proto = location.protocol === "https:" ? "wss:" : "ws:";
  return `${proto}//${location.host}/ws`;
}

const kind = new URLSearchParams(location.search).get("role") === "agent" ? "computer" : guessType();
function guessType() {
  const ua = navigator.userAgent;
  if (/TV|SmartTV|Tizen|Web0S|BRAVIA|AppleTV/i.test(ua)) return "tv";
  if (/Mobile|Android/i.test(ua) && innerWidth < 800) return "phone";
  return "computer";
}

let id = sessionStorage.getItem("kairos.receiver") || "";
let audioCtx = null;

function beep() {
  try {
    audioCtx = audioCtx || new AudioContext();
    const o = audioCtx.createOscillator();
    const g = audioCtx.createGain();
    o.frequency.value = 440;
    g.gain.value = 0.04;
    o.connect(g);
    g.connect(audioCtx.destination);
    o.start();
    o.stop(audioCtx.currentTime + 0.05);
  } catch {
    /* ignore */
  }
}

function connect() {
  const ws = new WebSocket(wsUrl());
  ws.onopen = () => {
    ws.send(
      JSON.stringify({
        type: "hello",
        role: "receiver",
        id: id || undefined,
        name: `${kind === "tv" ? "TV" : "Tela"} · ${location.hostname}`,
        type: kind === "phone" ? "phone" : kind,
        os: navigator.platform,
      })
    );
    $("#status").textContent = "Aguardando emparelhamento";
  };
  ws.onclose = () => {
    $("#status").textContent = "Hub desconectado — reconectando";
    setTimeout(connect, 1200);
  };
  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.type === "welcome") {
      id = msg.id;
      sessionStorage.setItem("kairos.receiver", id);
      if (msg.pairCode) $("#code").textContent = msg.pairCode;
    }
    if (msg.type === "paired") {
      $("#status").textContent = "Emparelhado com o comandante";
      $("#who").textContent = msg.commander?.name || "";
      beep();
    }
    if (msg.type === "cast-frame" && msg.data) {
      const img = $("#castImg");
      img.style.display = "block";
      img.src = msg.data;
      $("#code").style.display = "none";
    }
    if (msg.type === "input") applyInput(msg);
    if (msg.type === "command") applyCommand(msg);
  };
}

function applyCommand(msg) {
  if (msg.action === "volume") {
    const v = (msg.data?.volume ?? 50) / 100;
    const video = $("#castVideo");
    video.volume = v;
  }
  if (msg.action === "power" && msg.data?.mode === "off") {
    document.body.style.filter = "brightness(0.05)";
  }
  if (msg.action === "power" && msg.data?.mode === "on") {
    document.body.style.filter = "none";
  }
}

function applyInput(msg) {
  const d = msg.data || {};
  if (msg.action === "keyboard") {
    const ev = new KeyboardEvent(d.type === "up" ? "keyup" : "keydown", {
      key: d.key,
      bubbles: true,
      cancelable: true,
    });
    document.dispatchEvent(ev);
    if (d.text && d.type !== "up") document.dispatchEvent(new InputEvent("input", { data: d.text, bubbles: true }));
  }
  if (msg.action === "remote") {
    const map = { up: "ArrowUp", down: "ArrowDown", left: "ArrowLeft", right: "ArrowRight", ok: "Enter", back: "Escape" };
    if (map[d.key]) document.dispatchEvent(new KeyboardEvent("keydown", { key: map[d.key], bubbles: true }));
    if (d.key === "volup") document.body.style.filter = "brightness(1.15)";
    if (d.key === "voldown") document.body.style.filter = "brightness(0.85)";
    if (d.key === "power") applyCommand({ action: "power", data: { mode: "toggle" } });
  }
  if (msg.action === "gamepad") {
    window.__kairosPad = window.__kairosPad || { buttons: {}, axes: [0, 0, 0, 0] };
    const p = window.__kairosPad;
    if (d.stick === "left") {
      p.axes[0] = d.x;
      p.axes[1] = d.y;
    }
    if (d.stick === "right") {
      p.axes[2] = d.x;
      p.axes[3] = d.y;
    }
    if (d.btn) p.buttons[d.btn] = d.down;
  }
}

connect();
document.body.addEventListener("click", () => {
  try {
    audioCtx = audioCtx || new AudioContext();
  } catch {
    /* ignore */
  }
});
