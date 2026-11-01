# Projeto Arena — versão 0.1

Nova linha de desenvolvimento do repositório. A versão 0.1 é uma fatia vertical mobile-first de uma arena 3D por equipes, com foco em movimentação, cooperação e controle territorial. Não reutiliza o ciclo de tiro, armas, inimigos ou objetivos do ORION-9.

## Primeiro marco

- Android nativo, paisagem obrigatória.
- Filament 1.77.3: Vulkan como backend preferencial; OpenGL ES como fallback.
- Kotlin para ciclo de vida, interface e input tátil.
- C++20 para simulação cinemática, aceleração, desaceleração, colisões e captura do objetivo.
- Câmera top-down oblíqua com projeção ortográfica e acompanhamento suave.
- Terreno contínuo com relevo, trilhas curvas, água, vegetação, rochas e um marco central.
- Personagem humanoide CC0 da Quaternius, com rig humanoide; animação de locomoção procedural na hierarquia de ossos.
- Nome e ícone são provisórios. A pesquisa de naming/branding vem depois da validação da primeira versão.

## Arquitetura

`MainActivity.kt` gere o estado da aplicação, os controles e a HUD.
`FilamentGameRenderer.kt` cria o renderer com Vulkan primeiro e OpenGL ES em recuperação.
`WorldGlbBuilder.kt` gera a malha ambiental glTF 2.0 em runtime, agrupada por material e com normais suaves.
`ArenaSimulation.cpp` executa a simulação C++20 e as colisões do personagem.

## Física da versão 0.1

O primeiro corte usa movimento cinemático com aceleração, amortecimento, limite de velocidade, colisores circulares de cenário, limite orgânico de arena, altura de terreno e uma habilidade de mobilidade com cooldown. O objetivo central progride enquanto o personagem permanece dentro da zona de captura. Isso não substitui uma simulação rígida completa; estabelece uma base testável de movimento e colisão.

## Assets e licenças

- Quaternius Universal Base Characters: CC0. Modelo humanoide distribuído em `app/src/main/assets/characters/`; licença arquivada em `ASSETS/`.
- Terreno, trilhas, água, rochas, árvores, vegetação e santuário da primeira fatia são geometria original gerada em runtime pelo projeto. Poly Haven permanece como fonte planejada para próximos assets e materiais; nada será marcado como importado antes de ser realmente integrado.
- Filament é distribuído sob Apache License 2.0.

## Build

O workflow GitHub Actions executa a verificação estrutural, compila o target C++20 via NDK/CMake e gera o APK debug. O APK precisa ser testado em dispositivos reais para confirmar o caminho Vulkan e o fallback GLES.
