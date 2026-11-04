# Projeto Arena — Pesquisa de identidade: um MOBA com mundo vivo

**Data:** 4 de novembro de 2026  
**Objetivo:** investigar como dar ao Projeto Arena personalidade própria, usando Deadlock como referência de qualidade e densidade, sem reproduzir sua identidade urbana nem copiar seus sistemas.

## Síntese executiva

A oportunidade não é criar “um Deadlock medieval”. É construir um **MOBA de fantasia em uma frente de guerra ecológica**: o vale tem rotinas, territórios, fauna, sinais e memória local. O jogador não é o centro de tudo; ele entra num lugar que já estava vivo e cuja atividade é perturbada pela guerra.

A ideia central recomendada é:

> **O vale não fica esperando o jogador. A guerra atravessa um ecossistema que já tinha seus próprios hábitos.**

Isso deve aparecer tanto em pequenos comportamentos visíveis quanto em decisões de rota e objetivos. A sensação de vida vem de causa e efeito legíveis — não de encher a tela com NPCs.

## O que a pesquisa mostra

### 1. Deadlock: identidade espacial e variedade ligada ao mapa

A reformulação de mapa de 25/02/2025 não se limitou a mudar decoração: a Valve descreveu uma transição para três rotas acompanhada de mudanças em edifícios, caminhos, acampamentos neutros, dutos, objetos quebráveis, pontos de fuga e objetivo central. Isso mostra que a identidade de um mapa nasce da ligação entre espaço, navegação e sistemas, não de uma camada visual isolada. [Map Rework Update — Deadlock](https://deadlock.io/en/patches/map-rework-update-2025-02-25-1792116353369036)

A atualização **City Never Sleeps**, de 29/09/2026, ampliou essa abordagem com uma grande revisão visual e dos neutros, além de novas mecânicas e melhoras de apresentação. É uma boa referência de evolução coerente de um mundo urbano, mas não é a direção visual que devemos copiar. [City Never Sleeps — Deadlock](https://deadlock.io/en/patches/city-never-sleeps-2026-09-29-steam-community-announcements-1844751498235383)

**Aplicação ao Projeto Arena:** cada bioma precisa ter função, silhueta, som, criaturas e rotas próprias. Os dois lados da selva não devem parecer cópias espelhadas com árvores distribuídas em grade.

### 2. Rain World: criaturas existem por motivos próprios

Joar Jakobsson, artista e programador de Rain World, descreveu criaturas que existem independentemente do jogador e procuram alimento e abrigo de forma autônoma. As relações entre criaturas — medo, confiança, caça e defesa — fazem o mundo parecer ativo mesmo quando o jogador não interfere. [Rain World: Surviving in a Living Ecosystem — PlayStation Blog](https://blog.playstation.com/2017/01/16/rain-world-surviving-in-a-living-ecosystem/)

A apresentação dos criadores na GDC detalha a importância de tornar a motivação da criatura perceptível na animação e no movimento. O comportamento visual deve explicar o que a criatura está tentando fazer, em vez de parecer uma animação aleatória. [Animation Bootcamp: Rainworld Animation Process — GDC Vault](https://www.gdcvault.com/play/1023475/Animation-Bootcamp-Rainworld-Animation)

A investigação posterior sobre Rain World também descreve sistemas modulares de percepção e intenção, como rastrear presas, ameaças, aliados, objetos e locais de abrigo. O ponto útil não é copiar a complexidade integral, mas adotar a ideia de que cada espécie combina poucas prioridades simples para produzir comportamento reconhecível. [Exploring Procedural Design in Rain World: The Watcher — Unity](https://unity.com/blog/exploring-procedural-design-rain-world)

**Aplicação ao Projeto Arena:** fauna ambiente e criaturas neutras precisam ter estados e prioridades visíveis: repousar, procurar alimento, patrulhar, reagir a ruído, fugir de uma ameaça, defender território e voltar ao abrigo. A simulação distante pode ser simplificada; perto do jogador, o comportamento e a animação devem ser coerentes.

### 3. Monster Hunter: o ambiente participa da ação

No pós-mortem de Monster Hunter: World, o diretor Yuya Tokuda explicou que a equipe trabalhou para que criaturas se movessem naturalmente pelo cenário, não ficassem presas na vegetação e interagissem umas com as outras. Criaturas menores podiam se unir contra uma maior, e o ambiente podia influenciar o combate. [How Capcom designed Monster Hunter: World to feel approachable and alive — Game Developer / GDC 2018](https://www.gamedeveloper.com/design/how-capcom-designed-i-monster-hunter-world-i-to-feel-approachable-and-alive)

**Aplicação ao Projeto Arena:** não basta criar uma criatura com Idle/Walk/Attack. Ela precisa navegar sem atravessar árvores e rochas, manter sua relação com o território e ter reações coerentes a outras criaturas e à batalha. A selva deve influenciar como os encontros acontecem — sem transformar o combate em aleatoriedade.

### 4. League of Legends: pequenas assinaturas ambientais e mudanças legíveis

A equipe de Summoner’s Rift descreveu como procurou uma “flor na moita” para cada versão elemental do mapa: pequenos elementos visuais, de arte e som, que tornam uma região reconhecível sem obrigar o jogador a reaprender o mapa inteiro. [Unleashing the Elements — Riot Games](https://www.leagueoflegends.com/en-us/news/dev/unleashing-the-elements/)

**Aplicação ao Projeto Arena:** cada região deve ter um detalhe memorável e funcional — por exemplo, um bosque com aves que levantam voo quando alguém se aproxima, uma ruína onde o vento movimenta sinos e tecidos, ou margens do rio com vegetação aquática. Não é preciso remodelar o mapa a cada partida para criar personalidade.

### 5. Simulação social: complexidade precisa ser compreensível

O artigo de praticantes sobre City of Gangsters destaca quatro lições de design: ações e consequências precisam ser legíveis, alterações precisam ser reversíveis quando possível, as regras sociais devem ser poucas e compreensíveis e agentes devem compartilhar uma base de comportamento reutilizável. [AI Design Lessons for Social Modeling at Scale — AAAI AIIDE](https://ojs.aaai.org/index.php/AIIDE/article/view/18911)

**Aplicação ao Projeto Arena:** as criaturas precisam reagir de forma que o jogador consiga entender. Não devemos introduzir dezenas de regras invisíveis ou simular uma população enorme sem impacto claro no jogo.

## Direção de identidade recomendada: Ecologia de Linha de Frente

A proposta tem quatro camadas, implementadas progressivamente.

### Camada A — Vida ambiente (principalmente audiovisual)

- Fauna não combativa em rotinas curtas: beber água, pastar, pousar, procurar abrigo e circular por pequenos territórios.
- Aves levantam voo e pequenos animais procuram cobertura quando uma luta começa nas proximidades.
- Vegetação, água, tecidos, bandeiras e objetos de cenário respondem ao vento e à passagem de personagens.
- Sons posicionais identificam os biomas e ajudam a comunicar atividade fora do enquadramento.
- Esses atores não concedem ouro, experiência, visão ou vantagem competitiva; seu papel é dar vida e feedback.

### Camada B — Criaturas territoriais e acampamentos neutros

- Cada família pertence a um território e tem um conjunto pequeno de prioridades: patrulha, repouso, alerta, agressão, recuo e retorno.
- Criaturas de uma mesma família podem cooperar; espécies diferentes podem evitar-se, disputar espaço ou reagir umas às outras quando isso for legível.
- Guardiões não ficam em pose estática: respiram, observam, se deslocam dentro de uma área limitada e reagem a aproximação.
- Cada acampamento precisa ter entrada, área de combate, abrigo/âncora e vegetação compatível com a espécie.
- Regras de combate, raio de agressão, recompensa e tempo de reaparecimento permanecem previsíveis e simétricos.

### Camada C — O mapa reage à guerra

- Fauna foge de confrontos intensos, criaturas territoriais entram em alerta e partículas/vegetação/objetos comunicam a passagem de uma batalha.
- Estruturas podem apresentar danos visuais depois de eventos importantes; qualquer mudança que afete colisão, cobertura ou linha de visão deve ser explicitamente anunciada e equilibrada.
- Marcos, fortalezas e regiões de selva respondem aos eventos da partida com alterações visuais pequenas, reversíveis e fáceis de ler.
- Um evento de mapa futuro pode alterar temporariamente o comportamento de uma região, mas deve ser anunciado, simétrico e não bloquear permanentemente uma rota.

### Camada D — Momentos emergentes com autoria controlada

- Um predador pode atravessar uma clareira enquanto uma equipe se aproxima; aves podem revelar indiretamente movimento recente; uma criatura pode recuar para seu abrigo quando a luta fica grande.
- O objetivo é produzir momentos que pareçam descobertos, não cutscenes repetidas.
- Eventos raros devem emergir de sistemas simples e conter limites para evitar loops, perseguições infinitas ou vantagens aleatórias.

## O que pode tornar o Projeto Arena reconhecível

| Pilar | Assinatura própria | Impacto no jogador |
|---|---|---|
| Duas selvas com ecologias distintas | Fauna, vegetação, sons e rotinas diferentes em cada lado | Reconhecimento do espaço e desejo de explorar |
| Criaturas com território | Patrulham, alertam, defendem e retornam ao abrigo | Encontros menos mecânicos e leitura estratégica |
| Guerra que perturba a natureza | Fauna e ambiente reagem à intensidade e proximidade das batalhas | O mapa comunica o que está acontecendo |
| Mundo com memória local | Sinais visuais de eventos recentes, sem alterar regras às escondidas | Sensação de continuidade dentro da partida |
| Combate conectado ao terreno | Rotas, margens, ruínas e vegetação influenciam aproximações | O cenário importa além da decoração |

A proposta de assinatura é **“um MOBA onde a selva é um terceiro participante”** — não uma terceira equipe, mas um conjunto neutro de sistemas vivos que reage igualmente às duas equipes.

## Limites competitivos

1. A fauna ambiente não pode dar recursos, revelar inimigos ou causar dano inesperado.
2. Criaturas neutras precisam de telegráficos, raios de ação e limites territoriais legíveis.
3. Qualquer evento com efeito de gameplay deve ocorrer em tempos conhecidos, ser anunciado e oferecer oportunidades equivalentes às equipes.
4. A rota principal, as três travessias e o acesso aos objetivos não podem ser bloqueados sem aviso.
5. Mudanças visuais não podem alterar silenciosamente colisão, visão ou navegação.
6. A aleatoriedade deve mudar detalhes e momentos, não decidir lutas.
7. A IA de ambiente precisa ter orçamento de CPU fixo e escala por distância.

## Arquitetura adequada ao alvo mobile

- **Próximo do jogador:** comportamento e animação completos para poucos atores relevantes.
- **Médio alcance:** estados simplificados e atualizados em frequência menor; sem rigs ativos quando não necessários.
- **Fora de alcance:** guardar apenas estado, objetivo e temporizador; não manter cada criatura executando pathfinding completo.
- Usar catálogos de espécies, módulos simples de comportamento, pooling, LOD, culling e navegação limitada por território.
- A simulação de ambiente nunca deve disputar o orçamento reservado para input, câmera, renderização, colisão, bots e minions.
- Medir CPU, GPU, memória e temperatura no Realme C53; a compilação CI não prova desempenho sustentado.

## Ordem de implementação recomendada

1. Integrar a fonte canônica do mundo ao runtime de renderização, física, navegação, minimapa e spawns.
2. Completar a topografia, o rio, as três pontes, as três rotas e os limites navegáveis.
3. Fechar a identidade visual distinta das duas selvas e das duas bases.
4. Criar o primeiro ciclo de vida de uma espécie ambiente e uma família territorial; validar navegação e animação no aparelho.
5. Expandir fauna, reações ambientais e momentos emergentes depois que o primeiro ciclo provar custo e legibilidade.
6. Só então avaliar eventos de mapa com impacto de gameplay.

## Critério de prova: “o mundo está vivo?”

Uma captura de gameplay de 60–90 segundos deve mostrar, sem depender de cutscene:
- pelo menos dois comportamentos ambientais distintos;
- uma reação de fauna à aproximação ou ao combate;
- um guardião em rotina antes de entrar em combate;
- navegação sem atravessar obstáculos;
- sinais sonoros e visuais coerentes com a região;
- nenhuma vantagem competitiva invisível ou ruído excessivo de animação.

## Fontes consultadas

- Valve / Deadlock, [Map Rework Update (25/02/2025)](https://deadlock.io/en/patches/map-rework-update-2025-02-25-1792116353369036).
- Valve / Deadlock, [City Never Sleeps (29/09/2026)](https://deadlock.io/en/patches/city-never-sleeps-2026-09-29-steam-community-announcements-1844751498235383).
- Joar Jakobsson / Videocult, [Rain World: Surviving in a Living Ecosystem](https://blog.playstation.com/2017/01/16/rain-world-surviving-in-a-living-ecosystem/).
- GDC Vault, [Animation Bootcamp: Rainworld Animation Process](https://www.gdcvault.com/play/1023475/Animation-Bootcamp-Rainworld-Animation).
- Unity, [Exploring Procedural Design in Rain World: The Watcher](https://unity.com/blog/exploring-procedural-design-rain-world).
- Alex Wawro / Game Developer, [How Capcom designed Monster Hunter: World to feel approachable and alive](https://www.gamedeveloper.com/design/how-capcom-designed-i-monster-hunter-world-i-to-feel-approachable-and-alive).
- Riot Games, [Unleashing the Elements](https://www.leagueoflegends.com/en-us/news/dev/unleashing-the-elements/).
- Robison, Viglione, Zubek & Horswill, [AI Design Lessons for Social Modeling at Scale](https://ojs.aaai.org/index.php/AIIDE/article/view/18911), AAAI AIIDE (2021).

## Decisão pendente de validação

Esta pesquisa define uma direção e critérios de teste, não declara os sistemas implementados. O primeiro passo técnico continua sendo conectar o JSON canônico à execução do jogo. A identidade “Ecologia de Linha de Frente” será validada por uma fatia jogável antes de expandir a simulação.
