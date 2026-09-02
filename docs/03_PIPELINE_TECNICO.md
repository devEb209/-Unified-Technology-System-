# THEATRE ZERO — PIPELINE TÉCNICO
### Resposta direta: dá para fazer sem engine de PC? E dá para conectar uma engine mobile aqui?

---

## 1. RESPOSTA CURTA

**Sim, dá para desenvolver sem engine de PC — com três caminhos, cada um com um teto de
realismo diferente.** O que **não** existe é um caminho onde um celular produz sozinho gráficos
nível *Bodycam/Unrecord*: aquilo é Unreal Engine 5 + Lumen + Nanite + Megascans rodando numa
RTX, e cada minuto de vídeo daquilo consome horas de GPU. O que dá para fazer é escolher onde
o poder de processamento mora.

| Caminho | Onde a engine roda | Roda aqui na conversa? | Teto de realismo | Custo |
|---|---|---|---|---|
| **A. Web (Three.js/Babylon)** ← *é o que já está feito neste repo* | Navegador (PC **e** celular) | **Sim, preview ao vivo** | Alto para web: PBR, sombras, pós-processo de sensor, balística real. Não chega a Lumen/Nanite | Zero |
| **B. Godot 4 com Editor Android** | **No próprio celular** (o editor roda em Android) | Não roda aqui, mas eu escrevo todo o projeto neste repo e você abre no celular | Muito bom: Godot 4 tem GI em tempo real (SDFGI), volumetria, SSR, TAA. Exporta APK e build de PC | Zero |
| **C. UE5 em PC na nuvem + Pixel Streaming** | Servidor com GPU (Vagon, Shadow, Paperspace, AWS G5) | Você joga pelo navegador do celular via streaming | **Teto máximo — o realismo do briefing** | ~US$ 20–60/mês |

Combinação recomendada: **A agora (protótipo jogável e sistemas provados) → C depois
(produção final)**, usando o protótipo como *design bible executável*. Todos os números de
balística, IA, percepção e câmera já validados em A migram literalmente para C.

---

## 2. CAMINHO A — WEB (implementado)

- Engine: Three.js r185 + pipeline de pós-processo próprio (`src/render/bodycam.js`).
- Roda em qualquer navegador com WebGL2; em celular também (com escala de resolução).
- **É o único caminho que conecta direto aqui**: `npm run dev` e o preview aparece pra você.
- Limite honesto: sem ray tracing, sem GI dinâmica de qualidade de filme, sem Nanite.
  O realismo vem de **simulação** (balística, IA, corpo, sensor de câmera), não de polígonos.

Para subir o teto visual dentro da web ainda cabe: WebGPU (Three WebGPURenderer), texturas
fotogramétricas comprimidas KTX2/Basis, modelos GLB escaneados, iluminação assada de alta
qualidade + SSGI, e um pipeline de decalques com parallax. Isso ainda roda no navegador.

---

## 3. CAMINHO B — ENGINE NO CELULAR (Godot 4, editor Android)

**O que é:** o Godot 4 publica um APK do **editor completo** para Android. Você edita cena,
código (GDScript/C#), materiais, importa GLB e **exporta o jogo do próprio telefone**.
Funciona bem em tablet ou celular com tela grande + teclado Bluetooth.

**Como conectamos isso aqui neste repositório:**
1. Eu crio e mantenho o projeto Godot no repo (`/godot`): `project.godot`, cenas `.tscn`,
   scripts `.gd`, shaders `.gdshader`, recursos.
2. Você instala **Godot Editor (Android)** no celular e o app **Termux** (ou o cliente Git da
   sua preferência).
3. `git clone` do repo no celular → abre a pasta no editor Godot → roda.
4. Você mexe, faz `git push`; eu continuo daqui. Loop fechado, sem PC em nenhum momento.

**O que o Godot 4 entrega de realismo:** SDFGI (iluminação global em tempo real), volumetric fog,
SSR, SSAO, TAA, depth of field, glow, e shaders customizados — dá para reproduzir 90% do meu
pipeline de câmera corporal com qualidade superior à da web. Perde para o UE5 em Nanite,
Lumen de alta fidelidade, MetaHuman e no ecossistema de assets fotogramétricos.

**Limitação real:** compilar e iterar um mundo pesado no celular é lento e esquenta o aparelho.
Serve para protótipo e para jogo estilizado-realista; não para o "filme jogável" completo.

---

## 4. CAMINHO C — UE5 NA NUVEM (o teto do briefing)

Este é o caminho para "realismo que transborda".

**Arquitetura:**
```
[Seu celular] --navegador--> [Pixel Streaming] --> [PC virtual com GPU na nuvem]
                                                     UE5.4 + Lumen + Nanite
                                                     Megascans + MetaHuman
[Este repositório] --git--> mesmo PC virtual (código C++, Blueprints, dados de missão)
```

**Provedores viáveis:** Vagon Streams, Shadow PC, Paperspace, AWS G5, Azure NV-series.
Custo típico de desenvolvimento em uso real: US$ 20–60/mês.

**O que eu entrego neste repo para esse caminho** (quando você disser que quer):
- módulos C++ dos sistemas já provados: `TZBallisticsComponent`, `TZBodycamPostProcess`
  (material de pós + Niagara de lente), `TZPerceptionComponent`, `TZMissionGraph`;
- estrutura de dados das 27 missões e do grafo de decisões em `DataTable`/JSON;
- especificação de captura de animação e lista de assets (Megascans, MetaHuman, mocap).

**Ativos que dão o realismo (não são código):**
- **Quixel Megascans** — gratuito para UE5: superfícies e props fotogramétricos.
- **MetaHuman** — humanos fotorrealistas em minutos.
- **Nanite + Lumen** — geometria e luz de cinema sem assar nada.
- **Chaos Destruction** — destruição estrutural.
- **MetaSounds** — o áudio procedural que já prototipei, mas em nível de produção.

---

## 5. O QUE JÁ ESTÁ PRONTO NESTE REPOSITÓRIO

```
game/
  index.html                  tela de entrada + o único botão de UI (SAIR)
  src/main.js                 laço principal, montagem da missão, luneta, encerramento
  src/render/bodycam.js       pipeline de sensor CMOS (rolling shutter, ISO, CA, NV, chuva…)
  src/world/world.js          relevo, céu dinâmico, instalação militar, chuva, holofotes
  src/player/player.js        corpo do operador: fôlego, batimento, postura, dano, arnês
  src/weapons/weapons.js      fichas reais das armas + viewmodels animados
  src/weapons/ballistics.js   balística externa, penetração, ricochete, som supersônico
  src/ai/soldier.js           percepção, esquadrão, combate, morte sem coreografia
  src/campaign/campaign.js    grafo de missão e decisões simultâneas por rádio
  src/audio/audio.js          síntese de tiro, impacto, rádio, respiração, artilharia
  src/net/net.js + server/    escaramuça multiplayer (relay 20 Hz)
  tools/smoke.js              teste headless de 30 s da simulação inteira
  tools/bal.mjs               validação da balística contra tabelas reais
docs/                         lore, GDD e este pipeline
```

**Rodar:**
```bash
cd game
npm install
npm run dev          # preview jogável
npm run server       # opcional: servidor de escaramuça (abra o jogo com ?mp=1)
node tools/smoke.js  # teste de regressão da simulação, sem GPU
```

---

## 6. ROADMAP DE PRODUÇÃO (se for para o Caminho C)

| Fase | Duração | Entrega |
|---|---|---|
| 0 · Protótipo de sistemas | **feito** | Este repo: câmera, balística, IA, decisões |
| 1 · Vertical slice UE5 | 4–6 meses | Missão 1 completa em qualidade final, 1 arma, 1 esquadrão |
| 2 · Ato I completo | 8 meses | 4 missões, 2 países, sistemas de dano e destruição |
| 3 · Atos II–III | 12 meses | Naval, urbano, ciberguerra diegética |
| 4 · Atos IV–V + multiplayer | 10 meses | 27 missões, 5 finais, modo ARQUIVO 16 jogadores |
| 5 · Polimento e certificação | 6 meses | Otimização, localização, classificação etária |

Equipe mínima realista para o Caminho C: 18–25 pessoas (6 programadores, 8 arte/animação,
2 áudio, 2 design de missão, 1 escritor, produção e QA). Orçamento de referência:
US$ 4–8 milhões. **Nada disso invalida o Caminho A** — o protótipo continua sendo o lugar onde
as regras do jogo são decididas antes de custarem caro.

---

## 7. RECOMENDAÇÃO

1. **Agora:** continuar no Caminho A comigo — cada missão nova (sniper, naval, ciberguerra,
   linha de frente) vira um cenário jogável aqui, e cada sistema fica provado.
2. **Em paralelo, se quiser mexer sozinho no celular:** eu monto o projeto Godot (Caminho B)
   neste mesmo repo e você edita pelo editor Android.
3. **Quando houver orçamento:** Caminho C, com o protótipo servindo de especificação executável.
