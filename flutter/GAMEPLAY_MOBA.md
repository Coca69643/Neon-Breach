# Projeto Arena — Gameplay MOBA

## Direção obrigatória

Projeto Arena é um MOBA 5v5 mobile, não um jogo de sobrevivência. O loop principal é disputa de rotas, combate entre heróis e tropas, controle de estruturas, progressão durante a partida e destruição do núcleo adversário.

## Loop de partida

1. Jogador escolhe Lyra, Bastion ou Kairo e entra na base da equipe.
2. As três rotas recebem ondas periódicas de tropas aliadas e adversárias.
3. Heróis, bots e tropas disputam espaço, experiência, ouro e estruturas.
4. Torres protegem cada rota; uma torre só pode ser atacada com pressão de tropas aliadas.
5. Destruir as três torres de uma rota abre o acesso ao núcleo daquela equipe.
6. A equipe que destrói o núcleo inimigo vence.

## Campo de batalha

- Três rotas: superior, central e inferior, estendidas por um campo urbano de 180 × 140 unidades.
- Formação sem jungler: distribuição 2–1–2, com flex para reforçar rota.
- Três torres por rota e por equipe: externas, intermediárias e internas (18 no total).
- Núcleo de cada equipe.
- Canal central leste-oeste, três travessias, becos laterais e quatro edifícios de piso térreo com interiores percorríveis; sem acampamentos de selva.
- Orçamento de tropas ativo limitado a 48 unidades.

## Sistemas de gameplay

- Movimento do herói por controle touch, colisão com o limite do mapa, canal, paredes de edifícios, mobiliário e footprints de torres.
- Ataque básico, alcance, intervalo de ataque e seleção de alvo.
- Três kits de habilidade com função distinta:
  - Lyra: suporte e recuperação de aliados.
  - Bastion: linha de frente e mitigação.
  - Kairo: mobilidade e pressão de curta duração.
- Ondas: três unidades corpo a corpo e uma unidade de distância por formação.
- Bots aliados e rivais com objetivos de rota, combate e retorno após eliminação.
- Torres com prioridade de alvo e proteção por tropas.
- Ouro, experiência, níveis, atributos e loja de itens.
- Vitória/derrota pelo estado do núcleo; pausa e retomada preservam a simulação.

## Fora do escopo

Não adicionar mecânicas de sobrevivência:
- fome, sede, sono ou temperatura corporal;
- coleta de madeira, pedra, minério ou alimentos;
- crafting, ferramentas de coleta ou durabilidade;
- construção de abrigo, base ou fogueira;
- inventário de sobrevivência, loot aleatório ou progressão por grind de recursos.

O ouro de partida é economia MOBA, não recurso de sobrevivência.

## Arquitetura técnica atual

- Flutter/Dart mantém interface, estado da partida e simulação determinística.
- Flutter Scene renderiza terreno, personagens, tropas, estruturas e efeitos 3D.
- Simulação usa passo fixo e orçamento explícito de entidades; não deve depender da taxa de quadros do aparelho.
- Renderização e simulação são separadas: um frame perdido não altera a velocidade lógica da partida.
- A câmera de combate é traseira e baixa; o arrasto na zona central/direita altera yaw/pitch e o joystick esquerdo altera apenas movimento. A visão estratégica fica no minimapa.
- Alvo inicial é 30 FPS sustentados em aparelho intermediário; medir no perfil/release em aparelho físico.
- Câmera de combate usa perspectiva 3/4, acompanhando o jogador por trás e um pouco acima; não usar enquadramento de mapa inteiro durante a luta.
- Configuração atual: follow distance 9.4, look-ahead 3.0, pitch inicial 0.34 rad e FOV vertical 49°; validar enquadramento no Realme C53.
- Escalas de renderização: herói 1.0, bots 0.86 e minions 0.54–0.58; validar proporção relativa às estruturas no aparelho.

## Estado desta implementação

Implementado no branch atual:
- Partida 5v5 com simulação Dart determinística, três rotas, ondas, 18 estruturas defensivas, bots, economia básica, XP, níveis, habilidades iniciais e respawn.
- Cena 3D conectada aos snapshots: terreno, bases urbanas, estruturas de rota, tropas, bots e herói selecionado.
- Joystick esquerdo exclusivo para movimento; pointer tracking central/direito exclusivo para girar e inclinar a câmera.
- HUD touch, minimapa, pausa e botões de ataque/habilidade.
- Ataque básico com clipe SwordSlash e alcance/intervalo específico por herói.
- Quatro interiores com piso, paredes, portas, mobiliário e colisões; três avenidas e três travessias do canal.
- Pipeline verifica o rig masculino de Kairo e os clipes de ataque no GLB empacotado.

Ainda pendente:
- Armas visíveis acopladas aos rigs dos heróis e efeitos de impacto por tipo de ataque.
- Seleção de alvo, telegraph e feedback de alcance/recarga mais legíveis.
- Loja e itens MOBA.
- Objetivos neutros competitivos (sem camps de sobrevivência ou coleta).
- Fachadas/interiores com acabamento artístico, escadas e rotas verticais funcionais.
- Validação física de câmera, movimento, ataques, FPS, temperatura e memória no Realme C53.

Não anunciar gameplay completo enquanto combate, equipamentos, progressão de itens e validação física não estiverem concluídos.

## Arena, câmera e interiores — revisão 1.7.5

- Footprint 180 × 140, terreno urbano sem rodapé de penhasco.
- Três avenidas em x ≈ -36 / 0 / +36 e z ≈ -70…+70.
- Quatro interiores com portas abertas, paredes e mobiliário com colisão; becos conectam as rotas. Sem camps ou mecânicas de coleta.
- O canal bloqueia movimento fora das três travessias; torres, paredes, mobiliário e limites do mapa têm colisão.
- Câmera de ação traseira com follow distance 9.4, look-ahead 3.0, pitch 0.34 rad e FOV 49°. O arrasto central/direito controla a câmera; joystick esquerdo controla movimento.
