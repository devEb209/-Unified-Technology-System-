# Käirōs Net Manager

**Controle total. Sem limites.** — App Android (APK) de uso pessoal para gerenciar a **sua própria** rede Wi-Fi.

> Uso estritamente pessoal, na rede da qual você é o proprietário. O app se recusa a operar em qualquer rede que não seja a vinculada como sua.

## Acesso
- Senha secreta exclusiva do app: `VAĒLÏS` (não é a senha real do Wi-Fi)
- Guardada apenas como hash SHA-256 com sal — nunca em texto puro
- 5 erros → app travado por 5 minutos; sessão expira em 15 minutos parado

## Principais recursos
- Lista de dispositivos conectados com **atualização automática a cada 7 minutos** (serviço em segundo plano)
- **Bloquear / desbloquear** internet do dispositivo com um toque (alternável)
- **Pausa blindada de 3h07min** — irreversível até o prazo terminar
- **Histórico completo por dispositivo** (conexões, bloqueios, pausas, mudanças)
- **Aumentar / diminuir potência (prioridade QoS 1–5)** e limite de banda por aparelho
- Modo pânico, liberar todos, scanner de portas, saúde da rede, favoritos, confiáveis, apelidos
- **78 sistemas** catalogados e alternáveis na aba *Sistemas*

## Trava "só a MINHA rede"
Na primeira execução, toque em **Marcar como minha** no painel. O app grava o BSSID+SSID e, a partir daí, todos os controles ficam desativados em qualquer outra rede.

## Bloqueio real
O corte de tráfego de terceiros só é efetivo através do roteador. Em **Ajustes → Painel do Roteador**, informe usuário e senha do painel; o app tenta os endpoints comuns (OpenWrt/LuCI, TP-Link, Mercusys, APIs genéricas). Sem isso, o estado é mantido localmente e reaplicado a cada ciclo.

## Gerar o APK
O build roda no GitHub Actions (`.github/workflows/kairos-apk.yml`):
1. Actions → **Käirōs Net Manager - Build APK** → *Run workflow*
2. Baixe o artefato **KairosNetManager-APK** (acessível apenas a quem tem acesso ao repositório)

Localmente: `./gradlew assembleRelease` com JDK 17 + Android SDK 34.

## Estrutura
```
app/src/main/java/net/kairos/manager/
├── MainActivity.kt          navegação e sessão
├── core/                    modelo, storage, auth, serviço 7min, ViewModel
├── net/                     scanner, ARP, OUI, enforcement no roteador
├── systems/Systems.kt       catálogo dos 78 sistemas
└── ui/                      tema, tela de senha, telas
```
