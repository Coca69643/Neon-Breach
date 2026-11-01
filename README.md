# Projeto Arena 0.5.0

MOBA 3D Android, landscape e offline, com partidas locais contra bots.

## IA 0.5.0
- Cada bot possui rota persistente com waypoints fixos, velocidade individual e atraso inicial.
- Navegação não lê a posição do jogador nem o progresso do placar das rotas.
- Avanço monotônico por waypoints, frenagem de chegada e slots laterais por rota.
- Progresso de cada rota é calculado numa zona central fixa, sem mover os destinos dos bots.
- Herói orienta-se pela velocidade vetorial e conserva a última direção quando parado.

## Identidade
Ícone original com silhueta de herói mascarado, visor violeta/ciano e três rotas convergentes. O ícone legado do ORION-9 não é usado.

## Arquitetura
- Android nativo Kotlin + C++20/NDK.
- Filament 1.77.3, Vulkan com fallback OpenGL ES.
- Partida local offline, sem login, servidor ou permissão de internet.
- Landscape obrigatório, controles touch e câmera de acompanhamento.

## Limitações
A IA atual faz avanço e disputa de zona por rota; ainda não representa uma IA MOBA completa. O teste de movimento, enquadramento, FPS sustentado e temperatura precisa ser feito no Realme C53.
