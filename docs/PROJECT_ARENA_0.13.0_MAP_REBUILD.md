# Project Arena 0.13.0 — mapa e câmera

## Objetivo

A 0.12.0 tinha sistemas de partida MOBA, mas o campo parecia uma ilha plana com faixas e bandeiras. A 0.13.0 trata o cenário como um campo de batalha com relevo e regiões distintas.

## Estrutura do mapa

- Três rotas principais continuam preservadas e cruzam o território em curvas.
- O rio atravessa o mapa; as três pontes permanecem como travessias principais.
- As selvas são divididas em quatro quadrantes e conectam acampamentos, rotas e rio.
- Oito acampamentos têm clareiras de terra, perímetro rochoso e ruínas.
- Dois objetivos neutros ocupam santuários de pedra distintos, um em ruínas e outro preservado.
- Os lados das bases recebem cristas, pátios e muralhas baixas.
- A borda da ilha tem falésia e uma camada de água abaixo do terreno.

## Terreno e renderização

`WorldGlbBuilder.heightAt(x,z)` é a fonte de altura autoritativa para a malha gerada, árvores, estruturas e herói. O terreno é construído em uma malha de 104 × 104 células. As zonas de selva usam solo escuro, vegetação rasteira e pedras facetadas; as árvores usam instâncias compartilhadas do pack KayKit CC0.

O mapa não cria um objeto GLB para cada pedra ou arbusto: geometria procedural de props é agrupada por material no GLB runtime. Isso limita a quantidade de assets e chamadas de draw.

## Câmera e controles

- Heading fixo no mundo; yaw do herói afeta apenas o modelo.
- Enquadramento isométrico com distância horizontal constante.
- Zona morta de 1,85 m entre o foco da câmera e o jogador; ultrapassada essa distância, o foco segue suavemente.
- O eixo vertical do controle touch é invertido para que empurrar o joystick para cima mova o herói para +Z, direção superior do campo.
- A câmera consulta a mesma função de altura do terreno para acompanhar a topografia sem alterar seu heading.

## Limites deste incremento

A atualização melhora a topografia, a leitura de rotas e a ambientação, mas ainda não implementa colisão de navegação para cada árvore/rocha, pathfinding em torno de obstáculos, Fog of War, matchmaking, draft ou chefes neutros animados. A validação real de câmera, temperatura e FPS depende de teste físico em aparelho; CI só comprova estrutura e compilação.
