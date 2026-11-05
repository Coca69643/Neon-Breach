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

- Movimento do herói por controle touch, colisão com o limite do mapa, canal, paredes, mobiliário, coberturas e footprints de torres; movimento com varredura em subpassos para impedir atravessar obstáculos.
- Ataque básico, alcance, intervalo de ataque e seleção de alvo.
- Espadas CC0 diferentes para Lyra, Bastion e Kairo, anexadas ao osso `Palm.R`; bots, tropas e NPCs usam seis modelos CC0 independentes dos heróis selecionáveis.
- Duas rotas verticais com escada e mezanino; movimento armazena elevação e exige atravessar a rampa, sem saltar entre pisos.
- Coberturas destrutíveis com 180 HP bloqueiam duas entradas; ataques básicos removem HP e destroem a colisão ao zerar.
- Reator central contestável; presença ponderada das unidades altera progresso, disputa simultânea congela a captura e controle concede +12% de dano.
- Primeira captura do reator rende 150 G e 90 XP à equipe capturadora.
- Três kits de habilidade com função distinta:
  - Lyra: suporte e recuperação de aliados.
  - Bastion: linha de frente e mitigação.
  - Kairo: mobilidade e pressão de curta duração.
- Ondas: três unidades corpo a corpo e uma unidade de distância por formação; unidades derrotadas são recicladas antes de aplicar o limite global de 48 entidades.
- Bots aliados e rivais com objetivos de rota, combate, flancos por pontos de referência e retorno após eliminação; sua movimentação ignora apenas a colisão do footprint das torres para alcançar pontos de ataque externos.
- Torres com prioridade de alvo e proteção por tropas.
- Ouro, experiência, níveis, atributos e loja de itens.
- Vitória/derrota pelo estado do núcleo; pausa e retomada preservam a simulação enquanto o processo está ativo. Persistência após encerramento forçado ainda não está implementada.

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
- Simulação usa passo fixo e orçamento explícito de entidades; não deve depender da taxa de quadros do aparelho. Unidades derrotadas são removidas antes de verificar o limite de 48 tropas, permitindo novas ondas ao longo da partida.
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
- Ataque básico com clipe SwordSlash e alcance/intervalo específico por herói; bots e tropas também expõem janelas de ataque para reproduzir golpes corpo a corpo ou à distância.
- Seleção manual de alvo por botão touch, com HUD contextual e barra de vida.
- Marcador de acerto separado da animação de swing; só confirma quando o dano foi aplicado.
- Quatro interiores com piso, paredes, portas, mobiliário e colisões; três avenidas e três travessias do canal.
- Seis modelos CC0 com rigs e animações compartilhados por bots, tropas e NPCs, sem reutilizar a aparência dos três heróis selecionáveis.
- Bots e tropas usam colisão de cenário e pontos de aproximação de estruturas; a pegada das torres não bloqueia o trânsito das unidades de rota.
- Pipeline verifica o rig masculino de Kairo e os clipes de ataque no GLB empacotado.

Ainda pendente:
- Efeitos de impacto por tipo de ataque e indicadores mais claros de seleção/alcance.
- Seleção de alvo, telegraph e feedback de alcance/recarga mais legíveis.
- Loja e itens MOBA.
- Efeitos de impacto, telegraph e seleção de alvo mais claros; o reator central já está integrado como objetivo competitivo.
- Fachadas/interiores com acabamento artístico e validação visual das escadas/mezaninos no aparelho.
- Validação física de câmera, movimento, ataques, FPS, temperatura e memória no Realme C53.

Não anunciar gameplay completo enquanto combate, equipamentos, progressão de itens e validação física não estiverem concluídos.

## Arena, câmera, verticalidade e objetivo — revisão 1.7.10

- Footprint 180 × 140, terreno urbano sem rodapé de penhasco.
- Três avenidas em x ≈ -36 / 0 / +36 e z ≈ -70…+70.
- Quatro interiores com portas, paredes e mobiliário; dois recebem mezaninos com escadas transitáveis. Sem camps ou mecânicas de coleta.
- Coberturas de entrada são destrutíveis; reator central no cruzamento médio concede bônus de dano por controle territorial.
- O canal bloqueia movimento fora das três travessias; torres, paredes, mobiliário e limites do mapa têm colisão para o jogador. Bots e tropas ignoram apenas a pegada das torres para acessar pontos de ataque fora das estruturas.
- O movimento do jogador valida o percurso em subpassos; o dash interrompe ao atingir um obstáculo, sem atravessar paredes.
- O minimapa usa as mesmas posições das três rotas e a linha central do canal do catálogo do mundo.
- Câmera de ação traseira com follow distance 9.4, look-ahead 3.0, pitch 0.34 rad e FOV 49°. O arrasto central/direito controla a câmera; joystick esquerdo controla movimento.

## Targeting e feedback de combate — revisão 1.7.10

- Botão ALVO percorre heróis e tropas inimigas dentro de 24 unidades, priorizando a menor distância.
- O HUD mostra nome, classe e vida do alvo selecionado e some quando ele morre ou sai do alcance de seleção.
- Ataque sem contato mantém o feedback de swing, mas não dispara confirmação de impacto.
- Dano real em heróis, tropas, coberturas, torres e núcleo ativa um marcador breve de acerto.
- A seleção manual complementa o auto-target atual; não substitui a lógica contextual de torres e estruturas.
- Ataques dos bots e minions têm uma janela temporal própria para que o renderer toque clips de golpe em vez de alternar apenas entre Idle e Walk.
- O processo de pausa/retomada conserva o estado em memória. Savegame que sobreviva ao encerramento forçado do aplicativo ainda não está implementado.
