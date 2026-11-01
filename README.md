# Projeto Arena 0.4.0

MOBA 3D mobile para Android, landscape e totalmente offline, com partidas 5v5 contra bots.

## IA e navegação 0.4.0
- Cada bot mantém rota, equipe, faixa e slot de formação durante a partida.
- Navegação de chegada com frenagem: reduz a velocidade conforme se aproxima do ponto-alvo e para ao alcançá-lo.
- NPCs não usam a posição do jogador como alvo e não recalculam perseguição a cada frame.
- O input do joystick altera somente a movimentação do herói.
- Bots desativados retornam à sua formação após o tempo de recuperação.
- Pressão de rota usa presença real na zona frontal.

## Partida offline
- 1 jogador + 4 bots aliados contra 5 bots adversários.
- Três rotas com pressão independente e ondas simplificadas de tropas.
- Três arquétipos: Lyra, Bastion e Kairo.
- Habilidades fictícias sem armas: impulso, pulso de ressonância e barreira.
- Sem login, servidor, matchmaking ou permissão de internet.

## Identidade visual
- Ícone próprio com fortaleza, três rotas e núcleo azul.
- Nome do aplicativo: Projeto Arena.

## Arquitetura
- Android nativo: lifecycle, UI e controles touch em Kotlin.
- C++20 via NDK/CMake: simulação, IA local, rotas e habilidades.
- Filament 1.77.3: renderização 3D, Vulkan preferencial e fallback OpenGL ES.
- Humanoide Quaternius CC0 compartilhado entre as instâncias do herói e bots.

## Build
O workflow valida estrutura, compila Kotlin/C++20 para arm64-v8a e armeabi-v7a, confirma a existência do APK debug e publica project-arena-0.4.0-debug. O CI confirma compilação, não substitui teste no Realme C53.

## Limitações
A IA de rotas ainda é uma base simplificada, sem tomada de decisão tática complexa. Visuais, papéis individuais de heróis, objetivos e tropas precisam de novas iterações. Renderização, FPS prolongado, memória e temperatura no Realme C53 ainda precisam de teste físico.
