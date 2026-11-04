# Projeto Arena 1.7.0 — Fundação do novo mapa

**Status:** aprovado para reconstrução; especificação inicial em branch isolada.  
**Branch:** `rebuild/project-arena-1.7.0-world-foundation`  
**Baseline:** `main` em `777f05be020cc0d11082d0c827c0c621087e856f`  
**Não é uma implementação concluída nem uma autorização para reutilizar o mapa legado.**

## 1. Decisão de produto

A versão 1.7.0 começa pela substituição integral do mapa. O cenário da 0.16.0 é apenas referência histórica e não pode ser a base geométrica da nova arena.

A entrega precisa ser reconhecivelmente um MOBA 3D amplo: espaço entre rotas para rotações, áreas de selva navegáveis, campos de visão variados, travessias, mudanças de elevação e objetivos com espaço de aproximação. O mapa não pode parecer um pequeno tabuleiro com três faixas pintadas.

A direção visual aprovada para planejamento é **fantasia medieval estilizada, natural e orgânica**, com fortalezas, ruínas, pedra desgastada, caminhos de terra e pedra, vegetação de formas variadas, água com margens naturais e relevo contínuo. Não usar formas primitivas repetidas como substituto de cenário final.

## 2. Escala: requisito eliminatório

### Baseline medido no código atual

O mapa 0.16.0 declara `kHalfExtentX = 35`, `kHalfExtentZ = 31` e `kWorldScale = 1.15` em `ArenaMapDefinition.h`.

Isso equivale a aproximadamente **80,5 m × 71,3 m** de envelope, ou **5.740 m²**.

### Alvo de projeto para a nova arena

- Envelope útil inicial: **180 m × 160 m**.
- Área de envelope: **28.800 m²**, aproximadamente **5 vezes a área** do mapa legado.
- Dimensões lineares: aproximadamente **2,24 vezes maiores** em cada eixo.
- Limites visuais orgânicos: o envelope não deve aparecer como uma caixa ou retângulo rígido.
- A escala final será validada com tempo de rotação, leitura de câmera, duração de deslocamento e densidade das lutas — não apenas pela dimensão declarada.

A nova definição trabalha em metros como unidade canônica. Não ampliar o cenário antigo por multiplicação de escala: terreno, rotas, alturas, distâncias, estruturas, colisores e navegação serão redesenhados em conjunto.

## 3. Macro-layout proposto

A arena terá duas bases em extremos opostos e três rotas que conectam os lados:

1. **Rota oeste:** percurso sinuoso junto a terreno elevado e áreas de floresta; deve oferecer aproximações e pontos de rotação próprios.
2. **Rota central:** caminho principal com leitura visual forte, atravessando o vale fluvial e passando por marcos arquitetônicos.
3. **Rota leste:** percurso com clareiras, ruínas e mudanças de elevação diferentes das outras duas rotas.

Entre as rotas haverá **duas grandes regiões de selva**, cada uma conectada a mais de uma rota. Elas não podem ser áreas decorativas sem passagem: precisam ter caminhos alternativos, clareiras, acampamentos, pontos de encontro e saídas legíveis.

Um rio sinuoso cruza a arena e participa da navegação. Haverá três travessias principais alinhadas às rotas, além de margens, áreas rasas, bancos de pedra e desníveis coerentes com o terreno. As travessias não serão retângulos brancos colocados sobre uma superfície.

As bases terão silhuetas arquitetônicas próprias, pátios, acessos legíveis e aproximações graduais. O perímetro do mundo será formado por cristas, encostas, rochas e vegetação, sem bordas quadradas visíveis.

### Distribuição espacial inicial (alvos, a testar)

| Elemento | Alvo inicial |
|---|---:|
| Rotas principais | 3 |
| Regiões de selva | 2 |
| Travessias principais do rio | 3 |
| Bases | 2 |
| Torres | 18 (3 por rota, por equipe) |
| Acampamentos neutros | 10–12 |
| Objetivos neutros principais | 2 |
| Equipes | 5v5 offline |

A disposição exata dos acampamentos e objetivos será decidida por testes de distância, rota e tempo de contestação, não por simetria automática.

## 4. Regras de arte: o que não pode voltar

### Proibido como solução visual final

- Terreno composto por grandes planos pretos ou ciano.
- Três fitas geométricas de cor uniforme usadas como estradas.
- Rio representado por uma faixa reta e plana.
- Rochas, árvores, torres ou ruínas construídas visualmente com caixas, cones ou esferas repetidas.
- Fortificações idênticas, repetidas sem composição ou variação de silhueta.
- Vegetação usada como pontos verdes isolados, sem volume, distribuição e relação com o terreno.
- Texturas PBR aplicadas sobre a mesma geometria antiga para declarar o mapa reconstruído.

### Direção visual obrigatória

- Relevo contínuo com encostas, depressões, cristas e transições suaves; terreno e margens do rio precisam formar uma única paisagem.
- Caminhos com largura variável, bordas irregulares e mistura de materiais.
- Água com largura e profundidade visual variáveis, margens naturais e travessias construídas no relevo.
- Arquitetura com silhuetas legíveis, volumes, telhados, arcos, contrafortes, pontes e ruínas que pertençam ao mesmo universo artístico.
- Vegetação em grupos e massas orgânicas, com espécies e alturas variadas.
- Paleta equilibrada: grama em tons naturais, terra ocre, pedra neutra, madeira quente e água azul-acinzentada. Verde não pode dominar todos os materiais.
- Iluminação diurna legível e sombras controladas; estruturas e personagens devem permanecer distinguíveis do fundo.

## 5. Fundação técnica: uma única definição do mundo

Criar uma definição canônica do mapa em unidades métricas. Essa fonte será usada para gerar ou alimentar:

- malha de terreno e alturas;
- superfícies de rotas, margens e travessias;
- colisores físicos e limites;
- grafo de navegação e conexões entre áreas;
- posições de bases, torres, acampamentos e objetivos;
- spawns de bots, minions e fauna ambiental;
- câmera, visibilidade e minimapa.

**Não manter coordenadas de gameplay duplicadas e ajustadas manualmente em Kotlin e C++.**

Direção de implementação: arquivo de dados canônico validado no repositório e geração determinística dos dados de Kotlin/C++ no CI. Os testes devem comparar posições, alturas, rotas, larguras, conexões e colisores produzidos a partir da mesma fonte.

O grafo de navegação deve suportar caminhos por rota, rotação pela selva, travessias do rio, rampas e acessos às bases. Um caminho que aparece visualmente precisa ter correspondência na navegação; uma barreira física precisa ser refletida na malha de navegação.

## 6. Fluxo de produção

### Fase A — Planta e topologia
Definir envelope, bases, rotas, selvas, rio, áreas altas/baixas, travessias, objetivos, campamentos e grafo de navegação. Revisar a leitura macro antes de construir o mapa completo.

### Fase B — Greybox integral (uso interno)
Construir o mapa inteiro com volumes provisórios apenas para verificar escala, distâncias, colisões, câmera, navegação e tempos de rotação. Greybox não é entrega visual, não é versão candidata a APK e não pode ser confundido com a arte aprovada.

### Fase C — Fatia visual representativa
Produzir uma área real, não primitiva, contendo um trecho de rota, selva, rio/margem, travessia, estrutura e variação de elevação. Usar assets com licença verificada, materiais coerentes e otimização mobile. Validar no aparelho antes de propagar o estilo.

### Fase D — Construção do mapa completo
Aplicar a direção aprovada a todo o terreno, bases, rotas, selvas, rio, estruturas e marcos. Remover a geometria provisória do runtime final.

### Fase E — Testes de mundo
Testar deslocamento manual, câmera, obstáculos, encostas, acessos, bots, minions, rotas alternativas, acampamentos, travessias e minimapa. Só depois reencaixar os kits de heróis e o balanceamento final.

## 7. Pipeline de assets e limites mobile

- Priorizar packs CC0 cuja licença da página do pack e do arquivo baixado seja verificada individualmente.
- Arquivar URL de origem, data, versão/pacote, licença e SHA-256 por lote.
- Usar GLB/glTF otimizado para o runtime Filament existente; conversão e atlas são offline.
- Reutilizar materiais e instâncias quando forem realmente o mesmo objeto; não reutilizar um único modelo de árvore/rocha como se cobrisse toda a diversidade do mapa.
- Implementar LOD por distância, culling por área, agrupamento de malhas estáticas e limites para folhagem transparente.
- Separar malhas de renderização e colisores simples, mas gerar ambos a partir dos mesmos pontos de colocação e transformações.
- Preservar modo offline. Nenhum asset pode depender de download durante a partida.
- Validar primeiro no Realme C53. Meta mínima de projeto: 30 FPS sustentados, sem travamentos recorrentes ou degradação térmica em sessão prolongada. A meta precisa ser medida, não inferida do CI.

## 8. Critérios de aceite do mapa

O mapa só passa para a fase de personagens/combate quando:

1. Seu envelope útil for 180 m × 160 m, sujeito apenas a ajuste documentado por teste real.
2. A arena oferecer cerca de cinco vezes a área do mapa legado.
3. As três rotas forem longas, distintas e conectadas às duas regiões de selva.
4. O rio, suas três travessias e as margens fizerem parte do mesmo relevo.
5. Existirem caminhos alternativos que conectem selva, rotas e objetivos.
6. Bases e estruturas estiverem posicionadas em espaços com aproximações e leitura de combate.
7. Movimento, câmera, colisão, navegação e minimapa concordarem sobre o mundo.
8. O mapa final não depender de fitas de cor, caixas, cones ou esferas como substitutos da arte ambiental.
9. A fatia visual e depois o mapa completo apresentarem terreno, água, vegetação e arquitetura coerentes.
10. O perfil mobile for medido no Realme C53 antes de declarar o mapa aprovado.

## 9. Fora de escopo até a aprovação do mapa

- Criar novos heróis ou substituir os modelos de Lyra, Bastion e Kairo.
- Refazer kits e habilidades.
- Expandir IA de combate ou balanceamento.
- Publicar APK da 1.7.0.

Esses sistemas não serão reescritos para acomodar coordenadas antigas. Serão conectados à nova definição do mundo depois que o mapa passar pelos critérios acima.

## 10. Referências de design consultadas

- Valve / Deadlock, **Map Rework Update** (25 Feb 2025): a reformulação alterou de quatro para três rotas e acompanhou a mudança com revisão de edifícios, caminhos, acampamentos e outros elementos do mapa. Também introduziu uma forma de explorar o mapa vazio para testar movimento e navegação. https://deadlock.io/en/patches/map-rework-update-2025-02-25-1792116353369036
- Valve / Deadlock, **City Never Sleeps** (29 Sep 2026): grande atualização visual do mapa e dos neutros; também cita melhorias de desempenho de renderização. https://deadlock.io/en/patches/city-never-sleeps-2026-09-29-steam-community-announcements-1844751498235383
- Epic Games, **Performance and Optimization for Mobile in Unreal Engine**: orientação de que renderização mobile exige escolhas específicas e modelos simplificados/performance-aware para recursos como sombras e texturas. Usado apenas como referência geral de otimização; o projeto continua em Kotlin/C++/Filament e não migra para Unreal. https://dev.epicgames.com/documentation/unreal-engine/performance-and-optimization-for-mobile-in-unreal-engine?lang=en-US

## 11. Estado honesto

Esta documentação registra a decisão de arquitetura e os critérios aprovados para começar. Não declara que o novo mapa, os assets, a navegação, a física ou o APK da 1.7.0 já foram implementados ou testados.


## 12. Plano tecnológico persistente

A estratégia de evolução tecnológica, stack aprovada, referências e ordem de implementação estão registradas em [PROJECT_ARENA_1.7.0_TECHNOLOGY_ROADMAP.md](PROJECT_ARENA_1.7.0_TECHNOLOGY_ROADMAP.md). A fonte inicial do novo mundo está em [world/arena_world_1_7.json](../world/arena_world_1_7.json), validada por [verify_arena_world.py](../tools/verify_arena_world.py).
