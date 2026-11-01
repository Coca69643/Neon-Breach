# Projeto Arena 0.2.0

MOBA 3D para Android, em paisagem, com partidas locais totalmente offline 5v5. Esta versão é uma primeira fatia funcional de uma partida contra bots; não é um cliente online nem um MOBA completo de produção.

## Partida offline

- 1 jogador + 4 bots aliados contra 5 bots adversários.
- Três rotas: oeste, centro e leste.
- Pressão independente por rota, ondas simplificadas de tropas e estruturas defensivas.
- Bots locais avançam pela rota atribuída, avaliam alvos próximos, interrompem adversários e voltam à formação após ficarem temporariamente fora da disputa.
- A vitória é definida pela conquista de duas das três rotas.
- Nenhum servidor, login, matchmaking ou permissão de internet é necessário.

## Heróis e habilidades

- **Lyra — suporte:** pulso de ressonância com alcance ampliado.
- **Bastion — defesa:** barreira com duração ampliada.
- **Kairo — mobilidade:** recarga reduzida do pulso.
- **Impulso:** deslocamento rápido.
- **Pulso:** interrompe unidades adversárias próximas.
- **Barreira:** protege temporariamente o jogador.

Habilidades são efeitos fictícios e abstratos de gameplay; não representam armamento real.

## Arquitetura

- Android nativo: lifecycle, UI, controles touch e estados de aplicação em Kotlin.
- C++20 via NDK/CMake: simulação, bots locais, ondas de tropas, progresso das rotas e habilidades.
- Filament 1.77.3: renderização 3D, Vulkan preferencial e fallback OpenGL ES.
- glTF 2.0 runtime: cenário com três rotas, estruturas, terreno contínuo, vegetação e unidades.
- Paisagem obrigatória e HUD/minimapa adequados à tela mobile.

## Build

O workflow GitHub Actions faz verificação estrutural, compila arm64-v8a e armeabi-v7a, verifica a existência do APK debug e publica o artefato project-arena-0.2.0-debug. O resultado do CI confirma a compilação, mas não substitui teste no dispositivo.

## Assets e licenças

- Quaternius Universal Base Characters: CC0 1.0; licença arquivada em ASSETS/Quaternius-Universal-Base-Characters-LICENSE.txt.
- Terreno, rotas, árvores, água, estruturas e avatares low-poly da primeira fatia são geometria gerada pelo projeto.
- Filament é distribuído sob Apache License 2.0.

## Limitações desta versão

A IA, a economia de tropas e a pressão das rotas são simplificadas. Não há loja, progressão persistente de herói, objetivos neutros avançados, campanha ou rede. Compatibilidade gráfica, FPS prolongado e comportamento térmico precisam ser medidos no Realme C53.
