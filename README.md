# KÄIRŌS TASK MANAGER

Multi-gerenciador de dispositivos tecnológicos — **Bunker Studios**.

Controle a TV e o computador pelo celular, com teclado virtual, gamepad virtual e jogos do telefone projetados no outro aparelho **sem instalar nada nele**.

## Como usar

```bash
npm install
npm start
```

Abra no celular: `http://IP-DESTA-MÁQUINA:4173`

1. Crie um PIN na primeira abertura.
2. A lista de dispositivos atualiza sozinha **a cada 7 minutos** (censo da LAN + SSDP). Toque em **ATUALIZAR** para varrer agora.
3. Na Smart TV ou no navegador do PC, abra `/receiver` e digite o código de 6 dígitos em **Ajustes**.
4. Controle: teclado, gamepad, touchpad, D-pad da TV, volume, standby.
5. Em **Jogos**, escolha o alvo e jogue. O game roda no celular; a outra tela só mostra o vídeo.

### Controle nativo do Windows / Linux / macOS

O receptor no navegador controla o que está naquela aba (jogos projetados, teclas na página). Para injetar teclado/mouse no sistema operacional:

```bash
node agent/kairos-agent.js ws://IP-DO-HUB:4173/ws
```

No Linux o agente usa `xdotool`. Emparelhe com o código que o agente imprime no terminal.

## Instalar como app no Android (PWA / “APK”)

Chrome → menu → **Adicionar à tela inicial**. O manifesto já está em `display: standalone`.

Para gerar um APK/TWA depois: empacote `public/` + o hub com Capacitor / PWABuilder apontando para o hub da casa.

## O que o censo encontra

Hosts na sua rede com portas típicas de Chromecast, Roku, Smart TV, RDP, VNC, SSH, Plex, impressora, DLNA. Sem o Receptor/Agente, o KÄIRŌS **mostra** o aparelho; o controle total exige emparelhamento — ninguém assume o controle de um dispositivo que você não autorizou.

## Arquitetura

```
Celular (comandante PWA)
        │  WebSocket
        ▼
   Hub KÄIRŌS (Node)
        │
   ┌────┼────────────┐
   ▼    ▼            ▼
Receptor   Agente    Censo LAN
(TV/PC)   (SO nativo)  7 min
```

Jogos nunca são copiados para a TV: o hub retransmite frames JPEG da canvas do celular.
