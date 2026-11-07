# Project Arena — reconstrução integral do mapa CC0

Status: gate de preparação e aquisição. **Nenhuma substituição de mapa foi implementada nesta etapa.**

## Diretriz do usuário

O mapa precisa mudar como espaço jogável, não apenas como composição de props. É explicitamente reprovado:
- distribuir miniaturas de edifícios em um terreno vazio e chamar isso de mapa novo;
- alinhar peças pequenas de rua sem formar uma malha urbana contínua;
- ampliar a escala de uma miniatura isolada para simular um prédio completo;
- usar fachadas como cascas decorativas sem espaço interno transitável;
- aceitar screenshots de editor ou renders isolados no lugar da câmera real da partida.

## Diagnóstico atual confirmado no código

- O mundo lógico atual mede 224 × 188 unidades e mantém seis setores.
- O catálogo contém dez blocos comerciais/residenciais, cada qual referenciando um GLB isolado e uma escala individual.
- Existem seis interiores construídos separadamente com paredes, mobiliário e vãos de entrada.
- Vias, canal, pontes, árvores, fachadas, navegação e colisores já têm uma fundação funcional, mas a composição de superfície ainda não comunica uma cidade completa com silhuetas densas, quarteirões conectados e identidade própria por distrito.
- A auditoria visual final dos edifícios, acessos e proporções continua pendente.

Esses pontos são uma fundação técnica; não equivalem ao aceite visual de um mapa urbano completo.

## Biblioteca CC0 candidata principal

**Quaternius — Downtown City MegaKit**

- Página oficial: https://quaternius.com/packs/downtowncitymegakit.html
- Distribuição do criador: https://quaternius.itch.io/downtown-city-megakit
- A página oficial indica 315 modelos e mais de 300 peças de ambiente.
- O kit é modular e foi anunciado para compor quarteirões urbanos completos, com peças de edifícios e ruas e sete edifícios de exemplo.
- glTF é um dos formatos listados.
- A página indica CC0 e informa que 60–70% do conteúdo está disponível gratuitamente.
- A distribuição padrão gratuita lista o arquivo `Downtown City MegaKit[Standard].zip` com 223 MB.

**Limitação importante:** o criador menciona janelas com interior falso. Isso não atende à exigência de interiores navegáveis. O kit será apenas a base de arquitetura externa/modular; o jogo deverá ter pisos, paredes internas, portas, escadas e espaços reais criados e testados como geometria de gameplay.

A informação da página é pesquisa inicial, não uma licença/arquivo já arquivado no repositório. Antes de importar qualquer modelo, registrar a data de aquisição, URL de origem, nome do arquivo, SHA-256 do ZIP, licença incluída, inventário da versão Standard e SHA-256 dos GLBs selecionados.

## Alvo de reconstrução

### Estrutura espacial

1. Preservar o loop MOBA, três rotas principais, rotas laterais, pontes e seis distritos.
2. Criar quarteirões completos a partir de módulos conectados. Cada quarteirão precisa de pelo menos um edifício dominante e volumes de apoio com escala consistente.
3. Substituir a leitura de edifícios isolados por ruas contínuas, calçadas, meios-fios, cruzamentos, travessias, pátios e praças com ligações visíveis.
4. Variar altura e silhueta: edifício cívico, mercado com módulos comerciais, galpão industrial, terminal, estruturas residenciais e elementos de margem do canal.
5. Evitar grandes áreas vazias preenchidas por árvores/props ou uma repetição de fachadas idênticas.

### Interiores e navegação

- Pelo menos seis interiores reais, conectados aos respectivos volumes externos.
- Entrada visível e sem obstrução; largura de porta compatível com a cápsula do jogador.
- Piso, teto, paredes, mobiliário e eventuais escadas/níveis internos são geometria real, não apenas um marcador no minimapa.
- Renderização, navegação e Rapier compartilham pivô, escala, rotação, bounds e footprints derivados da mesma definição.
- A rota do jogador deve permitir entrar, circular e sair sem atravessar paredes, móveis ou o piso.

### Identidade dos seis distritos

| Distrito | Composição necessária |
|---|---|
| Cívico | Volume institucional de referência, praça, acesso público e mobiliário urbano |
| Reserva Verde | Caminhos orgânicos, relevo leve, vegetação de silhuetas diferentes e clareiras de combate |
| Mercado Central | Quarteirão comercial conectado, marquises, vitrines modulares e praça aberta |
| Pátio Industrial | Galpões de maior escala, docas/pátios, cercas e estruturas de serviço |
| Estação Intermodal | Terminal reconhecível, cobertura de plataforma e volumes de transporte |
| Orla do Canal | Passeio marginal, contenções, guarda-corpos e pontes com silhuetas distintas |

## Fases de implementação

### M0 — Aquisição e auditoria
- Baixar somente a versão Standard gratuita diretamente da distribuição oficial.
- Registrar ZIP, SHA-256, licença, nomes/formatos e quantidade real de arquivos.
- Inventariar módulos arquitetônicos, peças de rua, portas, janelas, pisos, coberturas e elementos de interior.
- Medir bounds, origem, escala, triângulos, materiais e textura de cada modelo candidato.
- Não criar paths presumidos nem preencher o repositório com placeholders.

### M1 — Quarteirão vertical slice
- Montar um quarteirão representativo em escala real.
- Incluir um volume dominante, um volume secundário, uma rua contínua, calçada, cruzamento e um interior realmente navegável.
- Validar geometria e colisão com a cápsula de jogo.
- Conferir o resultado na câmera de gameplay, não somente em viewport de modelagem.

### M2 — Rede urbana
- Conectar os quarteirões com ruas, avenidas, calçadas, pontes e travessias.
- Aplicar os footprints exatos ao catálogo de navegação e aos colliders do Rapier.
- Remover ou substituir modelos antigos quando conflitarem com a nova composição.

### M3 — Seis distritos
- Compor cada distrito a partir de módulos coerentes e de silhuetas claramente distintas.
- Garantir rotas MOBA, áreas de confronto e acesso aos interiores.
- Integrar props somente depois de validar a arquitetura e as vias.

### M4 — Otimização mobile
- Converter/bundlar tudo offline em GLB.
- Reutilizar materiais e texturas, aplicar LOD, culling por células e instancing onde suportado.
- Controlar draw calls, memória de textura, memória de meshes e tamanho final do APK.
- Preservar atualização de cena e simulação dentro do orçamento estabelecido.

## Aceitação obrigatória

- [ ] O ZIP exato e sua licença estão arquivados; hash e inventário foram registrados.
- [ ] A rua contínua e os quarteirões têm escala coerente com o herói na câmera da partida.
- [ ] Não há composição baseada em miniaturas soltas ou em fachadas decorativas.
- [ ] Pelo menos seis edifícios/interiores são realmente transitáveis.
- [ ] Portas, corredores, escadas e passagens não bloqueiam o jogador.
- [ ] Bounds de GLB, navegação e Rapier são consistentes.
- [ ] Capturas de gameplay mostram pelo menos um quarteirão completo e os seis distritos.
- [ ] Não há clipping, fachadas cortadas, objetos flutuantes ou edifícios sobre as vias.
- [ ] Build e testes de navegação/colisão passam.
- [ ] Teste físico prolongado no Realme C53 confirma frame pacing, memória, aquecimento e retomada da partida.

**Nenhum item visual será marcado como aprovado só porque o GLB foi incluído ou o CI ficou verde.** Screenshots e teste físico continuam sendo gates independentes.

## Estado da etapa

- Pesquisa do kit oficial: concluída.
- Aquisição/inspeção do ZIP: pendente.
- Importação de módulos: não iniciada.
- Reconstrução do mapa: não iniciada.
- Screenshots e teste Realme C53: pendentes.
