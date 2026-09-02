import * as THREE from 'three';

/* ------------------------------------------------------------------
   THEATRE ZERO — ATO I: SILENT MERIDIAN
   Grafo de missão com decisões SIMULTÂNEAS: duas ordens chegam no mesmo
   instante por canais diferentes (comando tático x agência). O jogador tem
   segundos para obedecer uma delas. A escolha reescreve o resto da campanha.
   Sem menus: tudo chega por rádio e é confirmado com F1 / F2.
------------------------------------------------------------------- */

export const CAMPAIGN_STATE = {
  flags: new Set(),
  choices: [],
  civilianCasualties: 0,
  detected: false,
  timeToExfil: null,
  reputation: { natoCommand: 0, agency: 0, localCell: 0 }
};

export class Radio {
  constructor(audio, captionEl) {
    this.audio = audio; this.el = captionEl;
    this.queue = []; this.current = null; this.t = 0;
  }
  say(speaker, text, dur = null) {
    const d = dur ?? Math.max(2.2, text.length * 0.055);
    this.queue.push({ speaker, text, dur: d });
  }
  clear() { this.queue.length = 0; this.current = null; this.el.textContent = ''; this.el.style.opacity = 0; }
  update(dt) {
    if (this.current) {
      this.t -= dt;
      if (this.t <= 0) { this.current = null; this.el.style.opacity = 0; }
      return;
    }
    if (this.queue.length) {
      this.current = this.queue.shift();
      this.t = this.current.dur;
      this.audio.radio(Math.random() * 10 | 0, Math.min(3.4, this.current.dur * 0.8));
      this.el.textContent = `${this.current.speaker}: ${this.current.text}`;
      this.el.style.opacity = 0.82;
    }
  }
}

export class Decision {
  constructor(prompt, a, b, seconds, onResolve) {
    this.prompt = prompt; this.a = a; this.b = b;
    this.time = seconds; this.total = seconds;
    this.onResolve = onResolve; this.done = false;
  }
}

export class Campaign {
  constructor(ctx) {
    this.ctx = ctx;                       // { player, world, squad, audio, radio, spawnEnemy, fx }
    this.state = CAMPAIGN_STATE;
    this.objectives = [];
    this.decision = null;
    this.t = 0;
    this.phase = 'insertion';
    this.log = [];
    this.ended = false;
  }

  flag(f) { this.state.flags.add(f); }
  has(f) { return this.state.flags.has(f); }

  begin() {
    const R = this.ctx.radio;
    R.say('OVERLORD', 'Câmera corporal ativa. Sinal criptografado estável. Você está a mil e duzentos metros da cerca leste da Instalação Meridian.');
    R.say('OVERLORD', 'Terceira Guerra, dia quatrocentos e onze. Este radar coordena os mísseis que caem em Roterdã a cada seis horas. Ele para hoje.');
    R.say('OVERLORD', 'Sem apoio aéreo. Sem extração se você for detectado antes do alvo. Silêncio é a única blindagem que você tem.');
    this.pushObjective('infiltrate', 'Infiltrar o perímetro da Instalação Meridian');
  }

  pushObjective(id, text) {
    this.objectives.push({ id, text, done: false });
    this.ctx.radio.say('OVERLORD', text.toUpperCase());
  }
  complete(id) {
    const o = this.objectives.find(o => o.id === id);
    if (o && !o.done) { o.done = true; this.log.push(id); return true; }
    return false;
  }

  ask(decision) {
    this.decision = decision;
    const R = this.ctx.radio;
    R.say('COMANDO', decision.prompt, 3.0);
    R.say('OPÇÃO F1', decision.a.label, 2.6);
    R.say('OPÇÃO F2', decision.b.label, 2.6);
  }

  resolve(which) {
    if (!this.decision || this.decision.done) return;
    const d = this.decision;
    d.done = true;
    const opt = which === 'a' ? d.a : which === 'b' ? d.b : (d.timeoutOption || d.a);
    this.state.choices.push({ prompt: d.prompt, taken: opt.label, at: this.t });
    this.decision = null;
    opt.effect?.(this);
  }

  update(dt, input) {
    if (this.ended) return;
    this.t += dt;
    const { player, world, squad, radio } = this.ctx;

    if (this.decision) {
      this.decision.time -= dt;
      if (input.hit('F1')) this.resolve('a');
      else if (input.hit('F2')) this.resolve('b');
      else if (this.decision.time <= 0) {
        radio.say('COMANDO', 'Sem resposta. Assumindo iniciativa própria.');
        this.resolve('timeout');
      }
    }

    switch (this.phase) {
      case 'insertion': this._insertion(dt); break;
      case 'perimeter': this._perimeter(dt); break;
      case 'interior': this._interior(dt); break;
      case 'objective': this._objective(dt); break;
      case 'exfil': this._exfil(dt); break;
    }

    // alarme global muda tudo
    if (!this.state.detected && squad.alertLevel >= 1) {
      this.state.detected = true;
      radio.say('OVERLORD', 'Você foi comprometido. Toda a guarnição está de pé. Improvise.');
      this.onDetected();
    }
    void world;
    void player;
  }

  onDetected() {
    // reforços: dois grupos convergem
    const { spawnEnemy } = this.ctx;
    for (let i = 0; i < 6; i++) {
      spawnEnemy(new THREE.Vector3(-58 + i * 4, 0, -70), true);
    }
    for (let i = 0; i < 4; i++) {
      spawnEnemy(new THREE.Vector3(62, 0, -30 + i * 5), true);
    }
  }

  /* ---------------- fases ---------------- */
  _insertion(dt) {
    const p = this.ctx.player.pos;
    if (p.distanceTo(new THREE.Vector3(0, 0, 52)) < 26) {
      this.phase = 'perimeter';
      this.complete('infiltrate');
      const R = this.ctx.radio;
      R.say('OVERLORD', 'Você está no alcance dos holofotes. Duas janelas se abriram ao mesmo tempo — decida agora.');
      this.ask(new Decision(
        'DUAS ORDENS SIMULTÂNEAS — ESCOLHA UMA',
        {
          label: 'F1 — CORTAR ENERGIA NO GERADOR OESTE (silencioso, lento, você fica cego junto com eles)',
          effect: (c) => {
            c.flag('path_blackout');
            c.state.reputation.agency += 1;
            c.pushObjective('generator', 'Sabotar o gerador principal (setor oeste)');
            c.ctx.radio.say('OVERLORD', 'Sem energia, os holofotes morrem e o radar entra em bateria reserva. Você tem visão noturna. Eles não.');
          }
        },
        {
          label: 'F2 — MARCAR O RADAR PARA UM DRONE DE ATAQUE (rápido, barulhento, guarnição inteira acorda)',
          effect: (c) => {
            c.flag('path_drone');
            c.state.reputation.natoCommand += 1;
            c.pushObjective('mark', 'Marcar a antena de radar e sobreviver ao contra-ataque');
            c.ctx.radio.say('OVERLORD', 'MQ-9 a nove minutos. Quando eles ouvirem o motor, você vira alvo prioritário.');
          }
        },
        14
      ));
      this.decision.timeoutOption = this.decision.a;
    }
  }

  _perimeter(dt) {
    const P = this.ctx.player;
    if (this.has('path_blackout') && P._powerCut) {
      if (this.complete('generator')) {
        this.ctx.radio.say('OVERLORD', 'Energia caiu. Ative o intensificador de imagem — tecla N.');
        this.pushObjective('terminal', 'Extrair chaves de mira no terminal SIGINT (prédio de comando)');
        this.phase = 'interior';
        for (const s of this.ctx.squad.members) if (s.alive && Math.random() < 0.6) { s.state = 'investigate'; s.lastKnown = new THREE.Vector3(-18, 0, 6); }
      }
    }
    if (this.has('path_drone') && P.pos.distanceTo(new THREE.Vector3(6, 0, 8)) < 22) {
      if (this.complete('mark')) {
        this.ctx.radio.say('OVERLORD', 'Alvo marcado. Nove minutos. Encontre cobertura sólida — e não fique embaixo daquela antena.');
        this.phase = 'interior';
        this.droneETA = 240;
        this.ctx.squad.alertAll(P.pos.clone(), 1.0);
      }
    }
  }

  _interior(dt) {
    const P = this.ctx.player;
    if (this.droneETA !== undefined) {
      this.droneETA -= dt;
      if (this.droneETA < 0 && !this.has('drone_struck')) {
        this.flag('drone_struck');
        this.strikeRadar();
      }
    }
    if (P._hacked && this.complete('terminal')) {
      this.ctx.radio.say('AGÊNCIA', 'Chaves recebidas. E temos um problema: o computador confirma dois alvos de valor no complexo.');
      this.phase = 'objective';
      this.ask(new Decision(
        'DOIS ALVOS, UMA JANELA — ESCOLHA',
        {
          label: 'F1 — DESTRUIR O RADAR (salva Roterdã hoje, perde a rede de comando inimiga)',
          effect: (c) => {
            c.flag('kill_radar'); c.state.reputation.natoCommand += 2;
            c.pushObjective('radar', 'Destruir o prato do radar (tiro no eixo — 7.62 penetra)');
          }
        },
        {
          label: 'F2 — CAPTURAR O OFICIAL DE ENLACE (perde o radar, abre toda a cadeia de mísseis no Ato II)',
          effect: (c) => {
            c.flag('capture_officer'); c.state.reputation.agency += 2;
            c.pushObjective('officer', 'Localizar e neutralizar o oficial de enlace (quartel norte)');
            c.ctx.spawnOfficer?.();
          }
        },
        18
      ));
      this.decision.timeoutOption = this.decision.a;
    }
  }

  strikeRadar() {
    const { world, audio, radio, player } = this.ctx;
    radio.say('OVERLORD', 'Impacto em cinco... quatro...');
    setTimeout(() => {
      const dish = world.radarDish;
      if (dish) { dish.visible = false; }
      audio.shot(30, { suppressed: false, caliber: '7.62x51' });
      audio.distantWar(); audio.distantWar();
      player.camImpulseVel.add(new THREE.Vector3(2, 4, 2));
      player.suppression = 1;
      this.flag('radar_destroyed');
      radio.say('OVERLORD', 'Radar fora do ar. Roterdã respira. Saia daí.');
      this.phase = 'exfil';
      this.state.timeToExfil = 300;
    }, 5000);
  }

  _objective(dt) {
    const { world, player, radio } = this.ctx;
    if (this.has('kill_radar') && world.radarDish.visible === false && this.complete('radar')) {
      this.phase = 'exfil';
    }
    // radar destruído a bala: verificado pelo main via callback
    if (this.has('kill_radar') && this.radarHits >= 6 && world.radarDish.visible) {
      world.radarDish.visible = false;
      this.flag('radar_destroyed');
      radio.say('OVERLORD', 'Prato inutilizado. Roterdã respira. Ponto de extração: floresta sul, mil metros.');
      this.complete('radar');
      this.phase = 'exfil';
      this.state.timeToExfil = 300;
    }
    if (this.has('capture_officer') && this.has('officer_down') && this.complete('officer')) {
      radio.say('AGÊNCIA', 'Confirmado. Ele tinha a cadeia inteira no bolso. Ato II começa por causa disso.');
      this.phase = 'exfil';
      this.state.timeToExfil = 300;
    }
    void player; void dt;
  }

  _exfil(dt) {
    const { player, radio } = this.ctx;
    if (this.state.timeToExfil !== null) this.state.timeToExfil -= dt;
    if (!this._exfilAnnounced) {
      this._exfilAnnounced = true;
      this.pushObjective('exfil', 'Extração: floresta ao sul, além da linha das árvores');
      radio.say('OVERLORD', 'Corra. Eles vão fechar o portão sul em cinco minutos.');
    }
    if (player.pos.z > 150) this.end('exfil');
    if (this.state.timeToExfil !== null && this.state.timeToExfil < 0 && !this.has('late')) {
      this.flag('late');
      radio.say('OVERLORD', 'Janela fechada. Você está por conta própria até a fronteira.');
    }
  }

  end(reason) {
    if (this.ended) return;
    this.ended = true;
    this.ctx.onEnd?.(reason, this.summary());
  }

  summary() {
    return {
      escolhas: this.state.choices,
      detectado: this.state.detected,
      flags: [...this.state.flags],
      reputacao: this.state.reputation
    };
  }
}
