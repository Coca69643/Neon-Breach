# Project Arena 0.14.0 — física, modelagem e animação

## Objetivo desta etapa

A 0.13.0 estabeleceu o terreno e a câmera. A 0.14.0 liga a apresentação do personagem à superfície e ao movimento simulado, evitando três sistemas concorrentes para posição: a simulação nativa é a autoridade; o renderer lê o snapshot e apresenta o resultado.

## Física cinemática

`ArenaPhysics.cpp` é compilado diretamente pelo target nativo Android. `PhysicsWorld.cpp` e a implementação anterior baseada em Jolt continuam fora do CMake, portanto não existe um segundo solver alterando posições.

- Passo fixo de 1/60 s com acumulador e limite de quatro subpassos por frame.
- Aceleração e frenagem limitadas, subpassos adaptativos e resposta de deslizamento.
- Colisão circular com árvores, rochas, torres, pedras de acampamentos e anéis de santuário; colisão AABB para muralhas e construções.
- Contenção no contorno da ilha e limitação da componente de velocidade para cima de inclinações acima do limite configurado.
- Separação entre jogador, bots e minions vivos.
- Desvio local preventivo aplicado apenas a bots e tropas. O joystick do jogador continua sendo a entrada direta e previsível.

Os colisores são aproximações cinemáticas derivadas das posições de cenário 0.13.0; não são malhas de colisão triangulares nem um motor de corpos rígidos dinâmicos.

## Superfície autoritativa

O perfil de altura nativo em `ArenaPhysics::terrainHeight` espelha `WorldGlbBuilder.heightAt`. A normal da superfície também é consultada pelo renderer. Movimento usa o gradiente nativo para limitar subidas; o renderer usa a normal para orientar os eixos do herói e dos NPCs.

Isto é uma aderência cinemática à topografia: os corpos não simulam gravidade vertical, saltos balísticos ou rolagem física.

## Equipamento de herói

`HeroGearGlbBuilder.kt` cria cinco grupos visuais por personagem, divididos em peças ósseas:

- tronco e detalhes;
- cabeça e capacete/capuz;
- costas/manto;
- ombreiras e antebraços;
- placas de coxa e botas.

Lyra, Bastion e Kairo têm formas e proporções distintas. As peças são GLB local sem URI externa, parentadas aos ossos spine/head/arms/thighs/feet do rig Quaternius. O corpo-base continua compartilhado; a identidade não depende de três modelos humanos completos duplicados.

Bots recebem acessórios de cor de equipe. O custo é mantido controlado por instanciamento do Filament e geometria local de baixa complexidade.

## Humanização da locomoção

- O rig de NPCs e minions foi ampliado para incluir pelve, pés, mãos, tronco, pescoço e cabeça.
- Passada acompanha deslocamento medido, com flexão de joelho e rotação de pé.
- Mãos e braços compensam a passada; pelve e torso reagem a curvas e frenagem.
- Bots suavizam a mudança de yaw e têm proporções por papel.
- Transformações são alinhadas à normal do terreno.

As poses continuam procedurais; esta versão não adiciona clipes de captura de movimento nem animações de combate completas para todo NPC.

## Testes

`tests/arena_physics_tests.cpp` valida:
- consulta da altura e inclinação;
- bloqueio de árvore e deslizamento/correção de posição;
- colisão com estruturas;
- contorno da ilha;
- frenagem;
- desvio local da IA;
- separação entre corpos.

O workflow executa esses testes nativos com warnings tratados como erros, verifica a estrutura e compila/assina o APK Android.

## Validação física pendente

O CI não comprova comportamento visual real. Ainda requer teste no Realme C53:
- estabilidade do APK e lifecycle;
- leitura visual dos acessórios e encaixe com o rig;
- colisões ao redor de cada área do mapa e se AI não fica presa;
- resposta do joystick junto aos props;
- FPS sustentado, temperatura e memória em partidas longas.

Não declarar a física ou o modelo visual como aprovados em aparelho até concluir esses testes.
