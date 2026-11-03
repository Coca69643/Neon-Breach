# Changelog — Projeto Arena

## [0.15.4] — 2026-11-03

### Preview e câmera
- Retirado o personagem da seleção/menu de cima da torre azul central; preview movido para clareira reservada fora das rotas principais.
- Ficha de herói continua à esquerda; câmera desloca o modelo para a área livre à direita, com escala maior.
- Câmera de combate aproximada e FOV vertical reduzido para tornar heróis e bots mais legíveis em landscape.

### Leitura do cenário
- Reduzida a saturação e a dominante ciano nos materiais de grama, trilhas, pedra e água.
- Skybox e iluminação indireta ajustados para uma temperatura mais neutra.
- Teste JVM verifica distância mínima do preview a torres, camps e santuários.

## [0.15.3] — 2026-11-02

### Rig e apresentação 3D
- Corrigida a causa do T-pose: a flexão dos braços passa a usar o eixo Z local do rig com sinal espelhado entre os lados.
- Jogador, bots e tropas compartilham a mesma convenção de flexão; um teste JVM usa as rotações de bind do GLB para verificar que ambos os braços apontam para baixo.
- Seleção de heróis reposicionada no centro da câmera, com enquadramento mais próximo e leve rotação de apresentação.
- O preview do HUB mantém idle procedural ativo enquanto o cenário 3D é renderizado.

## [0.15.0] — 2026-11-02

### Silhuetas, rig e movimento
- Expandido o pipeline de equipamento para cinco silhuetas de função: Bastion/solo, Kairo/jungle, conjurador/mid, ranger/carry e Lyra/suporte.
- O renderer associa o conjunto de cada bot ao papel retornado pelo snapshot nativo e reconstrói apenas o equipamento quando o jogador troca de herói.
- Diagnóstico do GLB confirmou ossos dos braços ao longo do eixo local Y. A pose anterior aplicava abdução em Z; foi substituída por rotação X de menor amplitude e flexão de cotovelos mais controlada.
- Bots passam a usar cadências, prontidão dos braços e flexão diferentes por papel; tropas de distância recebem postura de prontidão distinta das unidades corpo a corpo.
- Câmera de combate aproximada moderadamente para tornar o herói mais legível sem abandonar a leitura tática.

### Campo de batalha e HUB
- Aumentada a escala das cristas laterais, elevações das bases, colinas de selva e vale do rio; acrescentada uma prateleira de terreno na selva.
- A malha passou de 104 × 104 para 136 × 136 células.
- A fórmula de elevação foi espelhada em Kotlin e C++ para manter renderização, altura de personagem, inclinação e física coerentes.
- Paleta de terreno e ambiente ajustada para tons menos ciano.
- Novo HUB panorâmico com ilustração vetorial original feita em Canvas.
- Removidos os grandes painéis e a pilha vertical de seis opções. Ações principais agora ficam em uma dock horizontal; guia e ajustes foram movidos para utilitários compactos, e a Loja fica dentro de Coleção.

### Validação e limites
- Adicionados testes JVM para os cinco GLBs de função e para o intervalo de alturas/inclinações do mapa.
- Testes C++ de física agora amostram a amplitude do terreno e o limite de inclinação.
- A versão é uma revisão visual/procedural, não uma troca por cinco esqueletos ou cinco clipes de captura de movimento importados. O corpo base continua sendo o humanoide Quaternius CC0; as diferenças vêm de equipamentos e animação procedural por função.
- CI compila o APK e executa testes determinísticos; validação visual, FPS sustentado, temperatura e controles ainda dependem de teste físico no Realme C53.


## [0.14.0] — 2026-11-02

### Modelagem e identidade dos personagens
- Criado um pipeline GLB runtime local para equipamentos articulados, sem dependências de rede ou texturas extras.
- Lyra recebe camadas leves de manto e placas; Bastion recebe peitoral/ombros reforçados e elmo; Kairo recebe armadura assimétrica e manto dividido.
- Cada conjunto inclui peitoral, detalhes, cabeça, costas, ombreiras, antebraços, coxas e botas.
- As peças são parentadas aos ossos do rig (spine, head, arms, thighs e feet), acompanhando animação e rotação do personagem.
- O jogador pode alternar entre os três conjuntos; nove bots recebem variações com cor de equipe.
- O corpo humanoide-base é compartilhado para manter custo de memória e geometria sob controle.

### Humanização e locomoção
- Bots e tropas usam um rig de 18 juntas, incluindo pelve, pés, mãos, tronco em três segmentos, pescoço e cabeça.
- Passada inclui elevação de joelho, rotação de pé, balanço dos braços, movimento das mãos, contrapeso do tronco e movimento sutil da cabeça.
- Bots suavizam o yaw em curvas e inclinam pelve/torso de acordo com a mudança de direção.
- Silhuetas e proporções dos bots variam conforme os papéis de solo, jungle, mid, carry e suporte.
- Herói, bots e tropas são orientados pela normal do terreno compartilhada com o mapa 0.13.0.

### Física integrada
- Criado módulo cinemático nativo ArenaPhysics, compilado junto do simulador C++.
- Movimento do jogador, bots e tropas passa pelo mesmo sistema de aceleração/frenagem, subpassos e colisão.
- Simulação usa passo fixo de 60 Hz com acumulador e limite de subpassos por frame.
- Colisores aproximados correspondem às árvores, rochas, acampamentos, santuários, torres e estruturas de base do cenário.
- Limite da ilha impede sair do campo; resposta de colisão remove velocidade normal e permite deslizar ao longo das superfícies.
- Inclinação excessiva reduz a componente de velocidade para cima da encosta.
- Separação de corpos reduz sobreposição entre jogador, bots e minions ativos.
- Desvio local preventivo redireciona bots/minions em torno de obstáculos próximos; o movimento do jogador permanece diretamente controlado pelo joystick.
- PhysicsWorld.cpp/Jolt permanece desativado no CMake; não existem dois motores disputando a autoridade da posição.

### Testes e distribuição
- Adicionados testes nativos para superfície, colisão com árvore, colisão de estrutura, limite da ilha, frenagem e separação entre personagens.
- O GitHub Actions compila e executa os testes nativos antes de compilar o APK Android.
- Mantidos applicationId, assinatura persistente, landscape, offline, HUB, economia, mapa 0.13.0 e sistemas MOBA.
- versionCode 45 / versionName 0.14.0.
- CI não equivale a validação física no Realme C53. FPS sustentado, temperatura, colisões sentidas nos controles e visual final permanecem pendentes de teste no aparelho.

## [0.13.0] — 2026-11-02

### Reconstrução do campo de batalha
- Substituído o relevo suave anterior por cristas laterais, elevações de aproximação das bases, colinas de selva e depressão fluvial.
- A função de altura do terreno agora é única e compartilhada pelo gerador GLB e pelo renderer; personagens, torres e props consultam a mesma superfície.
- Adicionadas 32 instâncias de árvores distribuídas em quatro quadrantes, clareiras com solo escuro, vegetação rasteira e formações rochosas low-poly.
- Acampamentos deixaram de ser representados por bandeiras: cada um recebeu piso de terra, perímetro de rochas e ruínas baixas.
- Os dois objetivos neutros receberam plataformas elevadas e santuários de pedra próprios, um intacto e outro parcialmente destruído.
- Bases receberam pátios e muralhas baixas nas aproximações. A cena mantém os edifícios, castelos, pontes e torres KayKit sob CC0.
- Adicionada camada de água profunda sob o perímetro rochoso para separar visualmente a ilha do fundo.

### Câmera e controle
- Câmera isométrica passou a manter direção fixa no mundo; a rotação do herói não altera a orientação da câmera.
- Implementada zona morta de 1,85 m: o personagem pode deslocar-se visivelmente na tela antes do acompanhamento suave.
- O acompanhamento da câmera agora usa a altura compartilhada do terreno.
- Eixo vertical do joystick invertido para corresponder à convenção visual da tela: empurrar para cima move o herói para o topo do campo.
- Removidas as bandeiras colocadas sobre pontes e acampamentos como substitutos visuais de objetivos.

### Compatibilidade e validação
- Mantidos 5v5 offline, três rotas, 18 torres, oito acampamentos, dois objetivos, economia, HUD, HUB e animações.
- Kotlin + C++20/NDK e Filament 1.77.3; landscape e package name preservados.
- versionCode 44 / versionName 0.13.0.
- CI valida compilação e estrutura; câmera, leitura de terreno, FPS sustentado, temperatura e toque ainda precisam ser verificados no Realme C53.

## [0.12.0] — 2026-11-02

### Reconstrução de gameplay MOBA
- Snapshot JNI/Kotlin ampliado para 320 valores: 18 torres, 48 slots de tropas, oito acampamentos, objetivos neutros, economia e progressão.
- Três rotas curvas, rio, duas selvas e trilhas de rotação entre acampamentos e rotas.
- Ondas alternadas por rota/equipe: quatro unidades por formação (três corpo a corpo e uma de distância), com até dois grupos ativos e teto fixo de 48 tropas.
- Três torres por rota/equipe; as torres externas ficam próximas ao rio, depois vêm as intermediárias e internas.
- O núcleo fica vulnerável depois da queda das três torres de uma rota; o jogador precisa de cobertura de tropas para atacar torres.
- O Guardião do Rio e a Sentinela Ancestral aparecem em tempos distintos e concedem ouro, XP e bônus temporário de cerco.
- Oito acampamentos neutros com respawn e recompensas.
- IA com papéis de solo, jungler, mid, carry e suporte; o suporte recupera aliados próximos e o carry mantém distância maior nos duelos.
- Ouro, XP, níveis, melhoria de habilidade e três categorias de item durante a partida.
- Minimap conectado a rotas curvas, rio, torres, tropas, acampamentos e objetivos ativos.
- Correções de integração: movimento do jogador aplicado uma vez por frame, recompensas de tropas/acampamentos sem duplicação, campos legados de resultado preservados e timers dos objetivos alinhados.
- Mantidos HUB 0.10.0, animação do herói 0.11.0, Kotlin + C++20/NDK e Filament 1.77.3.
- versionCode 43 / versionName 0.12.0.



## [0.11.0] — 2026-11-02

### Personagem jogável e animação
- Implementado controlador de movimento com estados de repouso, caminhada, corrida, impulso, gesto de habilidade, proteção, reação a dano, queda e retorno.
- A locomoção passou a acompanhar a distância percorrida; a rotação do corpo suaviza mudanças de direção e inclinações respondem à aceleração e frenagem.
- Expandido o rig animado do herói para pelve, tronco em três segmentos, cabeça, mãos, pés, braços e pernas.
- Suavização temporal por osso evita transições instantâneas entre poses.
- Snapshot JNI agora alimenta diretamente os estados de impulso, habilidade, proteção, dano e retorno; botões disparam gestos visuais correspondentes.
- As animações completas permanecem apenas no personagem jogável; bots e tropas preservam o rig reduzido para limitar CPU em celulares intermediários.
- Lyra, Bastion e Kairo recebem cadência, postura e proporções moderadas próprias. A geometria humanoide-base ainda é compartilhada.
- Mantidos Kotlin + C++20/NDK, Filament 1.77.3, HUD, economia offline e regras da partida.
- versionCode 42 / versionName 0.11.0.



## [0.10.0] — 2026-11-02

### HUB e meta progressão
- Adicionadas telas de coleção de skins, loja, missões e perfil, com navegação a partir do menu principal.
- Criado armazenamento local de carteira, XP, nível, partidas, vitórias, skins desbloqueadas e skin equipada.
- Partidas concedem moedas e fragmentos; contrato de três partidas concede recompensa fixa adicional.
- Loja permite trocar 120 fragmentos por 500 moedas; skin alternativa custa 500 moedas e muda a paleta do modelo 3D.
- Economia offline de teste, sem compras reais, rede ou caixas aleatórias.
- versionCode 41 / versionName 0.10.0.


## [0.9.1] — 2026-11-02

### Interface e navegação
- Mantida a composição do menu sobre o cenário 3D; substituído o toque global para iniciar partida por ações explícitas.
- Menu agora apresenta herói em destaque, função, descrição e habilidade; opções JOGAR, HERÓIS, COMO JOGAR e AJUSTES.
- Adicionadas telas de seleção de herói, guia de partida e ajustes de sensibilidade.
- Sensibilidade do direcional tem três presets e é persistida no dispositivo.

### Heróis com funções reais
- Lyra: AURA recupera vida do jogador, bots aliados e tropas próximas, além de causar efeito menor em rivais dentro da área.
- Bastion: IMPACTO tem área/dano maiores, ataque básico pesado e escudo mais duradouro.
- Kairo: ONDA tem recarga mais curta, ataque rápido, deslocamento superior e impulso mais veloz.

### Combate e retorno
- Removido o retorno instantâneo e invisível ao chegar a zero de vida.
- Derrota agora inicia 1,45 s de retorno à base, registra quedas e dá breve janela de invulnerabilidade ao reaparecer.
- Bots e torres deixam de atingir o jogador durante a janela de retorno.
- Snapshot JNI/Kotlin ampliado de 94 para 96 valores, adicionando contador de quedas e tempo restante de retorno.

### Build e validação
- versionCode 40 / versionName 0.9.1.
- O CI compila e verifica o APK; o workflow prepara um pré-lançamento identificável na aba Releases para evitar que o APK fique perdido entre artefatos de rascunhos.
- Build CI não representa teste físico de FPS, temperatura ou controles no Realme C53.

## [0.9.0] — 2026-11-01

### Loop de cerco e vitória por objetivos
- Substituída a vitória por controle abstrato de duas zonas por um objetivo de MOBA: derrubar as três torres da rota e destruir o núcleo inimigo.
- Duplas de tropas em cada rota avançam em ondas, detectam tropas rivais próximas, combatem e retomam o avanço quando vencem.
- Tropas derrotadas reaparecem na base após uma janela de respawn da onda.
- Torres defensivas atacam tropas e heróis adversários em alcance; o estado de cada torre é enviado pelo snapshot JNI e aparece no radar.
- Bots avançam até estruturas, atacam torres e passam a pressionar o núcleo após a queda da torre da sua rota.
- Adicionado GOLPE manual para o jogador; o alvo próximo é priorizado por tipo e alcance. PULSO também atinge tropas.
- HUD atualizado para comunicar progresso das torres, integridade do núcleo, vida e recarga do golpe.
- Snapshot JNI/Kotlin ampliado para 94 valores com vida, seis torres, dois núcleos, recarga do ataque básico e vida das 12 tropas; unidades derrotadas saem da cena e retornam quando a próxima onda renasce.

### Validação
- A atualização usa versionCode 39 / versionName 0.9.0.
- Build/assinatura e teste no Realme C53 ainda precisam ser confirmados nesta versão.

## [0.8.0] — 2026-11-01

### Câmera e personagens
- A câmera inicia na posição real de spawn, reduz o viés lateral e aproxima o enquadramento do herói para mantê-lo fora da área do joystick.
- Bots recebem perfis de silhueta mais distintos por escala e proporção.
- Corrigido o eixo de rotação dos braços: ombros usam rotação local em Z; pernas mantêm o eixo de passada. A correção remove a pose rígida de braços abertos.

### Combate funcional
- Bots interrompem rotas para perseguir e enfrentar heróis rivais próximos.
- Inimigos atacam o jogador ao entrar em alcance; escudo reduz dano recebido.
- Ataque básico automático do jogador, dano, eliminação temporária e respawn.
- PULSO causa dano em área e interrompe ataques; não consome recarga quando não há rival no raio.
- Vida do jogador enviada pelo snapshot JNI e exibida no HUD.

### Mapa
- Canal do rio recortado na malha do terreno; água elevada para permanecer visível entre as margens.
- Materiais de solo terroso e afloramentos rochosos introduzem contraste com a grama.

### Validação
- Atualização preparada para versionCode 38 / versionName 0.8.0. Build CI e validação física no Realme C53 ainda pendentes.


## [0.7.0] — 2026-11-01

### Ambiente CC0 — reconstrução do mapa
- Removidos do cenário os geradores de árvores, pedras, cones, copas esféricas, altar e beacon gigante da versão anterior.
- Importados 12 modelos glTF do KayKit Medieval Hexagon Pack: castelos azul/vermelho, torres azul/vermelho, casas, igrejas, pontes, árvores agrupadas e bandeiras das equipes.
- Licença CC0 1.0 arquivada em ASSETS/KayKit-Medieval-Hexagon-LICENSE.txt.
- Somente modelos ambientais foram importados; não foram incluídos itens ou sistemas armados.
- O mapa passa a ter duas bases, três rotas pavimentadas, rio transversal, três pontes, torres defensivas e bandeiras como pontos de controle.
- O atlas hexagons_medieval.png é compartilhado por todos os modelos via ResourceLoader; os nomes binários originais foram preservados para resolver as URIs glTF.
- WorldGlbBuilder agora gera somente terreno, bordas de estrada, superfície de pedra e água; a arquitetura e vegetação são modelos 3D CC0 instanciados pelo Filament.

### Personagens, animação e tropas
- Corrigida a T-pose: o renderer agora aplica postura de repouso com ombros baixos e cotovelos flexionados.
- Depois de cada atualização de ossos, Animator.updateBoneMatrices() envia a pose para as malhas com skinning do Filament.
- Herói, nove bots e doze tropas usam instâncias independentes do rig, com ciclos esqueléticos de locomoção e postura de repouso.
- Adicionadas doze tropas físicas, duas por equipe em cada uma das três rotas; suas posições são simuladas em C++ e enviadas pelo snapshot JNI de 60 valores.
- As tropas avançam para pontos de encontro e permanecem na zona; a presença delas contribui para a leitura e pontuação das rotas.

### Mantido
- Android nativo em landscape, Kotlin + C++20/NDK e Filament 1.77.3.
- Partidas locais offline 5v5, três rotas, câmera em perspectiva seguindo o herói e controles touch.
- Três perfis selecionáveis: Lyra, Bastion e Kairo.

### Limitações conhecidas
- O elenco ainda compartilha uma geometria humanoide base; a diferenciação visual ocorre por equipe, escala e perfil, não por malhas exclusivas.
- A animação é esquelética procedural no rig e ainda não tem clipes exclusivos por personagem.
- As tropas não têm uma IA de combate completa; avançam e disputam presença na zona.
- Os bots de herói ainda seguem rotas/zonas, sem uma estratégia avançada de formação e objetivos.
- Qualidade visual, estabilidade Vulkan/GLES, FPS sustentado e temperatura precisam de teste no Realme C53.

### Build e assinatura
- versionCode 37 / versionName 0.7.0; applicationId preservado: com.duckdream.neonbreach.
- O workflow exige a chave persistente NEON_BREACH_* em builds de distribuição e verifica package/version/signature.
- Build 0.7.0 verificado no GitHub Actions: run #207 (41344752150), commit `5ffed19af12e7c2c0c7cb72e9a2010de91e8777e`; todas as etapas concluídas com sucesso, incluindo compilação, validação de package/version e assinatura persistente.
- Artefato: `project-arena-0.7.0-update` (artifact ID 13098268857); APK extraído e inspecionado: 17.451.555 bytes; SHA-256 `37444976d7372bd9cf381720ca07299752dafe447e45c283e92344551bc23533`.
- O APK está disponível para teste; a validação em dispositivo físico continua pendente.

## [0.6.0] — 2026-11-01
- Câmera em perspectiva próxima ao herói, follow camera, menu imersivo e HUD compacto.
- Campo retangular com rotas de captura, IA de bots baseada em waypoints, habilidades de suporte/impulso/escudo.
- Assinatura persistente e build 0.6.0 verificada (run #177).
