# Project Arena — Gate de reconstrução do cenário

## Objetivo

Transformar o campo de batalha em uma cidade com leitura visual forte e seis distritos reconhecíveis, preservando o loop MOBA, as dimensões navegáveis, a física Rapier e o orçamento de renderização mobile.

Este gate sucede a fundação técnica 1.8.0. O herói metamórfico fica suspenso até que a identidade do cenário seja aprovada.

## Diagnóstico da fundação atual

O branch já possui:

- Arena lógica irregular de 224 × 188 unidades.
- Seis distritos, três avenidas, cinco pontes e seis interiores.
- Malha contínua do terreno com overlays elevados de asfalto e calçada.
- 56 modelos urbanos Kenney CC0 preparados offline.
- Culling de cenário por vizinhança e atualização da cena a 30 Hz, com HUD a 10 Hz.
- Menu separado da cena de batalha.

A composição visual ainda está incompleta: o catálogo coloca apenas oito blocos comerciais/suburbanos como marcos arquitetônicos principais. A cidade possui sinais, árvores, mobiliário e interiores, mas isso não garante silhuetas distintas, fachadas contínuas ou densidade suficiente para cada setor. O próximo passe deve corrigir composição, variedade e escala, não simplesmente espalhar mais objetos aleatórios.

## Direção visual proposta

**Cidade urbana estilizada, com leitura semi-realista e low-poly refinado.**

- Silhuetas arquitetônicas variadas; evitar repetir o mesmo prédio em quarteirões diferentes.
- Materiais coerentes entre fachadas, calçadas, asfalto, vegetação e água.
- Variação de altura entre edifícios baixos, médios e um ou dois marcos altos por setor.
- Fachadas com portas, vitrines, marquises, sacadas e recuos legíveis na câmera de gameplay.
- Praças e áreas abertas com composição intencional, não grandes retângulos vazios.
- Vegetação em grupos irregulares e bordas naturais; não apenas árvores isoladas em coordenadas simétricas.
- Iluminação estável, sem depender de sombras dinâmicas caras para comunicar volume.

## Identidade dos seis distritos

| Distrito | Elementos de leitura obrigatória |
|---|---|
| Distrito Cívico | Edifício público de referência, praça pavimentada, mobiliário urbano e sinalização institucional. |
| Reserva Verde | Caminhos orgânicos, árvores de silhuetas diferentes, rochas, arbustos e pequenas clareiras. |
| Mercado Central | Fachadas comerciais variadas, marquises, vitrines, toldos, bancas e pontos de encontro. |
| Pátio Industrial | Galpões, depósitos, estruturas técnicas, cercas, tubulações e pátios de serviço. |
| Estação Intermodal | Terminal reconhecível, cobertura de plataforma, sinalização de embarque e elementos de transporte. |
| Orla do Canal | Passeio marginal, contenções, guarda-corpos, bancos, iluminação e cinco pontes visualmente distintas. |

Os seis interiores permanecem acessíveis. A reconstrução das fachadas não pode fechar portas, reduzir passagens ou deslocar colisões sem atualizar navegação e testes.

## Biblioteca CC0 — ordem de preferência

Usar Kenney como biblioteca-base de cenário, pois os kits compartilham linguagem visual e são declarados CC0:

- City Kit (Roads): 90 arquivos; base para peças rodoviárias e sinalização.
- City Kit (Commercial): 50 arquivos; fachadas, edifícios e marcos urbanos.
- City Kit (Suburban): 40 arquivos; quarteirões baixos e transições residenciais.
- City Kit (Industrial): 40 arquivos; galpões e edifícios de serviço.
- Nature Kit: 330 arquivos; árvores, rochas e vegetação.
- Train Kit: 100 arquivos; elementos de estação e transporte.

Texturas de acabamento podem vir de Poly Haven ou ambientCG, ambos CC0. Manter apenas materiais que combinem com o estilo do cenário; não misturar texturas fotográficas pesadas com assets estilizados sem uma etapa de integração.

### Fontes oficiais

- https://kenney.nl/assets/city-kit-roads
- https://kenney.nl/assets/city-kit-commercial
- https://kenney.nl/assets/city-kit-suburban
- https://kenney.nl/assets/city-kit-industrial
- https://kenney.nl/assets/nature-kit
- https://kenney.nl/assets/train-kit
- https://polyhaven.com/license
- https://docs.ambientcg.com/license/

Todo asset novo deve ter licença verificada, origem fixa, hash registrado, validação GLB e inclusão offline. Não depender de download pela partida.

## Separação entre menu e partida

A cena da partida continua sendo uma cena de gameplay independente. O menu não deve carregar o mapa completo como plano de fundo: a apresentação do menu será dedicada à torre/complexo principal, em uma cena 3D separada e leve. Isso mantém o mapa de batalha fora da composição do menu e evita carregar centenas de objetos antes de iniciar a partida.

## Sequência de implementação

### Gate S1 — Vertical slice visual

Reconstruir primeiro um distrito representativo, incluindo:
- um marco arquitetônico;
- um quarteirão com variação de fachadas;
- um trecho de rua com meio-fio e passeio;
- mobiliário e vegetação contextual;
- um interior conectado a uma entrada real.

Critério: validar escala na câmera de gameplay, legibilidade das rotas, aparência dos materiais, colisão e custo de cena antes de replicar o método.

### Gate S2 — Seis distritos

Aplicar a linguagem aprovada aos outros cinco setores, com identidade própria e sem duplicação óbvia de edifícios.

### Gate S3 — Torre do menu

Substituir a ilustração pintada por uma apresentação 3D isolada da torre/complexo, sem renderizar o mapa de batalha atrás dela.

### Gate S4 — Otimização e validação física

Verificar no perfil Release:
- meta de 30 FPS sustentados;
- memória e tamanho dos assets;
- tempo de carregamento;
- ausência de clipping, objetos flutuantes e fachadas atravessáveis indevidamente;
- leitura dos seis distritos na tela do aparelho intermediário.

O CI confirma análise e testes automatizados, mas não substitui a inspeção visual e o teste prolongado no Realme C53.

## Critérios de aceite do cenário

- Cada distrito é reconhecível pela arquitetura e pelo mobiliário, não apenas pelo nome no HUD.
- Nenhuma avenida, ponte, entrada ou interior fica visualmente bloqueado.
- Edifícios e props respeitam a escala dos personagens.
- Geometria visível, navegação lógica e colisão Rapier permanecem alinhadas.
- Não há repetição dominante de um único modelo.
- Os novos modelos são CC0, fixados por hash e preparados offline.
- O mapa de batalha não é instanciado no menu.
- Nenhum APK é produzido a partir deste PR Draft.

## Estado

**Aberto — planejamento e seleção de assets concluídos parcialmente.** O primeiro distrito vertical slice é o próximo trabalho de implementação. A decisão final entre manter a cena de batalha 3D atual ou migrar para um mapa 2D/top-down precisa ser confirmada antes de alterar a arquitetura do renderer.
