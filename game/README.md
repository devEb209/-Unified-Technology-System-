# THEATRE ZERO — protótipo jogável

Bodycam tática ambientada na Terceira Guerra Mundial. Sem HUD, sem menu em partida,
sem tiro cinematográfico. Só um sensor de câmera sujo preso ao peito de alguém que
provavelmente não volta.

```bash
npm install
npm run dev            # abre o preview
npm run server         # opcional: escaramuça multiplayer, depois abra o jogo com ?mp=1
node tools/smoke.js    # teste headless da simulação (mundo + IA + balística + campanha)
node tools/bal.mjs     # confere a balística contra tabelas reais
```

## Controles (não existem na tela — estão só aqui)

| Tecla | Ação |
|---|---|
| `WASD` | mover · `SHIFT` correr · `CTRL` agachar · `C` deitar |
| `Botão direito` | mira (ADS / luneta 10×) · `Botão esquerdo` atirar |
| `R` | recarregar (tática ou com ferrolho, se a câmara estiver vazia) |
| `V` | **checar carregador** — a única forma de saber sua munição |
| `Q` / `E` | inclinar sobre a cobertura |
| `B` | prender a respiração (custa fôlego) |
| `N` | intensificador de imagem (visão noturna Gen-3) |
| `1` `2` `3` | MK18 suprimido · M110 SASS · Glock 19 |
| `F` | interagir / sabotar / hackear (segurar) |
| `F1` / `F2` | responder às **duas ordens simultâneas** do rádio |

## A missão que está no protótipo

**ATO I — SILENT MERIDIAN.** Estônia, 02:36, chuva. Você tem que apagar um radar que
guia mísseis contra Roterdã. Aos 26 metros do perímetro, dois comandos legítimos chegam
ao mesmo tempo e você tem 14 segundos: cortar a energia (silêncio, escuridão, você
enxerga com o tubo e eles não) ou marcar o radar para um drone (rápido, barulhento,
a guarnição inteira acorda). Depois disso, mais uma bifurcação: destruir o radar ou
capturar o oficial de enlace. As duas fecham portas diferentes para o Ato II.

Se você for detectado, dez reforços convergem por dois eixos e a missão vira outra coisa.

Documentação completa em [`../docs`](../docs): lore, GDD de sistemas e pipeline técnico.
