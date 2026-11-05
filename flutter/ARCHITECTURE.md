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

A primeira integração de conteúdo usa SceneModel para apresentar os três heróis CC0 já existentes, com os clips Idle originais: Female_Idle para Lyra/Kairo e Man_Idle para Bastion. A inicialização estática acontece no bootstrap antes da validação do manifesto e de qualquer SceneView; falhas entram na recuperação e podem ser tentadas novamente. A seleção troca o GLB sem reconstruir a aplicação. Isso ainda precisa de validação em dispositivo.

A etapa seguinte gera offline o GLB do Vale das Coroas: heightfield contínuo de baixa densidade, relevo com cristas suaves, canal de rio de largura variável, bandas de margem e mapas albedo/normal de grama, musgo, solo e rocha. Quatro modelos de vegetação Quaternius CC0 são decodificados do conteúdo já versionado, sem baixar nada durante a partida. SceneModel monta as árvores e arbustos a partir de fontes repetidas, compartilhando geometria/texturas cacheadas pelo runtime. O pixel ratio da prévia é 0.9 e o ritmo é limitado a 30 FPS; estes são limites de configuração, não resultados medidos no Realme C53.

MATCH_LOADING apresenta somente uma prévia ambiental rotulada como SEM GAMEPLAY. Não é uma partida: navegação, unidades, bots, objetivos, HUD e combate ainda não foram migrados para Flutter Scene.


1. Habilitar Flutter GPU no AndroidManifest com io.flutter.embedding.android.EnableFlutterGPU=true.
2. Inicializar Scene.initializeStaticResources() no bootstrap, antes de liberar o menu e montar qualquer SceneView.
3. Executar tool/prepare_world_assets.py para gerar o terreno GLB e decodificar modelos naturais CC0 offline.
4. Pré-processar modelos e materiais incluídos no APK pelo build hook.
5. Reservar importação GLB em runtime para conteúdo dinâmico; assets embarcados usam o pipeline de build.
6. Descartar cenas explicitamente para liberar render targets e texturas.
7. Não liberar uma partida se os assets necessários falharem na validação.

## Identidade Android

Preservar applicationId com.duckdream.projectarena e usar versionCode maior que 59 na próxima APK instalável. Esta fundação usa 0.17.0+60 e minSdk 24, mínimo Android do Flutter atual. O nome instalado e o ícone vetorial são reutilizados da identidade existente do Projeto Arena. Builds de CI devem carregar o mesmo keystore persistente do pipeline Android anterior; a release usa esse keystore em vez de uma chave efêmera do runner. O artefato de teste é ARM64, direcionado ao Realme C53 e aos aparelhos ARM64.

## Critérios de aceite

- flutter analyze e flutter test aprovados.
- Build Android release com Flutter GPU habilitado.
- Cena de teste renderizada em dispositivo Android real.
- GLB de personagem com rig e animações validado em runtime.
- FPS, memória e temperatura medidos no Realme C53.
- APK instalada e executada no dispositivo; compilação isolada não é aceite final.
