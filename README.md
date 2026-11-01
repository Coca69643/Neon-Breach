# Projeto Arena 0.7.0

MOBA-lite 3D para Android, landscape e totalmente offline, com herói controlável, bots locais, tropas visíveis e três rotas de controle.

## Reconstrução visual 0.7.0
- O campo antigo de árvores, cones e esferas e o altar procedural foram removidos.
- O ambiente agora usa 12 modelos glTF do KayKit Medieval Hexagon Pack: castelos azul/vermelho, torres, casas, igrejas, pontes, agrupamentos de árvores e bandeiras.
- O pack é CC0 1.0. Somente peças de ambiente foram importadas; o jogo não incorpora itens ou mecânicas armadas.
- O mapa tem duas bases, três rotas de pedra, um rio transversal com três pontes, torres por rota e bandeiras nas áreas de controle.
- O atlas de textura compartilhado é carregado uma vez pelo ResourceLoader do Filament.
- A malha de runtime ficou restrita ao terreno, às estradas e ao rio; não gera mais a vegetação decorativa repetitiva da versão anterior.

## Personagens e unidades
- O rig Quaternius CC0 continua sendo o modelo humanoide base.
- A pose de repouso agora baixa os braços e dobra levemente os cotovelos.
- A locomoção aplica ciclos esqueléticos de caminhada/corrida e chama Animator.updateBoneMatrices() em cada instância, incluindo herói, bots e tropas.
- Nove bots locais movem-se por rotas próprias.
- Doze tropas físicas (duas por equipe em cada uma das três rotas) avançam até a zona central e ficam visíveis na partida.

## Regras da partida
- 1 jogador + 4 bots aliados contra 5 bots adversários.
- Três rotas; controlar e manter duas vence a partida.
- Tropas contribuem para a presença de rota; escudo reforça a captura, pulso interrompe temporariamente unidades próximas e impulso reposiciona o herói.
- Sem login, servidor, matchmaking ou conexão com a internet.

## Stack e distribuição
- Android nativo Kotlin + C++20/NDK.
- Filament 1.77.3, Vulkan preferencial e fallback OpenGL ES.
- applicationId: com.duckdream.neonbreach.
- versionCode 37 / versionName 0.7.0.
- APK de atualização usa a chave persistente NEON_BREACH_*.

## Limitações conhecidas
- Herói, bots e tropas ainda compartilham a mesma geometria humanoide CC0; equipes e tropas variam por cor e escala, mas não há ainda silhuetas exclusivas por função.
- A animação é esquelética procedural no rig; ainda não há um conjunto completo de clipes exclusivos por herói.
- As tropas avançam e sustentam presença na rota; não há ainda um sistema de combate ou minion AI completo.
- A IA dos heróis continua baseada em rotas e zonas, sem estratégia avançada de equipe.
- CI não substitui teste físico no Realme C53: câmera, qualidade visual, FPS sustentado, memória e temperatura ainda precisam de validação no aparelho.
