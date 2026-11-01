# Projeto Arena 0.3.0

MOBA 3D para Android, landscape, com partidas locais totalmente offline 5v5. Esta versão corrige defeitos de renderização e reconstrói a leitura visual do mapa e das unidades.

## Partida offline
- 1 jogador + 4 bots aliados contra 5 bots adversários.
- Três rotas: oeste, centro e leste, com pressão independente.
- Ondas simplificadas de tropas e estruturas defensivas.
- Bots locais avançam por suas rotas, avaliam unidades próximas e disputam os objetivos.
- Três arquétipos selecionáveis: Lyra (suporte), Bastion (defesa) e Kairo (mobilidade).
- Habilidades fictícias sem armamento: impulso, pulso de ressonância e barreira.
- Nenhum servidor, login, matchmaking ou permissão de internet é necessário.

## Reconstrução visual 0.3.0
- Ordem de triângulos de esferas corrigida para faces externas visíveis.
- Sol direcional com ângulo oblíquo, exposição explícita e preenchimento por luz indireta.
- Terreno com perímetro arredondado em vez de malha quadrada exposta.
- Três rotas com ombros escuros e superfície central de pedra.
- Bots usando instâncias do humanoide Quaternius CC0, tintas por equipe e animação procedural de rig.
- Câmera de overview para menu/pausa/resultado e câmera de acompanhamento durante a partida.
- Painel de pausa centralizado.

## Arquitetura
- Android nativo: ciclo de vida, UI e controles touch em Kotlin.
- C++20 via NDK/CMake: simulação, bots locais, ondas e progresso das rotas.
- Filament 1.77.3: renderização 3D, Vulkan preferencial e fallback OpenGL ES.
- glTF 2.0 runtime para ambiente; instâncias glTF do humanoide CC0 para jogador e bots.
- Paisagem obrigatória; HUD e minimapa em composição mobile.

## Build e validação
O workflow valida estrutura, compila Kotlin e C++ para arm64-v8a e armeabi-v7a, confirma a existência do APK debug e publica project-arena-0.3.0-debug. O CI confirma a compilação, não substitui teste no Realme C53.

## Assets e licenças
- Quaternius Universal Base Characters: CC0 1.0; licença arquivada em ASSETS/Quaternius-Universal-Base-Characters-LICENSE.txt.
- Ambiente, rotas, árvores, rochas, água e estruturas são geometria gerada pelo projeto.
- Filament é distribuído sob Apache License 2.0.

## Limitações
IA, tropas, economia e pressão de rota ainda são simplificadas. As nove instâncias dos bots compartilham o mesmo modelo base. Teste visual, compatibilidade gráfica, FPS prolongado, memória e temperatura no Realme C53 permanecem pendentes.
