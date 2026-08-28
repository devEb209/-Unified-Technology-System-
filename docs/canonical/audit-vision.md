# AUDITORIA DA ARQUITETURA vs A VISÃO (honestidade total)

> Auditoria feita sob as duas regras supremas e o critério de completo em
> 12 pontos (vision.md). Nada foi inflado; o percentual foi **rebaixado**
> para refletir a régua correta (89% → 70%). Distância é a única moeda aqui.

## A) O que JÁ ESTÁ ALINHADO à visão (com evidência)

| Alinhamento | Evidência real |
|---|---|
| RRW como base da realidade e causalidade | entidades/componentes/**relações** (juntas já são relações!)/eventos com cadeia verificável; `save→load→evoluir == original` byte-idêntico; processos abstratos↔detalhados |
| Tese dos D como camadas funcionais com efeito observável | 16 camadas, `touch()` auditável; toggle muda a realidade; testes provam efeito |
| D-O15 = materializar dentro dos limites, defer-not-discard | pressão→estratégia auditável (raio, percepção, sombras, SR de áudio, impostor); fila de defer executa quando há orçamento; NADA descartado da verdade |
| **Escala multinível é realidade (a prova mais forte)** | D-14: settlement abstrato↔individual preservando identidade/estado/relações/memória — a cidade distante é ESTADO CAUSAL, não textura. Isto é a visão §6 funcionando ANTES dela ser escrita |
| Mundo vivo, não cena | clima causal (chuva→molhado, vento+seca→poeira, tempestade→raio→fogo→medo), economia/agregados, recursos com regrowth, memória de NPCs, gossip; cadeias verificadas ponta a ponta |
| NMN como mente | necessidades→percepção→memória→relações→decisão COM EXPLICAÇÃO causal→ação→consequência→memória nova |
| RealLife causal como módulo | máquina de estados climática com causas e consequências testadas |
| AI-first como interface principal | Core interpretar→planejar→executar tools validadas→verificar→corrigir→memória; no browser o usuário digita o objetivo e a realidade muda; CreationProjects duráveis e retomáveis |
| Cadeia REALIDADE→…→HARDWARE | RRW→Frame→(RHI→GPU / AudioStream→device); Frame é a única verdade da apresentação |
| Filosofia nativa (ADR-018) | renderer/RHI/física/áudio/DB/comm próprios; externo só o inevitável, isolado |

## B) O que está PARCIALMENTE alinhado

> **R1 FECHOU (esta rodada): atmosfera, hidrologia, combustão, ecologia —
> ver "✅ R1" abaixo. Os itens restantes de B são acústica, física de
> energia, D-O15 re-representação.**

- ✅ **R1: Atmosfera** — `world/phenomena/atmosphere.js`: o céu É
  espalhamento (Rayleigh dia/pôr-do-sol por caminho óptico + Mie por
  umidade/poeira/poluição), com inércia (o ar é gás, não flag). O renderer
  CONSUME `atmosphere.sky()` — o gradiente autoral foi DELETADO de reallife.
- ✅ **R1: Hidrologia** — `world/phenomena/hydrology.js`: água como
  SUBSTÂNCIA (células com lâmina d'água; chuva acumula, escoa por
  gradiente, evapora ao sol, infiltra no solo → `soil.wetness` é A umidade
  do mundo). Poças persistem em terreno plano; solo encharcado RECUSA
  ignição (testado).
- ✅ **R1: Combustão** — `world/phenomena/combustion.js`: fogo é processo
  sobre COMBUSTÍVEL real (bioma→biomassa); espalha por vento+continuidade,
  chuva apaga, chão queimado PERSISTE, umidade bloqueia; cada ignição/
  extinção é evento causal RRW (raio→ignited→started→sighted→flee
  verificado em teste de integração).
- ✅ **R1: Ecologia** — `world/phenomena/ecology.js`: vegetação é
  POPULAÇÃO (indivíduos com espécie/idade/biomassa/saúde; crescimento
  logístico dirigido por sol×água do solo; sementes, competição, morte por
  fogo/seca/idade; madeira morta vira combustível — ciclo fechado com
  combustão). Renderer materializa a população sob D-O15.
- ✅ **R2: Acústica** — `world/phenomena/acoustics.js`: som é onda de
  pressão com atraso FINITO (d/343), absorção do ar (umidade!), sombra
  acústica de terreno (atrás da serra: fraco e abafado). Trovão longe =
  rumble grave (re-representação D-O15, não corte). O som NÃO atravessa
  mais montanhas.
- **Física**: mecânica sólida (impactos causais, rotação, juntas PBD), sem
  energia acumulada, deformação, materiais, fluidos.
- **D-O15 em áudio/partículas**: corta CONTAGEM (voices, densidade) em vez
  de RE-REPRESENTAR — **trovão longe → rumble grave JÁ RESOLVIDO no R2**;
  falta fogo longe (brilho no horizonte) e partículas.
- **Streaming**: cache LRU persistido existe mas é opcional; sem workers.

## C) Onde caiu em mentalidade de engine tradicional (confissão honesta)

1. **Céu = skybox/gradiente** (§3 violado): não modela espalhamento
   atmosférico; poeira/chuva do estado deveriam colorir o céu.
2. **Água = shader de ondas**: onda decorativa; nenhuma substância
   representada. §3 diz exatamente "não definir a água simplesmente como
   shader de água" — foi o que fizemos.
3. **Partículas = contagem GL_POINTS** (`particleDensity` multiplica
   quantidade): chuva/poeira são matéria representável (fluxo, massa,
   concentração) — hoje são só "menos pontinhos".
4. **Iluminação = blinn-phong + 1 sol + 4 pontuais**: mecanismo OK como
   materialização, mas não há modelo de luz (extinção, indireta, oclusão
   atmosférica) por trás — a técnica virou o fundamento.
5. **LOD/impostores/fade**: implementados como técnica gráfica pura.
   São legítimos COMO MATERIALIZAÇÃO da escala (§6), mas hoje não derivam
   de nenhuma semântica de escala representada (só de distância). A
   distância é um proxy razoável, não a realidade.
6. **Sons one-shot**: trovão = burst de ruído. Materialização honesta para
   perto; para longe deveria haver re-representação acústica, não corte.

## D) Sistemas que precisam EVOLUIR (sem reescrever)

- `render/shaders+webgl2`: céu/água/luz passam a CONSUMIR estado
  atmosférico/hidrológico do Frame (os shaders ficam; a fonte muda).
- `world/reallife`: de módulo de clima a **camada transversal** de
  fenômenos (atmosfera, hidrologia, combustão, ecologia de crescimento).
- `audio`: camada acústica (oclusão via raycast de terreno que JÁ existe,
  absorção por zona, atraso de propagação ligado ao binaural).
- `physics`: energia (impulso→deformação→consequência), materiais.
- `world/streaming`: cache persistido default-on, amostragem async.
- `nmn`: conhecimento/medo/objetivos como estado de primeira classe;
  escala de grupos.
- `d/do15`: estratégias de RE-REPRESENTAÇÃO (não só contagem).

## E) Sistemas NOVOS necessários (não existem hoje)

1. **Atmosfera** (`world/phenomena/atmosphere`): ar como estado (densidade,
   umidade, poeira) → céu/extinção/fog derivados → Frame → shaders.
2. **Hidrologia** (`world/phenomena/hydrology`): corpos d'água com nível/
   vazão; chuva acumula, escoa, alaga; molhado deriva daí.
3. **Combustão** (`world/phenomena/combustion`): fogo consome combustível
   real, espalha por vegetação/vento, chuva extingue — tudo causal no RRW.
4. **Ecologia de crescimento** (`world/phenomena/ecology`): árvores com
   idade/tamanho/estado; sementes→crescimento→morte; conecta D-9 e vegetação
   do renderer.
5. **Acústica** (`audio/acoustics`): oclusão/absorção/propagação como
   modelo, materializada pelo stream.
6. **Gramática de criação** (`singularity/creation`): "cidade costeira
   tropical, economia própria, rios, agricultura, anos de evolução" →
   decomposição em fenômenos + estruturas + projetos longos.
7. **Anexos/contexto** (plataforma): imagens/documentos/dados como entrada
   interpretada, com contratos e segurança.
8. **Pipelines assíncronos**: workers para amostragem/geração pesada.

## F) Técnicas no lugar errado (e como ficam)

| Técnica | Hoje | Deve ser |
|---|---|---|
| LOD/impostores/fade | fundamento visual da distância | materialização da escala representada (a escala vem do estado; a técnica só desenha) |
| Skybox/gradiente | o céu inteiro | fallback de apresentação; o céu deriva da atmosfera |
| Shader de água | a água inteira | materialização do corpo d'água representado |
| Partículas por contagem | chuva/poeira | materialização de fluxo/massa representados |
| Blinn-phong | a "luz" | materialização do transporte de luz simplificado sobre o estado atmosférico |

## G) A arquitetura ÚNICA (convergência)

```
                    ┌──────────────────────────────┐
                    │  RRW (estado + causalidade)  │
                    └──────┬───────────────────────┘
          ┌────────────────┼──────────────────────────┐
   RealLife/Fenômenos   NMN (mentes)          Sociedade/Economia
   atmosfera hidrologia
   combustão ecologia
          └────────────────┼──────────────────────────┘
                    D-O15 (priorizar/materializar)
                           ↓
                     PERCEPÇÃO + FRAME
                    ↓                  ↓
             Renderer (RHI→GPU)   AudioStream (→device)
             materializa               materializa
           luz/água/céu/fogo     propagação/acústica
```
Tudo sobre o MESMO estado; nada inventa realidade; cada fenômeno tem
representação → modelo → materialização → percepção.

---

# RE-BASELINE HONESTA: 89% → **70%**

O 89% media "sistemas implementados e testados". A régua nova mede
**fidelidade de representação + 12 pontos**. Reavaliação por categoria
(pesos mantidos; notas sob a régua nova):

| Categoria | Peso | Antes | **Agora** | Por quê caiu/subiu |
|---|---|---|---|---|
| Núcleo da realidade (RRW/D/D-O15/NMN/escala) | 18 | 100% | **85%** | D-14 multinível é a visão §6 viva; caem profundidade de NMN e escala de grupos |
| Render GÊNESIS | 14 | 92% | **45%** | céu/água/luz/partículas ainda mecanismo-no-lugar-do-fenômeno |
| Singularity AI | 14 | 90% | **75%** | Core forte; falta gramática de criação real, LLM/busca vivos |
| Plataforma UTS | 12 | 90% | **85%** | falta anexos/contexto e storage externo |
| Usabilidade pra todos | 10 | 82% | **80%** | demo forte; falta onboarding/galeria |
| Física | 8 | 88% | **55%** | sem energia/deformação/fluidos/materiais |
| Áudio | 8 | 88% | **60%** | binaural/música fortes; acústica inexistente |
| Streaming+Persistência | 8 | 90% | **80%** | persistência forte; async ausente, cache não-default |
| Ferramentas/pipelines | 8 | 75% | **60%** | alcance criativo da IA ainda restrito |
| **TOTAL** | 100 | (89%) | **≈70%** | distância real à visão |

# ROADMAP DE EVOLUÇÃO (visão-first; um fenômeno por vez, os 12 pontos cada)

- **R1 — Fenômenos I**: Atmosfera (ar→céu/extinção/fog derivados) ·
  Hidrologia v1 (corpo d'água com nível/vazão; chuva acumula/escoa) ·
  Combustão v1 (fogo consome/espalha por vento+vegetação; chuva apaga).
- **R2 — Fenômenos II**: Ecologia de crescimento (árvores com
  idade/estado; bioma→morfologia) · Acústica v1 (oclusão/absorção/propagação) ·
  Física: energia→deformação→consequência.
- **R3 — Escala como realidade**: generalizar D-14 além de settlements
  (multidões, clima, água, terreno: abstrato↔detalhe com continuidade);
  LOD/impostores passam a materializar ESSA escala.
- **R4 — D-O15 re-representação**: trocar cortes de contagem por
  representações alternativas (trovão longe→rumble; chuva→fluxo+área).
- **R5 — Criação completa**: gramática de criação (cidade costeira,
  economia, anos), CreationProjects longos, anexos/contexto.
- **R6 — Infra e alcance**: workers/async, LLM real + busca real,
  onboarding/galeria/npm start.

A cada rodada: % recalculado nesta régua, com o que ENTROU e o que ainda
falta — sem inflar nada.
