# Projeto Arena

MOBA 3D mobile para Android, com arquitetura Flutter + Flutter Scene. Aplicativo offline, orientação landscape e renderização 3D integrada ao Flutter GPU / Impeller.

## Log de atualizações

- **1.7.4 (66) — arena expandida e câmera de ação:** Vale das Coroas ampliado de 88 × 58 para 120 × 84 unidades; quatro acessos laterais percorríveis; colisão com rio, pontes, árvores e torres; câmera traseira baixa com suavização e leitura de personagem em primeiro plano. Build ARM64 submetido ao CI; renderização, FPS e temperatura ainda precisam de teste físico.
- **1.7.3 (65) — câmera de combate:** enquadramento 3/4 mais baixo e próximo do herói; escala ampliada do personagem jogável, bots e minions para leitura em tela mobile. Build ARM64 submetido ao CI; validação visual e FPS no Realme C53 pendentes.
- **1.7.2 (64) — migração Flutter Scene:** runtime 3D migrado para Flutter; máquina de estados Dart; preview 3D de Lyra, Bastion e Kairo; hub 3D e sub-telas reorganizadas; Vale das Coroas reconstruído com footprint retangular orgânico, três rotas, rio em S e três pontes. APK ARM64 assinado e validado no CI; teste físico ainda pendente.

## Histórico legado

- **0.16.0 (build de teste)** — Personagens CC0 e NPCs com 3 corpos, animações próprias e paletas por material; terreno PBR, vegetação e iluminação ambiental.
- **0.15.12** — Corrigida a orientação dos três heróis e aplicadas paletas de materiais individuais.
- **0.15.11** — Novo ícone e identificador Android próprio, sem conflito de instalação com ORION-9.
- **0.15.10** — Fauna reposicionada perto das rotas; culling acompanha os animais em movimento.
- **0.15.9** — Lyra, Bastion e Kairo com modelos CC0 independentes.
- **0.15.8** — Seis animais, oito guardiões e vegetação agrupada.
- **0.15.6** — Recuperação de inicialização 3D e correções de rig.
- **0.15.5** — Primeiro modelo 3D autoral da Lyra.
- **0.15.4** — Ajustes de câmera, seleção de heróis e leitura do cenário.
- **0.15.0** — Reconstrução do mapa, relevo, funções dos personagens e HUB.

