# Project Arena — feedback crítico pós-v1.8.0

Registro permanente de requisitos e defeitos apontados pelo jogador nas capturas da v1.8.0 (07/11/2026). Este documento deve ser atualizado ao longo da correção e permanecer no histórico do projeto.

## Regra de trabalho

- Toda correção começa em branch separada; `main` e a release v1.8.0 permanecem intactas.
- CI verde valida somente o que os testes realmente executam. Aprovação visual, comportamento de gameplay e desempenho no Realme C53 exigem evidência própria.
- Não gerar APK de atualização nem publicar versão até os critérios correspondentes serem aprovados.
- Não marcar como resolvido apenas porque existe código, asset, teste de string ou build compilado.

## Problemas reportados

### P0 — Movimento, orientação e escala das unidades
- Heróis, bots e tropas aparentam caminhar de costas (moonwalk).
- Minions continuam pequenos e uma unidade aparece visualmente fora da formação.
- Bots/minions reutilizam os mesmos personagens e não têm hierarquia visual suficientemente clara.
- Armas dos heróis ficam desproporcionais ou desalinhadas; a espada pode atravessar o piso. O requisito é aplicar o tipo de equipamento adequado e uma transformação de encaixe calibrada por rig, não somente reduzir uma escala global.

### P0 — Integridade visual e física do mapa
- Capturas mostram edifícios ou paredes ocupando vias, fachadas incompletas e estruturas sem proporção convincente.
- Algumas construções aparentam não ter entrada funcional ou o interior não corresponde ao espaço visual.
- Render, navegação e colisão precisam usar a mesma fonte de dimensões, origem, rotação e footprint. Não adicionar fachadas isoladamente sem validar o espaço de circulação.

**Causa de geometria confirmada na auditoria:** os GLBs fixados do Kenney Furniture Pack usam origem no início do segmento (bounds locais X=[0,1], não um pivô central). O renderer estava colocando paredes laterais no centro do eixo Z, deslocando-as 9 unidades para fora da sala; os dois segmentos frontais começavam em offsets centrais, e a moldura da porta também iniciava no centro. Isso não correspondia ao footprint lógico da colisão. A PR corrige os pontos iniciais para os limites reais do cômodo e mantém o vão de porta de 6,4 unidades. Assets verificados no commit CC0 fixado `ea2f2aa1ca8da0898330c97df8a5489976b051d0`: `wall.glb` (blob `ba5b8d2a16bdb6042750d1bef5e7afe78c9b0091`) e `walldoorwaywide.glb` (blob `76c658e0919d2acfd77630efc1851358579a964f`).

### P0 — NPCs de MOBA, não somente pedestres
- Os NPCs atuais são pedestres ambientais com patrulha e diálogo; isso não satisfaz a expectativa de entidades neutras de gameplay de um MOBA.
- A próxima implementação de NPC de gameplay deve ter papel de jogo explícito, presença consistente no mapa, estado/comportamento, interação/combatibilidade, recompensa/objetivo e representação legível no HUD/minimapa.
- Pedestres ambientais podem permanecer como ambientação, mas não devem ser apresentados como substitutos de NPCs neutros de gameplay.

### P1 — Menu e identidade do jogador
- A inspiração em Project R.I.S.E. deve ser de composição e hierarquia visual, sem copiar sua interface ou usar atalhos fictícios.
- Remover atalhos bloqueados sem função real (BAÚS, DESAFIOS, MERCADOR) até os sistemas existirem.
- O cabeçalho deve mostrar nome do jogador e foto de perfil real, com fluxo explícito de criação/edição e persistência local; não deixar o título do jogo no lugar da identidade do jogador.

### P1 — Novo herói e seleção
- O elenco permanece com Lyra, Bastion e Kairo; o novo herói solicitado não está implementado nem selecionável.
- A direção já registrada em `PROJECT_ARENA_HERO_SELECTION.md` é um sintético humanoide original cuja habilidade principal transforma temporariamente sua forma em uma criatura quadrúpede original. A forma-base robótica deve continuar sendo a identidade principal.
- A seleção deve ser ampliada para acomodar espécies e silhuetas distintas sem comprimir o modelo 3D nem deixar o personagem de costas. Catálogo, preview, rig, animações, identidade de gameplay e testes devem ser integrados em conjunto.

### P1 — HUD de partida
- A HUD mostrada nas capturas é genérica e ocupa espaço com placas visuais pouco integradas ao mundo.
- Revisar hierarquia, legibilidade, escala e áreas de toque para landscape mobile. Não remover informação essencial de MOBA (vida, nível, ouro, mapa, alvos, objetivos e ações).

## Critérios observáveis de aceite

### Movimento e unidades
1. Herói, bots e minions acompanham a direção real do deslocamento em oito direções, sem moonwalk, inversão ao mudar de eixo ou rotação instável quando param.
2. Minions são legíveis na distância normal de combate e mantêm escala consistente entre equipe azul/vermelha, classes corpo a corpo/distância e animações.
3. Unidades aparecem em rotas navegáveis, não dentro de edifícios, sob o terreno ou separadas da formação sem objetivo de IA.
4. Testes determinísticos cobrem conversão de direção e lógica de movimentação; inspeção visual confirma o resultado no build.

### Equipamento
1. Cada rig usa socket e transformação próprios (escala, rotação e posição), com pivô preso à mão correta.
2. Equipamento permanece na mão durante idle, locomoção e ação, sem atravessar piso, corpo ou câmera.
3. O catálogo permite armas diferentes por herói; não assumir que todos os heróis usam espadas.
4. Verificação visual por herói e rig antes de marcar como concluído.

### Mapa
1. Nenhuma fachada, parede, poste ou prop invade as faixas de via ou os acessos de combate.
2. Portas, passagens e escadas têm largura compatível com a cápsula do jogador e conectam a um interior realmente navegável.
3. Origem, dimensões e rotação do GLB conferem com o footprint usado pela navegação e pela física.
4. Testes amostram pontos de via, portas, interior, limites e colisão; screenshots de gameplay mostram o cenário completo, sem fachadas incompletas ou objetos flutuantes.
5. O mapa permanece coerente com o orçamento de memória e renderização mobile.

### NPCs de gameplay
1. Existem NPCs neutros com função MOBA definida, distintos dos pedestres ambientais.
2. Eles são encontrados no mundo sem depender de procurar aleatoriamente por um pedestre; o HUD/minimapa indica a presença e o estado.
3. Estado, comportamento, colisão, recompensa, reaparecimento e efeitos de equipe têm testes próprios.
4. Os assets possuem licença CC0 confirmada para o pacote exato, origem/hash fixados e são empacotados offline.

### Menu, perfil, seleção e HUD
1. Menu mantém apresentação full-screen autoral, sem atalhos mortos ou cópia literal de Project R.I.S.E.
2. Nome e foto de perfil do jogador são apresentados e persistidos; a edição é acessível e funciona offline.
3. Seleção mantém previews frontais calibrados por personagem, catálogo extensível por espécie e layout utilizável em landscape.
4. Novo herói só aparece como jogável após rig, animações, habilidade, transformação, balanceamento e testes estarem integrados.
5. HUD é legível em tela mobile landscape, mantém áreas de toque adequadas e comunica os sistemas centrais do MOBA.

## Priorização da branch de recuperação

1. Corrigir e verificar orientação de todos os rigs e escala legível dos minions.
2. Auditar as dimensões/origens dos edifícios e alinhar visual, colisão e navegação antes de expandir o mapa.
3. Definir e implementar NPCs neutros de gameplay (sistemas separados dos pedestres).
4. Corrigir sockets/equipamentos por rig com evidência visual.
5. Reconstruir menu/perfil/HUD e concluir a seleção com o novo herói.

## Estado inicial — 07/11/2026

- [x] Branch separada criada: `fix/1.8.1-feedback-recovery`.
- [x] Auditoria inicial de call paths, pipeline CC0, documentos de arquitetura e testes.
- [x] Orientação de rigs: NPCs, bots e minions agora usam a base local -Z, alinhada ao deslocamento; `flutter analyze` e 86 testes passaram (run 42380337841); inspeção visual ainda pendente.
- [x] Escala de bots, minions e pedestres aumentada de forma controlada; compilação/análise/testes passaram; inspeção visual ainda pendente para confirmar proporção.
- [x] Mapa — interiores: origem dos GLBs de parede/porta auditada; âncoras laterais/frontais/porta alinhadas ao footprint; testes geométricos passaram no run 42380337841; screenshot de jogo ainda pendente.
- [x] Footprints externos: colisores Rapier e navegação agora usam meia-largura, meia-profundidade e altura derivados do GLB de cada uma das dez fachadas; o bake offline valida os limites contra os assets CC0 fixados.
- [ ] Mapa — composição urbana: posicionamento final dos edifícios, afastamento visual das vias, fachadas completas, entradas reais e leitura dos seis distritos ainda exigem screenshots de gameplay; não declarar o mapa completo.
- [x] NPCs de serviço: todos os pedestres/NPCs de cidade recebem marcador de chão/cabeça e pinos móveis no minimapa; o quartermaster foi movido para o Mercado Central.
- [x] Quartermaster funcional: loja em mundo com célula de impacto (+12% poder) e placa reforçada (+100 vida), custos em ouro, bloqueio por proximidade e compras únicas por partida; testes cobrem preço, alcance e efeitos.
- [ ] NPCs neutros de combate/camps (equivalente a jungle camps) ainda não implementados; não confundir o mercador e pedestres com esse sistema.
- [ ] Equipamentos por rig: calibração visual pendente.
- [ ] Perfil real do jogador: não implementado.
- [ ] Novo herói sintético metamórfico: não implementado.
- [ ] HUD e seleção: revisão de UX pendente.
- [ ] Realme C53: sem validação física nesta etapa.

## Validação da etapa seguinte — 07/11/2026

- CI run: [42383763525](https://github.com/Coca69643/Neon-Breach/actions/runs/42383763525), HEAD `0b4915c11702e7170008962fe93204b227829b84`.
- `flutter analyze`: sem issues.
- Testes: 89 aprovados.
- Preparação offline de terreno, cidade, NPCs, heróis e armas: aprovada.
- Os dez GLBs de fachada tiveram bounds conferidos no bake contra o manifesto do código e usam footprint retangular/altura exatos no catálogo e no Rapier.
- Nenhuma etapa de release/APK foi executada por esta PR.
- Inspeção visual de screenshots e validação física no Realme C53 continuam pendentes.

## Fontes internas

- `docs/DEVELOPMENT_PROTOCOL.md`
- `docs/ASSET_PIPELINE_CC0.md`
- `docs/PROJECT_ARENA_HERO_SELECTION.md`
- `docs/PROJECT_ARENA_SCENARIO_GATE.md`
- Capturas de gameplay recebidas em 07/11/2026.
