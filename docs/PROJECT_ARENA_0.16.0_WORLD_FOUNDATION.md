# Projeto Arena 0.16.0 — Vale das Coroas: fundação compartilhada do mundo

Status: desenvolvimento em branch; não é uma release instalável.

## Objetivo desta etapa

Estabelecer uma fonte nativa única para os dados geométricos que precisam coincidir entre simulação, colisão e renderer. A alteração prepara a reconstrução visual do mapa e elimina listas independentes de posições que já divergiam entre C++ e Kotlin.

## Implementado nesta etapa

- `ArenaWorldDefinition.h` centraliza a função de altura do terreno, eixo do rio, centro das três rotas, profundidade das torres, fortalezas, estruturas de base, paredes, pátios, acampamentos, objetivos, árvores, clareiras e vegetação rasteira.
- `ArenaPhysics.cpp` consome os mesmos pontos canônicos para terreno, árvores, acampamentos, clareiras, objetivos e torres.
- `ArenaSimulation.cpp` consome as mesmas definições para rotas, torres, bases, objetivos, acampamentos e spawns do caçador da selva.
- A ponte JNI exporta uma grade de altura, máscara de limite da ilha, curva amostrada das três rotas e conjuntos de pontos em lotes. O Kotlin interpola terreno/rotas localmente, evitando chamadas JNI por célula ou por frame.
- `ArenaWorldDefinition.kt` armazena a grade uma única vez e fornece interpolação bilinear ao renderer, evitando milhares de chamadas JNI por frame.
- `WorldGlbBuilder.kt` deriva terreno, trilhas, rio, clareiras, objetivos, vegetação, paredes e pátios de base de posições compartilhadas.
- `FilamentGameRenderer.kt` e o minimapa consomem o mesmo traçado de rotas e as mesmas posições de estruturas.
- `ArenaLifeCatalog.kt` posiciona guardiões usando os centros canônicos dos acampamentos.

## Critérios de aceitação

1. O teste nativo confirma que a altura usada pela física é exatamente a função canônica.
2. As três rotas permanecem ordenadas e separadas ao longo do eixo norte-sul.
3. Acampamentos espelhados permanecem simétricos; torres usam o centro da rota e a profundidade definida por time/tier.
4. Os pontos de árvores, clareiras, acampamentos e objetivos usados pela colisão vêm das mesmas tabelas consumidas pelo renderer.
5. O Android compila e o APK passa pela inspeção de pacote, versão e assinatura no CI.
6. Teste visual da malha, movimentação em torno de cada obstáculo, leitura do mapa e desempenho prolongado no Realme C53 continuam pendentes até validação física.

## Limites intencionais

Esta etapa ainda não substitui os modelos arquitetônicos, não muda a silhueta final do vale, não aumenta a área jogável, não cria novas mecânicas de combate e não altera o equilíbrio da partida. Ela remove duplicações de dados para que as próximas etapas possam reconstruir o campo sem separar renderização, simulação e colisão.

## Pesquisa técnica de apoio

- Wild Rift — atualizações de ritmo de partida, ondas, pressão de rota e progressão da selva: https://wildrift.leagueoflegends.com/pt-br/news/game-updates/
- Android Developers — otimização geométrica, LOD, consolidação de malhas e culling: https://developer.android.com/games/optimize/optimization-tips
- Android Developers — adaptação térmica e ajuste de carga gráfica para sessões sustentadas: https://developer.android.com/games/optimize/adpf/best-practices-adpf

Fontes consultadas em 3 de novembro de 2026. Elas fundamentam as restrições de design e desempenho; não representam validação de FPS no aparelho de teste.
