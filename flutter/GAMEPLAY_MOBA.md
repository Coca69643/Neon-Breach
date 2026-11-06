# Projeto Arena — Gameplay MOBA

## Direção obrigatória

Projeto Arena é um MOBA 5v5 mobile de controle territorial. As rotas mantêm pressão de siege; os seis distritos e o reator central direcionam rotação, recompensas e vantagem estratégica.

## Loop de partida — District Control

1. Jogador escolhe Lyra, Bastion ou Kairo e entra na base.
2. A partida abre com tropas nas rotas e disputa simultânea dos seis distritos.
3. Bots roamers procuram distritos neutros ou adversários; o bot central contesta o reator.
4. Capturar um distrito concede ouro, experiência e bônus territorial de 3,5% de dano à equipe.
5. O reator central mantém seu bônus separado; as tropas continuam necessárias para pressionar estruturas.
6. Uma rota aberta permite avançar sobre o núcleo; vence a equipe que o destruir.

## Campo de batalha

- Arena urbana de 224 × 188 com seis distritos: Distrito Cívico, Reserva Verde, Mercado Central, Pátio Industrial, Estação Intermodal e Orla do Canal.
- Cinco pontes sobre o canal e ruas secundárias pavimentadas conectam os distritos sem obrigar o jogador a usar três corredores fixos.
- Quatro consoles neutros de captura; cada distrito controlado concede bônus territorial.
- Seis interiores ampliados para 24 × 18 unidades, com portas de 6,4 unidades, mobiliário e colisões; dois têm mezaninos.
- Três linhas de tropas continuam como pressão de siege, enquanto heróis e bots fazem rotação territorial.
- Núcleo de cada equipe; orçamento ativo limitado a 48 minions.

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
- Escalas de renderização: herói 1.0, bots 0.98 e minions 0.94–1.02; confirmar a proporção final no aparelho.

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

- Footprint 224 × 188, terreno urbano sem rodapé de penhasco.
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

## Cidade viva e comando tático — revisão 1.7.10

- Quatro distritos internos têm funções visuais distintas: operações, oficina, informação do parque e convivência.
- Os quarteirões usam fachadas CC0 variadas; ruas recebem semáforos, placas, iluminação, faixas, marquises, floreiras e pontos de praça.
- Seis NPCs de serviço seguem patrulhas determinísticas curtas, com caminhada, pausas e animação de interação.
- Um toque no minimapa em terreno acessível envia o aliado de flanco mais próximo a um ponto por oito segundos.
- A ordem tática é temporária e não cancela combate contra heróis; água, estruturas, paredes e pontos fora do mundo são rejeitados.
- O reator central mostra visualmente o controle azul/vermelho e o estado contestado por meio de um anel no cenário.
- Modelos e texturas são preparados no build a partir de assets CC0 fixados por hash; a partida não baixa conteúdo pela rede.
- Os novos detalhes são colocados em pontos navegáveis e não alteram as rotas de colisão existentes.

## Reconstrução das mecânicas — fundação de navegação

- O jogador continua usando o controlador cinemático Rapier 3D com cápsula, gravidade, snap-to-ground, autostep, rampas, mezaninos e colliders estáticos do terreno/edifícios.
- Bots e minions agora compartilham um único resolvedor de movimento de agentes: steering, contorno por ângulos alternativos, deslizamento por eixos e validação de terreno/cobertura.
- A IA escolhe o objetivo tático; o motor compartilhado resolve a locomoção. Formação dos minions é aplicada como preferência lateral, sem duplicar a lógica de colisão.
- O passo é alimentado pelo relógio fixo da simulação. O resolvedor rejeita posições fora da malha navegável, água, paredes e cobertura destrutível.
- Esta etapa ainda não transforma todos os agentes em corpos Rapier: somente o jogador possui cápsula física no mundo 3D. A próxima integração deve adicionar colisão física aos heróis controlados pela IA e, depois, às tropas em lotes de baixo custo.
- A expansão do mapa e a reconstrução de interiores devem acontecer em conjunto com a malha física e a navegação; não basta escalar as fachadas sobre a mesma ilha compacta.
