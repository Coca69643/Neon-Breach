# Project Arena — reconstrução integral do mapa CC0

Status: escala global de renderização/colisão reconciliada em código; reconstrução geométrica do mapa ainda pendente.

## Diretriz do usuário

O mapa precisa mudar como espaço jogável, não apenas como composição de props. É explicitamente reprovado:
- distribuir miniaturas de edifícios em um terreno vazio e chamar isso de mapa novo;
- alinhar peças pequenas de rua sem formar uma malha urbana contínua;
- ampliar a escala de uma miniatura isolada para simular um prédio completo;
- usar fachadas como cascas decorativas sem espaço interno transitável;
- aceitar screenshots de editor ou renders isolados no lugar da câmera real da partida.

## Diagnóstico atual confirmado no código

- O mundo lógico atual mede 224 × 188 unidades e mantém seis setores.
- O catálogo contém treze placements comerciais/residenciais com doze silhuetas GLB distintas; quatro volumes de escala maior formam o primeiro quarteirão ao redor do interior west-north.
- Existem seis interiores construídos com paredes, mobiliário e vãos de entrada; o primeiro quarteirão vertical slice envolve o interior west-north com quatro edifícios CC0.
- Vias, canal, pontes, árvores, fachadas, navegação e colisores já têm uma fundação funcional, mas a composição de superfície ainda não comunica uma cidade completa com silhuetas densas, quarteirões conectados e identidade própria por distrito.
- A auditoria encontrou um desvio de escala: a raiz 3D aplicava 1.35× aos modelos, enquanto Rapier e navegação usavam as dimensões lógicas sem essa conversão. `worldScale` agora é 1.0 para manter renderização, câmera e física no mesmo sistema de unidades; a validação em runtime ainda é obrigatória.
- A auditoria visual final dos edifícios, acessos e proporções continua pendente.

Esses pontos são uma fundação técnica; não equivalem ao aceite visual de um mapa urbano completo.

## Biblioteca CC0 selecionada para reconstrução

A base visual passa a ser a família de kits urbanos **Kenney**, cuja página oficial de cada pacote declara CC0. A seleção cobre arquitetura, malha viária, natureza, indústria e interiores:

| Pacote oficial | Conteúdo declarado | Uso previsto |
|---|---:|---|
| [City Kit (Roads)](https://kenney.nl/assets/city-kit-roads) | 90 peças, atualização 2.2 | Malha de ruas, cruzamentos, curvas, calçadas e sinalização |
| [City Kit (Commercial)](https://kenney.nl/assets/city-kit-commercial) | 50 arquivos | Volumes comerciais e silhuetas de maior altura |
| [City Kit (Suburban)](https://kenney.nl/assets/city-kit-suburban) | 40 arquivos | Edifícios residenciais, pátios e fachadas de apoio |
| [City Kit (Industrial)](https://kenney.nl/assets/city-kit-industrial) | 40 arquivos | Galpões, fábricas e estruturas de serviço |
| [Nature Kit](https://kenney.nl/assets/nature-kit) | 330 arquivos | Árvores, rochas e vegetação dos espaços abertos |
| [Furniture Kit](https://kenney.nl/assets/furniture-kit) | 140 arquivos | Mobiliário dos interiores realmente acessíveis |
| [Factory Kit](https://kenney.nl/assets/factory-kit) | 140 arquivos | Equipamentos e composição interna do distrito industrial |

**Regra de composição:** esses pacotes são fontes de peças 3D, não um mapa pronto. O resultado precisa ser montado em escala de gameplay, com quarteirões conectados e volumes arquitetônicos coerentes. Uma coleção de edifícios isolados, miniaturas, fachadas sem volume ou tiles de rua espalhados não atende ao objetivo.

**Interiores:** os kits externos não comprovam que um edifício seja transitável. Cada edifício selecionado terá geometria interna própria — piso, paredes, vãos, portas e mobiliário — ligada ao volume externo e aos mesmos bounds usados por navegação e Rapier.

**Proveniência pendente:** as páginas oficiais confirmam a licença CC0 e o conteúdo declarado, mas os ZIPs originais ainda não estão arquivados neste repositório. A aquisição continua bloqueada até registrar, por pacote, URL oficial, versão, data, arquivo original, SHA-256 do ZIP, licença incluída, inventário e hashes SHA-256 dos GLBs selecionados. Os GLBs individuais atualmente preparados por `prepare_city_assets.py` são uma base técnica existente; não representam aquisição integral nem reconstrução do mapa.

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
- [ ] Compor um quarteirão em escala de gameplay ao redor do interior west-north.
- [ ] Integrar quatro volumes CC0 distintos (comercial, residencial e silhueta alta) sem transformar o quarteirão em edifícios miniaturizados.
- [ ] Derivar renderização e colisão dos mesmos bounds GLB e manter os volumes sem interseção.
- [ ] Manter a rota sul da porta e a calçada da avenida oeste transitáveis.
- [ ] Validar o resultado na câmera real da partida e no Realme C53.

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
- Reuso de modelos já presentes no bundle offline: composição M1 preparada com assets já pinados; novos arquivos externos ainda não adquiridos.
- Escala renderização/física: reconciliada em código; runtime ainda pendente.
- M1 — quarteirão vertical slice: composição de código preparada; CI, captura de gameplay e revisão física ainda pendentes.
- M2 — rede urbana e cinco distritos restantes: não iniciada.
- Screenshots e teste Realme C53: pendentes.
