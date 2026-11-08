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

## Integração Flutter Scene e divisão 2D/3D

A arquitetura visual está separada por contexto:

- **Menu principal:** fundo estático em 2D, desenhado por `ArenaMainMenuScene` com `CustomPaint` e isolado por `RepaintBoundary`. Não instancia `SceneView`, não carrega GLBs e não cria o mapa de batalha.
- **Gameplay:** campo urbano, personagens, entidades, estruturas e câmera permanecem em 3D usando Flutter Scene.
- **Seleção de heróis:** mantém uma prévia 3D independente; ela não transforma o menu principal em uma cena 3D.

O fundo do menu desenha a silhueta da torre de comando, skyline, atmosfera e primeiro plano diretamente no canvas. Não existe dependência de `arena_menu_hub.glb` no caminho de inicialização do menu. Isso mantém o menu leve e evita carregar recursos da partida antes de iniciar o gameplay.

O CI de release valida explicitamente que o APK não contenha o antigo GLB do hub nem a cena Flutter Scene pré-processada correspondente. A presença de modelos 3D no APK é reservada à gameplay.

A primeira integração de conteúdo usa SceneModel para apresentar os três heróis CC0 já existentes, com os clips Idle originais: Female_Idle para Lyra e Man_Idle para Bastion/Kairo. A inicialização estática acontece no bootstrap antes da validação do manifesto e de qualquer SceneView; falhas entram na recuperação e podem ser tentadas novamente. A seleção troca o GLB sem reconstruir a aplicação. Isso ainda precisa de validação em dispositivo.

A base urbana atual (1.8.0) usa um campo lógico irregular de 224 × 188 unidades com seis distritos, três avenidas, cinco travessias do canal, seis interiores e duas rotas elevadas. O terreno mantém uma malha contínua com superfícies elevadas de asfalto e calçada. Os assets de cenário Kenney CC0 são preparados offline e o catálogo de mundo é compartilhado entre renderer, navegação e colisão Rapier. A composição artística dos seis distritos continua em evolução por gates; a primeira vertical slice visual é o Mercado Central.

A câmera usa pointer tracking independente na zona central/direita. O joystick esquerdo altera apenas o vetor de movimento; o ponteiro direito altera yaw e pitch. Follow distance 9.4, look-ahead 3.0, pitch inicial 0.34 rad e FOV vertical 49°. Estes são parâmetros de configuração, não medições de enquadramento ou desempenho.

A auditoria de Kairo confirmou que o GLB legado na branch antiga continha clipes Female. O pipeline agora baixa um segundo modelo masculino distinto do Quaternius Animated Men Pack (Man-fjHyMd5Wxw, CC0), aplica paleta própria, exige Man_Idle/Man_Walk/Man_SwordSlash e o verificador inspeciona o GLB efetivamente empacotado no APK. O seletor e a partida usam Man_Idle/Man_Walk para Kairo. A inspeção visual final do modelo ainda depende de execução no Realme C53.

O ataque básico aciona o clipe SwordSlash e usa alcance/intervalo específicos por herói. A revisão 1.7.6 importa três espadas CC0 distintas e as anexa ao nó `Palm.R` dos rigs Lyra, Bastion e Kairo. `HeroWeaponSocket` mantém um Future por variante, importa cada template uma vez e clona o grafo para heróis e bots; a arma acompanha as animações do osso da mão. O pipeline verifica hashes de origem e exige `Palm.R` nos três modelos. A seleção touch de alvo, HUD contextual e confirmação de acerto foram adicionadas na 1.7.7; efeitos de impacto específicos por classe e inspeção visual no aparelho continuam pendentes.

O catálogo urbano adiciona dois mezaninos em lados opostos. `MobaPoint.elevation`, `resolveNavigationElevation` e `isWalkable(elevation:)` obrigam a subir pela rampa em passos contínuos e mantêm entidades em pisos diferentes fora de alcance umas das outras. O objetivo é manter um só mapa de navegação e um orçamento de entidades adequado ao mobile.

As duas entradas dos mezaninos têm coberturas destrutíveis com HP, dano por ataque básico e remoção da colisão quando destruídas. O reator central acompanha presença ponderada de heróis, bots e tropas; disputa simultânea congela a captura. O controle concede 12% de dano à equipe e a primeira captura premia com ouro/XP. Renderização, simulação e HUD usam o mesmo snapshot do objetivo.

1. Habilitar Flutter GPU no AndroidManifest com io.flutter.embedding.android.EnableFlutterGPU=true.
2. Inicializar Scene.initializeStaticResources() no bootstrap, antes de liberar o menu e montar qualquer SceneView.
3. Executar tool/prepare_world_assets.py para gerar o terreno GLB e decodificar modelos naturais CC0 offline.
3a. Executar tool/prepare_weapon_assets.py para buscar e validar as espadas CC0 por hash.
4. Pré-processar modelos e materiais incluídos no APK pelo build hook.
5. Reservar importação GLB em runtime para conteúdo dinâmico; assets embarcados usam o pipeline de build.
6. Descartar cenas explicitamente para liberar render targets e texturas.
7. Não liberar uma partida se os assets necessários falharem na validação.

## Identidade Android

Preservar o applicationId `com.duckdream.projectarena`. A release 1.8.0 usa `versionName` 1.8.0 e `versionCode` 73, com `minSdk` 24 e ABI ARM64. O nome instalado e o ícone vetorial são reutilizados da identidade existente do Projeto Arena. Builds de release confiáveis na branch `main` carregam o mesmo keystore persistente do pipeline Android anterior; branches de desenvolvimento e PRs não recebem essa chave. O APK deve atualizar a instalação existente, sem exigir desinstalação. A validação visual e o teste prolongado de desempenho continuam sendo feitos no Realme C53.

## Critérios de aceite

- flutter analyze e flutter test aprovados.
- Build Android release com Flutter GPU habilitado.
- Cena de teste renderizada em dispositivo Android real.
- GLB de personagem com rig e animações validado em runtime.
- FPS, memória e temperatura medidos no Realme C53.
- APK instalada e executada no dispositivo; compilação isolada não é aceite final.


## Fundação de sessões Online e Rede Local (v1.8.3, em validação)

A camada de rede está isolada em lib/network/ e acessada por uma tela independente em lib/app/arena_network_lobby_screen.dart.

- Online: supabase_flutter 2.18.x, autenticação anônima e Supabase Realtime Presence em canais privados.
- LAN: ServerSocket/Socket TCP, host no aparelho, conexão manual por IPv4 + porta e token aleatório de 128 bits.
- Escopo de presença: nome exibido e roster de sala. Nenhum estado de combate é transmitido.
- Credenciais: URL e publishable key do projeto são configuração de cliente; service_role e credenciais administrativas nunca entram no APK.
- RLS: políticas dedicadas a tópicos arena:lobby:% em realtime.messages; canais são criados como privados.
- Android: INTERNET é incluída pelo gerador de host. targetSdk=36 evita antecipar a permissão específica de API 37. Qualquer subida futura para target 37 precisa implementar o fluxo runtime de ACCESS_LOCAL_NETWORK documentado pelo Flutter/Android.
- Offline-first: inicialização Supabase é lazy e só ocorre quando o usuário abre/cria/entra numa sala. Falhas de autenticação/rede não impedem a inicialização do jogo offline.

Esta entrega é uma fundação de lobby e presença, não multiplayer de partida. O runtime 3D, movimento, objetivos e toda a simulação permanecem locais até uma revisão separada com critérios próprios. Antes de avançar: testar duas instalações reais na mesma LAN, reconexão, host encerrado, redes diferentes e políticas RLS com sessões convidadas.
