# Limitações reais

Sem exagero — o que NÃO existe (e o que está pronto para receber).

## 1. Renderer GPU — AUSENTE (FUTURO)

- Backends existentes: `NullBackend` (métricas) e `TextBackend` (ASCII CLI).
- **Não existe** renderer Vulkan/DirectX/OpenGL/WebGL.
- **Pronto para**: `RendererBackend` (interface `render(frame, world?)`) —
  um backend GPU pluga sem tocar na lógica; a UES não se acopla a nenhuma
  API gráfica concreta.

## 2. LLM externo no Node — AUSENTE (FUTURO)

- `HeuristicProvider` (local, não-LLM) + `PuterProvider` (browser-only).
- **Nenhum LLM externo real conectado** em Node — não se finge o contrário.
- **Pronto para**: `ProviderRegistry.define(...)` — o teste `canonical`
  demonstra um provider externo plugando e orquestrando o fluxo completo
  (cena construída no mundo) sem alterar o Core.

## 3. Persistência — IMPLEMENTADA (esta etapa), com escopo definido

- `serializeUes/restoreUes/saveUes/restoreFromJson` cobrem: RRW completo
  (incl. causalidade e processos), mundo (chunks/heights/foco/raio/zonas),
  relógio, RNG (estado exato), hardware, sociedade, agendamento D-O15,
  memória da IA. Determinismo comprovado por teste.
- **Faltam**: I/O de disco/ficheiro (a API devolve string JSON — a escrita
  em arquivo é trivial e fica por conta do chamador), versioning/migração de
  snapshots, e persistência de estado de terceiros (ex.: plugins de renderer).

## 4. Escala — MEZURADA, não extrapolada

- Medido (esta máquina, workstation 60ms): 500 NPCs materializados ≈
  27ms/tick (ok); **2000 materializados ≈ 216ms/tick → gargalo CPU** (o
  sistema adapta: deferrals + raio menor); 20.000 abstratas ≈ 2ms/tick.
- O ponto de gargalo **depende da máquina** — os testes usam margens e
  verificam a **adaptação** (não um número absoluto).
- Percepção de NPC é O(entidades no raio) — com milhares de NPCs densos,
  a percepção vira o gargalo dominante (candidato a grade espacial/LOD de
  percepção — futuro).

## 5. D-MAX e acrônimo RRW — NÃO RATIFICADOS

- Ver `provisional.md`. Enquanto não ratificados, **não são canon**.

## 6. Escopo de "realidade"

- A implementação cobre: espaço 2.5D, biomas, tempo/clima, fogo, entidades
  biológicas (NPCs), sociedade/economia, informação, óptica básica (luz/
  sombra/LOD). Não cobre: fluidos, acústica, redes elétricas, vida social
  em escala civilização, 3D, etc. — tudo isso é **extensível** no RRW, mas
  **não implementado** (a visão é maior que o estado atual — ver `vision.md`).
