# Project Arena — Gate de reconstrução do cenário

## Decisão de arquitetura (confirmada)

- **Menu principal:** fundo ilustrado em 2D, leve e independente.
- **Gameplay:** campo de batalha em 3D, com cenário, entidades e colisão na cena de partida.
- O menu não instancia o mapa de batalha nem carrega seus modelos 3D.
- Não haverá migração do renderer da gameplay para 2D. A divisão 2D/3D está fechada para este gate.

## Objetivo

Reconstruir o campo de batalha como uma cidade estilizada com seis distritos visualmente reconhecíveis, preservando o loop MOBA, a navegação, a física Rapier e o orçamento de renderização mobile.

O herói metamórfico permanece fora de escopo até a identidade visual do cenário ser aprovada.

## Diagnóstico da fundação

O branch já possui:

- Arena lógica irregular de 224 × 188 unidades.
- Seis distritos, três avenidas, cinco pontes e seis interiores acessíveis.
- Terreno contínuo com overlays elevados de asfalto e calçadas, meio-fio e marcações.
- 56 modelos urbanos Kenney CC0 preparados offline e com origem/hash fixados no script de preparação.
- Culling de props por vizinhança; cena atualizada a 30 Hz e HUD a 10 Hz.
- Colisões de edifícios, vegetação, mobiliário interno e rotas verticais compartilhadas com a navegação.

A base técnica está pronta para receber composição visual. O problema restante é densidade, hierarquia de silhuetas e identidade de cada setor — não a dimensão do mapa.

## Direção visual

**Cidade urbana estilizada, com leitura semi-realista e low-poly refinado.**

- Variar silhuetas e alturas; evitar fachadas dominantes repetidas.
- Manter linguagem visual consistente entre edifícios, pavimento, mobiliário e vegetação.
- Dar escala legível a portas, vitrines, marquises e elementos urbanos na câmera de gameplay.
- Compor praças e clareiras com intenção, sem preencher todos os espaços.
- Preservar passagens, rotas de combate e acesso aos seis interiores.
- Usar iluminação estável; não depender de sombras dinâmicas caras para comunicar volume.

## Identidade dos distritos

| Distrito | Leitura visual obrigatória |
|---|---|
| Distrito Cívico | Edifício público de referência, praça pavimentada, mobiliário e sinalização institucional. |
| Reserva Verde | Caminhos orgânicos, árvores de silhuetas diferentes, rochas, arbustos e clareiras. |
| Mercado Central | Fachadas comerciais variadas, marquises, vitrines, toldos, bancas e praça aberta. |
| Pátio Industrial | Galpões, depósitos, estruturas técnicas, cercas e pátios de serviço. |
| Estação Intermodal | Terminal reconhecível, cobertura de plataforma, sinalização e elementos de transporte. |
| Orla do Canal | Passeio marginal, contenções, guarda-corpos, bancos, iluminação e cinco pontes distintas. |

## Gate S1 — Vertical slice do Mercado Central

**Primeira implementação submetida no catálogo de mundo:**

- Duas fachadas comerciais diferentes: `commercial_building_i.glb` e `commercial_building_j.glb`.
- As duas fachadas enquadram o núcleo do distrito sem ocupar o ponto de captura.
- Marquises, dois pontos de convivência com guarda-sol, quatro floreiras e dois postes de iluminação formam a primeira composição de rua.
- As footprints dos dois edifícios entram em `commercialBlocks`; o mesmo catálogo alimenta o renderizador, `isWalkable` e os colliders estáticos do Rapier.
- Os modelos já estão na lista de assets Kenney fixados e validados pelo script `prepare_city_assets.py`; não foi introduzida dependência de download em runtime.

**Validação automatizada mais recente:** CI run 42383763525 passou em `flutter analyze` e 89 testes. As dez fachadas comerciais agora possuem footprints retangulares derivados dos bounds locais dos GLBs; o bake offline valida largura, profundidade, altura e origem centralizada dos modelos, e o Rapier usa essas mesmas dimensões.

**Validação visual ainda pendente:** screenshots da câmera real de gameplay precisam confirmar escala, afastamento das vias, ausência de clipping e acessos. A validação física no Realme C53 continua pendente. A inclusão no catálogo e o CI não equivalem a aceite visual.

Critérios de aceite do S1:
1. Fachadas distintas e proporção coerente com os personagens.
2. Praça e ponto de captura desobstruídos.
3. Passagens laterais navegáveis e colisão alinhada às fachadas.
4. Props apoiados no pavimento, sem clipping ou objetos flutuantes.
5. Custo de renderização compatível com o perfil mobile.

## Gate S2 — Expansão dos seis distritos

Depois do aceite visual do Mercado Central, aplicar a mesma disciplina aos outros cinco setores. Cada um deve usar um conjunto próprio de silhuetas e mobiliário; não basta trocar o rótulo do distrito.

## Gate S3 — Otimização e validação mobile

Verificar no perfil Release:
- meta de 30 FPS sustentados;
- memória, draw calls e tamanho dos assets;
- tempo de carregamento e atualizações de células de cenário;
- ausência de clipping, objetos flutuantes e rotas bloqueadas;
- leitura dos seis distritos na tela do aparelho intermediário.

O CI automatizado não substitui inspeção visual e sessão prolongada no Realme C53.

## Biblioteca CC0 e preparação offline

Kenney continua como biblioteca ambiental principal por manter uma linguagem visual coerente e declarar CC0 nos kits utilizados:

- City Kit Roads: https://kenney.nl/assets/city-kit-roads
- City Kit Commercial: https://kenney.nl/assets/city-kit-commercial
- City Kit Suburban: https://kenney.nl/assets/city-kit-suburban
- City Kit Industrial: https://kenney.nl/assets/city-kit-industrial
- Nature Kit: https://kenney.nl/assets/nature-kit
- Train Kit: https://kenney.nl/assets/train-kit

Poly Haven e ambientCG ficam reservados a acabamentos que combinem com a direção estilizada:
- https://polyhaven.com/license
- https://docs.ambientcg.com/license/

Todo novo modelo deve ter licença verificada, origem fixa, hash registrado, validação GLB e inclusão offline. A partida não baixa assets.

## Fora de escopo deste gate

- O menu permanece 2D; não será convertido para torre 3D.
- Não carregar o mapa de batalha atrás do menu.
- Não alterar o renderer 3D da gameplay.
- Não implementar o herói metamórfico antes da aprovação da identidade do cenário.
- Não gerar APK nem publicar release a partir deste PR Draft.

## Estado

**S1 em implementação; aceite visual pendente.** A arquitetura 2D no menu / 3D na gameplay está confirmada. O CI passou para a etapa de footprints e colisões; o próximo passo é validar a composição do Mercado Central com screenshots e no aparelho antes de propagar o padrão aos demais distritos.
