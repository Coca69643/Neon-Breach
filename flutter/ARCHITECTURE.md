# Projeto Arena — arquitetura Flutter Scene

## Decisão técnica

**Flutter + Flutter Scene** será a stack de aplicação e 3D do Projeto Arena. Flutter Scene é um runtime 3D integrado ao ecossistema Flutter, construído sobre Flutter GPU e Impeller. Não usaremos runtime C++ próprio, OpenGL ES manual, Filament, Godot, Unity, Unreal ou Flame.

- **Flutter/Dart:** aplicação Android, menus, HUD, input de toque, configurações, ciclo de vida e máquina de estados.
- **Flutter Scene:** scene graph, renderização 3D, modelos glTF/GLB, materiais, câmera, animação esquelética, partículas e recursos de cena.
- **Dart:** FSM de bots/minions, regras de partida, navegação de alto nível e orquestração do gameplay.
- **Asset pipeline Flutter Scene:** conversão dos modelos e materiais incluídos no APK para recursos pré-processados.

Versão fixada: flutter_scene 0.24.3. Requer Flutter 3.47 stable ou superior e Dart 3.10 ou superior. O pacote está em versão 0.x; atualizações serão explícitas e protegidas por CI.

## Política gráfica mobile

O Projeto Arena não usará sombras dinâmicas. A iluminação visual será construída com materiais PBR e mapas de ambiente controlados, cores de vértice, texturas, materiais emissivos e iluminação baked nos próprios assets quando necessário.

Não adicionar luzes com shadow casting, cascatas de sombra ou mapas de sombra em runtime. Ausência de sombras não significa remover iluminação, volume, contraste, materiais ou profundidade.

Metas de produção:
- 30 FPS sustentados como piso no Realme C53.
- Perfil gráfico adaptativo para dispositivos mais fracos.
- Orçamento de draw calls, materiais, texturas e entidades por tela.
- LOD, frustum culling, instancing e atlas de materiais onde o conteúdo permitir.
- Limitar transparências e partículas sobrepostas.
- Medir memória GPU, temperatura e estabilidade em sessões longas.

A cena de teste técnica não representa a direção artística final. A arte de produção usará modelos orgânicos, silhuetas legíveis, rigs e animações próprias, não formas primitivas como substitutos de personagens ou cenário.

## Máquina de estados

A implementação principal está em lib/game/state/arena_state_machine.dart.

Fluxo: BOOT → ASSET_VALIDATION → MAIN_MENU → HERO_SELECTION → MATCH_LOADING → IN_MATCH.

Estados laterais: PAUSED, MATCH_RESULT e RECOVERABLE_ERROR.

Regras: a interface envia eventos; transições inválidas são rejeitadas; seleção de herói precisa ser válida; pausa manual não é removida automaticamente pelo lifecycle; recuperação preserva o estágio que precisa ser repetido.

A IA dos bots e minions será implementada em Dart com FSMs determinísticas, desacopladas do scene graph. A lógica de decisão não deve depender de animações ou widgets.

## Integração Flutter Scene

O menu principal usa SceneView.declarative em tela cheia, com o terreno contínuo, vegetação CC0 e um herói animado em primeiro plano; a interface Flutter fica restrita a marca, herói atual e uma ação primária na borda inferior. A câmera faz um deslocamento lateral lento, com pixel ratio 0.85 e teto de 30 FPS. A cena reutiliza os GLBs e o catálogo de posicionamento existentes, sem adicionar dependências ou sombras dinâmicas.

**Hub principal:** `tool/prepare_menu_hub.py` gera `assets/world/arena_menu_hub.glb` no build. O modelo contém a Torre do Firmamento como marco central, ilha suspensa, mar magenta, portal luminoso, anéis quebrados, fragmentos e nuvens. É uma composição original do Projeto Arena; não reutiliza a ilustração de loading nem o cenário de seleção de heróis. A cena é montada por `SceneView.declarative`, com pixel ratio 0.85, câmera de deriva lenta e limite de 30 FPS. Os controles Flutter ficam nas bordas: Heróis abre a sub-tela existente, Ascender entra na prévia atual, e Baús/Desafios/Mercador permanecem bloqueados até a implementação dos respectivos sistemas. Esses limites são metas de configuração, não medições no Realme C53.

A primeira integração de conteúdo usa SceneModel para apresentar os três heróis CC0 já existentes, com os clips Idle originais: Female_Idle para Lyra/Kairo e Man_Idle para Bastion. A inicialização estática acontece no bootstrap antes da validação do manifesto e de qualquer SceneView; falhas entram na recuperação e podem ser tentadas novamente. A seleção troca o GLB sem reconstruir a aplicação. Isso ainda precisa de validação em dispositivo.

O mapa Vale das Coroas foi ampliado para 120 × 84 unidades e usa um super-retângulo orgânico de expoente 5.2, em vez do footprint oval anterior. O terreno tem três rotas longitudinais, rio diagonal em S, três pontes, bases opostas, quatro acessos laterais abertos e pátios percorríveis. Não há acampamentos neutros nem loop de coleta. A malha GLB é gerada offline com mapas de grama, musgo, solo, rocha, margens e água; 30 árvores e 12 arbustos CC0 são posicionados no perímetro, deixando os acessos laterais livres. SceneModel reutiliza recursos cacheados.

A navegação do jogador usa o mesmo catálogo geométrico do terreno: respeita os limites do mapa, bloqueia o canal fora das três pontes e considera colisões de troncos e footprints das torres. A altura de navegação sobre pontes é calculada pela elevação do deck, mantendo heróis, bots e minions no nível visual correto.

MATCH_LOADING cria uma sessão da simulação MOBA e abre MobaMatchView: terreno, herói, bots, minions, torres, bases, HUD touch e minimapa. A câmera é uma perspectiva de ação baixa e traseira, suavizada e orientada pela direção de movimento; a câmera não tenta mostrar o mapa inteiro durante o combate. O minimapa preserva a leitura macro das três rotas. O teto de renderização é 30 FPS, mas FPS sustentado, temperatura, enquadramento e resposta de toque ainda precisam de teste no Realme C53.


1. Habilitar Flutter GPU no AndroidManifest com io.flutter.embedding.android.EnableFlutterGPU=true.
2. Inicializar Scene.initializeStaticResources() no bootstrap, antes de liberar o menu e montar qualquer SceneView.
3. Executar tool/prepare_world_assets.py para gerar o terreno GLB e decodificar modelos naturais CC0 offline.
4. Pré-processar modelos e materiais incluídos no APK pelo build hook.
5. Reservar importação GLB em runtime para conteúdo dinâmico; assets embarcados usam o pipeline de build.
6. Descartar cenas explicitamente para liberar render targets e texturas.
7. Não liberar uma partida se os assets necessários falharem na validação.

## Identidade Android

Preservar applicationId com.duckdream.projectarena e usar versionCode maior que 65 na próxima APK instalável. Esta fundação usa 1.7.4+66 e minSdk 24, mínimo Android do Flutter atual. O nome instalado e o ícone vetorial são reutilizados da identidade existente do Projeto Arena. Builds de CI devem carregar o mesmo keystore persistente do pipeline Android anterior; a release usa esse keystore em vez de uma chave efêmera do runner. O artefato de teste é ARM64, direcionado ao Realme C53 e aos aparelhos ARM64.

## Critérios de aceite

- flutter analyze e flutter test aprovados.
- Build Android release com Flutter GPU habilitado.
- Cena de teste renderizada em dispositivo Android real.
- GLB de personagem com rig e animações validado em runtime.
- FPS, memória e temperatura medidos no Realme C53.
- APK instalada e executada no dispositivo; compilação isolada não é aceite final.
