# Projeto Arena 0.11.0

MOBA-lite 3D nativo para Android, landscape e offline: herói controlável, 5v5 local com bots, três rotas de cerco, ondas de tropas, torres defensivas e núcleo.

## Movimento e animação do herói 0.11.0
- O herói jogável usa um controlador de estados: repouso, caminhada, corrida, impulso, gesto de habilidade, proteção, reação a dano, estado de queda e retorno.
- As transições por osso usam suavização temporal; a fase do passo acompanha a distância percorrida, reduzindo deslizamento quando a velocidade muda.
- O rig do herói foi ampliado para incluir pelve, tronco superior, cabeça, mãos e pés; bots e tropas mantêm o conjunto menor de ossos para limitar custo de CPU.
- Posição, velocidade, impulso, habilidade ativa, proteção, variação de vida e retorno são lidos do snapshot nativo. Os botões também disparam os gestos correspondentes.
- Lyra, Bastion e Kairo usam cadências e posturas diferentes, sem deformações extremas de escala. A malha base ainda é compartilhada; não são três modelos exclusivos.
- Não há nova engine, dependência de runtime ou mudança na simulação nativa do MOBA.

## HUB e progressão offline 0.10.0
- Menu expandido com telas de skins, loja, missões e perfil, mantendo o modo MOBA 5v5 e suas três rotas.
- Carteira local com Moedas de Arena e Fragmentos; partidas concedem recompensas fixas, com bônus de contrato a cada três partidas.
- Loja troca fragmentos por moedas; skins têm preço fixo, podem ser equipadas e alteram a paleta do herói no preview 3D.
- XP, nível, partidas, vitórias, moedas, fragmentos e desbloqueios são persistidos localmente em SharedPreferences versionadas.
- Economia demonstrativa offline: sem compras reais, servidor ou recompensas aleatórias.

## Reconstrução visual 0.8.0
- O campo antigo de árvores, cones e esferas e o altar procedural foram removidos.
- O ambiente base ainda usa 12 modelos glTF do KayKit Medieval Hexagon Pack: castelos azul/vermelho, torres, casas, igrejas, pontes, agrupamentos de árvores e bandeiras.
- O pack é CC0 1.0. Somente peças de ambiente foram importadas; o jogo não incorpora itens ou mecânicas armadas.
- O mapa tem duas bases, três rotas de pedra, um rio transversal com três pontes, torres por rota e bandeiras nas áreas de controle.
- O atlas de textura compartilhado é carregado uma vez pelo ResourceLoader do Filament.
- A malha de runtime ficou restrita ao terreno, às estradas e ao rio; não gera mais a vegetação decorativa repetitiva da versão anterior.

## Evolução 0.9.1
- Menu principal preserva a apresentação 3D do herói e agora separa JOGAR, HERÓIS, COMO JOGAR e AJUSTES; tocar no cenário não inicia uma partida.
- Seleção de herói explica função e habilidade antes da confirmação.
- Lyra usa AURA para recuperar aliados próximos e enfraquecer rivais dentro da área.
- Bastion tem IMPACTO de maior alcance/dano, ataque pesado e escudo prolongado.
- Kairo tem ONDA de recarga reduzida, ataque rápido e impulso mais veloz.
- A sensibilidade do direcional possui três níveis persistidos localmente.
- O jogador agora passa por uma janela de retorno de 1,45 s após ser derrotado; o HUD mostra o tempo restante e o total de quedas.

## Loop de cerco 0.9.0
- A vitória deixa de depender de controle abstrato de duas zonas: é necessário derrubar as três torres da rota atacante e reduzir a vida do núcleo inimigo a zero.
- Duplas de tropas por rota procuram tropas rivais próximas, entram em combate, empurram a rota quando vencem e reaparecem em novas ondas após serem derrotadas.
- Torres defensivas atacam tropas e heróis adversários em alcance; o radar indica torres ativas e destruídas.
- Bots avançam pela rota, interrompem o avanço para duelar e atacam torres ou núcleo quando o caminho está livre.
- O jogador usa GOLPE manual, com seleção automática do alvo válido mais próximo em alcance: herói, tropa, torre ou núcleo.
- O HUD exibe vida, quedas, recarga do golpe, progresso das torres e integridade do núcleo.

## Personagens e unidades
- Corrigido o eixo de rotação dos ombros; braços agora descem da pose horizontal e acompanham a passada.
- Silhuetas de bots pesados, ágeis e equilibrados têm proporções mais distintas, embora ainda compartilhem a malha base.
- O rig Quaternius CC0 continua sendo o modelo humanoide base.
- A pose de repouso agora baixa os braços e dobra levemente os cotovelos.
- A locomoção aplica ciclos esqueléticos de caminhada/corrida e chama Animator.updateBoneMatrices() em cada instância, incluindo herói, bots e tropas.
- Nove bots locais movem-se por rotas próprias.
- Doze tropas físicas formam duplas por equipe em cada rota, avançam, combatem tropas rivais e retornam como novas ondas após serem derrotadas.

## Regras da partida
- Bots enfrentam unidades rivais próximas e perseguem o jogador quando ele entra em alcance.
- O jogador usa GOLPE manual para atingir o alvo válido mais próximo; heróis controlados pela IA mantêm ataques contextuais.
- 1 jogador + 4 bots aliados contra 5 bots adversários.
- Três rotas de cerco; derrubar as torres e destruir o núcleo inimigo vence a partida.
- AURA (Lyra), IMPACTO (Bastion) ou ONDA (Kairo) varia por herói; ESCUDO reduz dano recebido; IMPULSO reposiciona na direção do joystick.
- O HUD exibe vida e quedas; derrotas acionam retorno temporizado à base.
- Sem login, servidor, matchmaking ou conexão com a internet.

## Mundo e câmera
- A câmera inicia no spawn real, reduz o deslocamento lateral e aproxima o enquadramento do personagem para evitar sobreposição com a área do joystick.
- O rio agora ocupa um canal recortado no terreno, com água visível; materiais de solo terroso e rocha quebram a superfície verde uniforme.

## Stack e distribuição
- Android nativo Kotlin + C++20/NDK.
- Filament 1.77.3, Vulkan preferencial e fallback OpenGL ES.
- applicationId: com.duckdream.neonbreach.
- versionCode 42 / versionName 0.11.0.
- APK de atualização usa a chave persistente NEON_BREACH_*.

## Limitações conhecidas
- Herói, bots e tropas ainda compartilham a mesma geometria humanoide CC0; equipes e tropas variam por cor e escala, mas não há ainda silhuetas exclusivas por função.
- A animação do herói agora é stateful e suavizada por osso, mas ainda é procedural; a malha base continua compartilhada entre os três heróis.
- As tropas já combatem em cada rota e reaparecem em ondas, mas usam apenas duas unidades homogêneas por equipe/rota; a IA de formação e de cerco ainda é simplificada.
- A IA dos heróis ainda é local e simplificada; não existe seleção de alvo manual por unidade nem comportamento avançado de equipe.
- O 0.9.1 amplia o loop de cerco e diferencia as funções dos heróis, mas ainda não é um MOBA completo: tropas são duplas homogêneas, não há objetivos de selva, itens, níveis ou habilidades exclusivas por herói. CI não substitui teste físico no Realme C53: câmera, FPS sustentado, memória, temperatura e estabilidade precisam ser medidos no aparelho.
