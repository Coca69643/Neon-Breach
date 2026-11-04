# Projeto Arena 1.7.0 — Plano de Evolução Tecnológica

**Status:** plano persistente de engenharia; evolução iniciada na branch isolada.  
**Branch de trabalho:** rebuild/project-arena-1.7.0-world-foundation  
**Versão-alvo:** 1.7.0  
**Data da pesquisa:** 4 de novembro de 2026.

Este documento é a referência técnica durável da evolução 1.7.0. Mudanças futuras devem consultá-lo e atualizá-lo quando uma decisão de arquitetura mudar. Não substituir este plano por listas de funcionalidades desconectadas.

## Princípios não negociáveis

1. Preservar Kotlin + Android, C++20/NDK, Filament e glTF/GLB como stack principal. Não migrar de engine por conveniência.
2. Reconstruir o mapa primeiro. O cenário legado não é fundação geométrica nem fonte de coordenadas da nova arena.
3. Uma definição espacial canônica alimenta renderização, física, navegação, minimapa, spawns e objetivos. Não manter coordenadas duplicadas manualmente em Kotlin e C++.
4. A arena nova tem envelope inicial de 180 × 160 metros (28.800 m²), cerca de cinco vezes a área do envelope legado de 80,5 × 71,3 m. Escala deve ser validada por leitura, rotação, distâncias e tempos de deslocamento.
5. A arte final deve usar terreno orgânico, elevação, arquitetura, vegetação e materiais coerentes. Caixas, cones, esferas e faixas planas não podem substituir a arte ambiental final.
6. Offline-first. Assets, shaders e conversões são preparados antes da execução; não depender de downloads durante a partida.
7. Realme C53 é o aparelho de referência. Metas de FPS, temperatura, memória e estabilidade exigem medição física, não podem ser inferidas de uma compilação.
8. Não declarar feature concluída até passar pelos critérios de aceite e pelos testes correspondentes.

## Stack confirmada no repositório

- Android/Kotlin: interface, ciclo de vida, input, apresentação e integração.
- C++20/NDK: simulação, física, combate e IA.
- JNI: fronteira controlada entre aplicação e simulação.
- Google Filament 1.77.3: renderização PBR, backend Vulkan com fallback OpenGL ES, sombras, SSAO, fog e resolução dinâmica já configurados.
- gltfio / glTF 2.0: carregamento de GLB, malhas, materiais e animação esquelética.
- Python: pipeline offline de assets, geração e validação.
- Gradle/CMake/GitHub Actions: compilação Android, testes nativos e verificações.

A existência de um recurso na documentação upstream não garante que esteja disponível, configurado ou habilitado na versão 1.77.3 instalada. Toda atualização de Filament ou adoção de extensão glTF deve ter teste de compatibilidade próprio.

## Plano por sistemas

### 1. World Pipeline 2.0 — prioridade absoluta

**Objetivo:** uma fonte de verdade para a arena.

- Criar definição de mundo versionada em JSON, com unidades métricas explícitas.
- Definir envelope, três rotas, bases, rio, travessias, duas regiões de selva, acampamentos, objetivos, alturas e topologia de navegação.
- Validar topologia, limites, interseções de rotas, travessias, conectividade e escalas no CI.
- Gerar representações Kotlin e C++ a partir da fonte canônica; artefatos gerados não devem ser editados manualmente.
- Gerar terreno, geometria de caminhos, margens, colisores e minimapa a partir dos mesmos dados.
- Separar render mesh de collision proxy, mantendo posição, escala e sockets sincronizados.
- Usar greybox integral apenas para teste interno de proporção e navegação; removê-lo do mapa final.

### 2. Environment Rendering 2.0

- Construir terreno contínuo com heightfield, cristas, vales, encostas e margens de rio.
- Usar modelos GLB autorais ou assets CC0 cuja licença exata esteja verificada.
- Preparar materiais PBR distintos para grama, terra, rocha, pedra trabalhada, madeira, água e vegetação.
- Evoluir o pipeline de texturas para KTX2/Basis Universal e mipmaps após validar o suporte da versão pinned.
- Avaliar EXT_meshopt_compression e KHR_draco_mesh_compression com arquivos de teste no gltfio Android.
- Implementar LOD, frustum culling, distance culling, instancing e agrupamento de malhas estáticas.
- Implementar setores do mundo e carregamento/ativação controlada; a decisão de streaming depende do orçamento real de memória.
- Criar shaders Filament próprios para água, materiais ambientais e vento na vegetação, compilados offline com a versão correspondente do matc.
- Tratar bloom, SSR, refração e técnicas de sombra mais caras como opções condicionadas à medição no aparelho.

### 3. World Interaction 2.0

- Navegação estratégica por grafo de regiões: bases, rotas, selvas, travessias e objetivos.
- A* para decisões de rota e deslocamento de heróis/bots.
- Flow Fields para grupos de minions que compartilham destino, com resolução espacial e orçamento de atualização controlados.
- Steering local, separação física e consultas espaciais para reduzir congestionamento.
- Física, relevo, colisores e navegação derivados da mesma definição.
- Testar toda ligação visual de caminho com sua correspondente navegável.

### 4. Character & Ability Framework

Começar após aprovação do mapa.

- Modelos independentes para heróis jogáveis, bots e famílias de minions.
- Pipeline GLB para rig, clips, materiais, escala, pivôs e validação.
- Registry de habilidades com estado, alvo, cooldown, interrupção, status effects e eventos de animação.
- Efeitos visuais ligados à execução real da habilidade; não usar ações genéricas renomeadas.
- Pooling de efeitos e objetos temporários para reduzir alocações em gameplay.

### 5. Mobile Performance Framework

- Medir frame time de CPU/GPU, memória, draw calls e custo por setor.
- Investigar Android Dynamic Performance Framework (ADPF) / PerformanceHintManager para reportar duração de trabalho de grupos de threads.
- Consultar Thermal API de forma controlada; a documentação alerta para não consultar thermal headroom mais de uma vez a cada 10 segundos.
- Definir perfis gráficos e degradação progressiva: resolução interna, sombras, distância de vegetação e efeitos.
- Avaliar Android Frame Pacing / Swappy apenas após mapear o ciclo atual de renderização do Filament; evitar dois sistemas concorrendo pelo pacing.
- Usar Perfetto e Android Performance Analyzer para localizar gargalos.
- Meta inicial: 30 FPS sustentados no Realme C53 em sessão prolongada, com ausência de travamentos recorrentes e degradação térmica; resultado depende de teste físico.

## Atualização do Filament

O projeto permanece fixado em 1.77.3 enquanto uma branch de compatibilidade avalia a versão upstream 1.80.1.

Verificar:
- inicialização Vulkan e fallback OpenGL ES;
- carregamento GLB, texturas e clips;
- materiais e shaders compilados;
- sombras e resolução dinâmica;
- estabilidade de ciclo de vida e recriação do Surface;
- tempo de frame, memória e comportamento térmico no aparelho.

Não atualizar dependências do runtime sem atualizar as ferramentas de shader correspondentes, validar APIs e executar a bateria de regressão. Não misturar a atualização do renderer com a primeira implementação do mapa.

## Ordem de execução

1. **World Pipeline 2.0:** definição canônica, validação e geração Kotlin/C++.
2. **Mapa greybox integral:** escala, rotas, navegação, câmera, física e objetivos.
3. **Fatia ambiental final:** uma região real com terreno, caminho, selva, rio, travessia, arquitetura e vegetação.
4. **Mapa completo:** produção de assets, materiais, LOD e setores.
5. **Character & Ability Framework:** elenco e combate sobre o mapa aprovado.
6. **Mobile Performance Framework:** instrumentação, perfis e otimização.
7. **Release 1.7.0:** build, inspeção de APK, smoke tests e validação física.

## Referências técnicas primárias

- Filament repository, releases, Android libraries, rendering features e gltfio: https://github.com/google/filament
- Filament Materials Guide: https://google.github.io/filament/Materials.html
- Filament gltfio / KTX2 provider: https://google.github.io/filament/gltfio.html
- Filament AssetLoader API: https://github.com/google/filament/blob/main/libs/gltfio/include/gltfio/AssetLoader.h
- Android Dynamic Performance Framework: https://developer.android.com/games/optimize/adpf
- Android Thermal API: https://developer.android.com/games/optimize/adpf/thermal
- Android Performance Hint NDK API: https://developer.android.com/ndk/reference/group/a-performance-hint
- Android Frame Pacing / Swappy: https://developer.android.com/games/sdk/frame-pacing
- Khronos glTF 2.0 specification: https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html
- Blender glTF exporter documentation: https://docs.blender.org/manual/en/latest/addons/import_export/scene_gltf2.html
- Efficient Crowd Simulation for Mobile Games (Game AI Pro): http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter24_Efficient_Crowd_Simulation_for_Mobile_Games.pdf
- Flow Field Pathfinding for Tower Defense: https://www.redblobgames.com/pathfinding/tower-defense/
- Android Performance Analyzer: https://developer.android.com/games/optimize

## Registro de implementação

### 2026-11-04 — Correção de orientação do joystick
- Identificado o desalinhamento entre o eixo X do mundo e o eixo horizontal da câmera fixa (câmera em -Z olhando para +Z).
- Criado ArenaMovementInput para converter o vetor do joystick em coordenadas de mundo: esquerda/direita e frente/trás alinhados à tela.
- Movimento e dash usam a mesma conversão.
- Adicionados testes unitários para quatro direções cardinais, diagonal e sensibilidade; validador estrutural verifica integração e contrato de eixos.
- CI específico da correção ainda precisa concluir antes de declarar a correção validada em build. Teste físico ainda requer aparelho.

### 2026-11-04 — World Pipeline 2.0, etapa inicial
- Branch isolada criada a partir da main: rebuild/project-arena-1.7.0-world-foundation.
- Especificação da fundação do mapa registrada em docs/PROJECT_ARENA_1.7.0_WORLD_FOUNDATION.md.
- Fonte canônica world/arena_world_1_7.json e validador tools/verify_arena_world.py foram adicionados; o workflow Android executa a validação.
- Validador executado com sucesso no GitHub Actions, run 41894611911: envelope, três rotas, três pontes, duas selvas, doze acampamentos e grafo conectado aprovados.
- Escopo implementado nesta etapa: fonte de dados + validação estrutural. O JSON ainda não alimenta o renderer/física ativos; geração Kotlin/C++ e integração runtime são os próximos passos. O mapa ativo 0.16.0 permanece intacto.


### 2026-11-04 — Auditoria do runtime visual da arena
- Auditoria concluída em `docs/PROJECT_ARENA_1.7.0_RUNTIME_VISUAL_AUDIT.md`.
- Confirmado: o runtime ainda chama `WorldGlbBuilder.build()` usando `ArenaMapDefinition.kt` e o espelho C++ `ArenaMapDefinition.h`, ambos com a escala antiga de 35 × 31 m e `WORLD_SCALE = 1.15`.
- Confirmado: castelos, torres, casas, igrejas, pontes, vegetação e GLBs de groundcover/rochas já existem, mas suas posições e o bake ambiental ainda usam as coordenadas do mapa 0.16.0.
- O terreno ativo ainda usa o antigo recorte de ilha e malha de 76 × 76 m; a nova fonte JSON de 180 × 160 m não é consumida pelo renderer, colisão ou simulação.
- Run CI `41901296794` concluiu com sucesso: pipeline de assets, validação estrutural do JSON, testes nativos, validação do projeto, testes Gradle e compilação Android. O APK foi identificado como **0.16.0**; isso não prova a integração ou aparência visual do mundo 1.7.0.
- Status corrigido: **fundação do mundo 1.7.0 ainda não integrada ao runtime; aceite visual bloqueado**. Próximo passo obrigatório: geração Kotlin/C++ a partir da fonte canônica e substituição da geometria/posicionamentos legados antes de declarar a arena orgânica e completa. A `main` permanece inalterada.


### 2026-11-04 — World contract generation and identity research
- Pesquisa de identidade registrada em `docs/PROJECT_ARENA_GAMEPLAY_IDENTITY_LIVING_TERRITORY.md`, baseada em notas oficiais de Deadlock, Dota 2, visão mobile do Wild Rift e sessão GDC sobre níveis com vida sistêmica.
- Direção proposta: **Território Vivo** — ecologia ativa, campo de batalha reativo, regiões com personalidade e objetivos que criam escolhas estratégicas. O ciclo experimental Territory Pulse permanece proposta futura, não feature implementada.
- Criado `tools/generate_arena_world_17.py`: gera contratos tipados Kotlin e C++ a partir de `world/arena_world_1_7.json`.
- Criados `ArenaWorld17Generated.kt` e `ArenaWorld17Generated.h`, incluindo limites 180 × 160 m, relevo, controles de elevação, bases, três rotas, rio de 13 pontos, três travessias, duas selvas, doze camps, dois objetivos e grafo de navegação.
- CI agora executa o gerador e exige que os arquivos gerados permaneçam idênticos ao resultado do JSON canônico; adicionados testes Kotlin e C++ para o contrato gerado.
- **Limite desta etapa:** o novo contrato está gerado e testado em isolamento; renderer, física e navegação ativos ainda usam o catálogo 0.16.0. Não declarar a nova arena integrada até a migração de todos os consumidores e validação visual no aparelho.
