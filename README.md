# Projeto Arena 0.9.0

MOBA-lite 3D nativo para Android, landscape e offline: herói controlável, 5v5 local com bots, três rotas de cerco, ondas de tropas, torres defensivas e núcleo.

## Reconstrução visual 0.8.0
- O campo antigo de árvores, cones e esferas e o altar procedural foram removidos.
- O ambiente base ainda usa 12 modelos glTF do KayKit Medieval Hexagon Pack: castelos azul/vermelho, torres, casas, igrejas, pontes, agrupamentos de árvores e bandeiras.
- O pack é CC0 1.0. Somente peças de ambiente foram importadas; o jogo não incorpora itens ou mecânicas armadas.
- O mapa tem duas bases, três rotas de pedra, um rio transversal com três pontes, torres por rota e bandeiras nas áreas de controle.
- O atlas de textura compartilhado é carregado uma vez pelo ResourceLoader do Filament.
- A malha de runtime ficou restrita ao terreno, às estradas e ao rio; não gera mais a vegetação decorativa repetitiva da versão anterior.

## Loop de cerco 0.9.0
- A vitória deixa de depender de controle abstrato de duas zonas: é necessário derrubar as três torres da rota atacante e reduzir a vida do núcleo inimigo a zero.
- Duplas de tropas por rota procuram tropas rivais próximas, entram em combate, empurram a rota quando vencem e reaparecem em novas ondas após serem derrotadas.
- Torres defensivas atacam tropas e heróis adversários em alcance; o radar indica torres ativas e destruídas.
- Bots avançam pela rota, interrompem o avanço para duelar e atacam torres ou núcleo quando o caminho está livre.
- O jogador recebe o comando GOLPE, com seleção automática do alvo válido mais próximo em alcance: herói, tropa, torre ou núcleo.
- O HUD exibe a vida do jogador, recarga do golpe, progresso das torres e integridade do núcleo.

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
- PULSO afeta heróis e tropas em área; ESCUDO reduz dano recebido; IMPULSO reposiciona na direção do joystick.
- O HUD exibe a vida atual do jogador.
- Sem login, servidor, matchmaking ou conexão com a internet.

## Mundo e câmera
- A câmera inicia no spawn real, reduz o deslocamento lateral e aproxima o enquadramento do personagem para evitar sobreposição com a área do joystick.
- O rio agora ocupa um canal recortado no terreno, com água visível; materiais de solo terroso e rocha quebram a superfície verde uniforme.

## Stack e distribuição
- Android nativo Kotlin + C++20/NDK.
- Filament 1.77.3, Vulkan preferencial e fallback OpenGL ES.
- applicationId: com.duckdream.neonbreach.
- versionCode 39 / versionName 0.9.0.
- APK de atualização usa a chave persistente NEON_BREACH_*.

## Limitações conhecidas
- Herói, bots e tropas ainda compartilham a mesma geometria humanoide CC0; equipes e tropas variam por cor e escala, mas não há ainda silhuetas exclusivas por função.
- A animação é esquelética procedural no rig; ainda não há um conjunto completo de clipes exclusivos por herói.
- As tropas já combatem em cada rota e reaparecem em ondas, mas usam apenas duas unidades homogêneas por equipe/rota; a IA de formação e de cerco ainda é simplificada.
- A IA dos heróis ainda é local e simplificada; não existe seleção de alvo manual por unidade nem comportamento avançado de equipe.
- O 0.9.0 implementa o primeiro loop de cerco jogável, mas ainda não é um MOBA completo: tropas são duplas homogêneas, não há objetivos de selva, itens, níveis ou habilidades exclusivas por herói. CI não substitui teste físico no Realme C53: câmera, FPS sustentado, memória, temperatura e estabilidade precisam ser medidos no aparelho.
