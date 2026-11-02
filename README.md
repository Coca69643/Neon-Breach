# Projeto Arena 0.15.0

MOBA 3D nativo para Android, landscape e offline. A 0.15.0 revisa o relevo do campo, a silhueta dos heróis, a articulação dos braços e a composição do HUB. Preserva a física cinemática, sistemas 5v5, progressão offline e a câmera isométrica fixa durante a partida.

## Revisão visual e de apresentação 0.15.0

- Relevo do campo ampliado: cristas laterais, elevações nas aproximações das bases, lombadas de selva e terraços periféricos com maior variação vertical.
- Malha do terreno refinada de 104 para 144 divisões por eixo; caminhos de pedra mais estreitos para recuperar a leitura de grama, rio e bordas.
- Paleta do solo e da iluminação ajustada para reduzir o domínio ciano e reforçar a separação entre grama, terra, pedra e água.
- Fórmula de altura mantida idêntica no gerador de terreno Kotlin e no módulo de física C++; personagens e colisores consultam a mesma altura.
- Lyra ganha caudas de manto em camadas; Bastion recebe ombreiras largas, crista de elmo e placas mais pesadas; Kairo recebe capuz e faixas assimétricas.
- Posição de repouso dos braços revisada: ângulos mais baixos, flexão combinada e balanço menor para reduzir a pose rígida em V.
- Proporções dos slots de tropas diferenciadas entre unidades corpo a corpo, de distância e pesadas.
- HUB reorganizado com o herói em destaque, animação idle no menu, botões secundários discretos e uma única ação principal. Coleção, loja e missões saem da coluna de botões grandes.
- Câmera do menu aproximada para apresentar o herói; a câmera de partida permanece separada.
- CI testa a integridade dos GLBs gerados e verifica a sincronização do relevo entre renderer e física.


## Modelagem, humanização e física 0.14.0

- Três conjuntos de equipamento modelados proceduralmente para Lyra, Bastion e Kairo: peitoral, ombreiras, antebraços, coxas, botas, cabeça e manto.
- As peças são instâncias GLB leves parentadas aos ossos correspondentes; o corpo humanoide-base continua compartilhado para limitar memória e draw calls.
- Bots recebem conjuntos compatíveis com a equipe; a movimentação usa proporções e animação corporal conforme a função.
- Rig animado expandido para jogadores, bots e minions, com passada, apoio de pés, movimento de mãos, contrapeso do tronco, cabeça e suavização de curvas/frenagem.
- Herói, bots e minions usam uma transformação alinhada à normal da superfície para acompanhar encostas do terreno 0.13.0.
- Física cinemática nativa em C++ com passo fixo de 60 Hz, aceleração/frenagem limitadas, subpassos, deslizamento em colisões, limite de inclinação e contenção na ilha.
- Colisores estáticos correspondem a árvores, pedras, clareiras, muralhas, torres e santuários. Separação física evita sobreposição entre jogador, bots e tropas.
- Bots e tropas usam desvio local preventivo de obstáculos; o joystick do jogador mantém controle direto.
- A simulação C++ é a autoridade para posição/velocidade; o renderer apenas apresenta as transformações e animações.
- Testes nativos no CI cobrem superfície, colisão com árvores/estruturas, limites, frenagem e separação entre corpos.

## MOBA 0.12.0 — estrutura de gameplay

- 5v5 local: jogador + quatro aliados controlados pela IA contra cinco adversários.
- Papéis de IA: solo, jungler, mid, carry e suporte. O herói escolhido define o papel inicial do jogador; os bots completam os quatro papéis restantes.
- Três rotas com curvas próprias, conectadas por rio e passagens para as duas selvas.
- Oito acampamentos neutros em posições espelhadas; derrotá-los concede ouro e XP e eles reaparecem após um intervalo.
- Ondas com três unidades corpo a corpo e uma unidade de distância por rota/equipe. Dois grupos alternados permitem até 48 tropas ativas sem crescimento ilimitado; grupos sobreviventes não são teleportados.
- Cada rota tem três torres por equipe. As torres priorizam tropas inimigas em alcance; o jogador precisa de uma onda aliada para pressionar estruturas.
- O núcleo só fica vulnerável depois que uma rota inteira perde suas três torres defensivas.
- Guardião do Rio e Sentinela Ancestral aparecem em tempos distintos. Derrotá-los concede ouro, XP e bônus temporário de cerco.
- IA de rota acompanha a frente das tropas, entra em confrontos próximos e pressiona estruturas com cobertura. Junglers limpam acampamentos e podem rotacionar para objetivos; carries preferem distância; suportes recuperam aliados.
- Economia de partida separada da economia do HUB: ouro, XP, níveis, melhorias de habilidade e três famílias de itens compráveis.
- Minimap mostra rotas, rio, torres em três níveis, tropas, heróis, acampamentos e objetivos ativos.

## Personagens e animação 0.11.0

- Controlador de estados para repouso, caminhada, corrida, impulso, habilidade, proteção, reação a dano, queda e retorno.
- Passadas derivadas do deslocamento, transições suaves por junta e inclinação em curvas, aceleração e frenagem.
- Rig ampliado apenas no herói jogável; bots e tropas mantêm rig reduzido para controlar custo de CPU.
- Snapshot nativo conecta movimento, combate e eventos de gameplay ao renderer.
- Lyra, Bastion e Kairo ocupam papéis iniciais distintos. A malha humanoide-base permanece compartilhada.

## HUB e progressão offline 0.10.0

- Menu com telas de heróis, guia, ajustes, skins, loja, missões e perfil.
- Carteira local com Moedas de Arena e Fragmentos; partidas concedem recompensas fixas e contrato a cada três partidas.
- Skins de preço fixo e loja de troca de fragmentos, sem compras reais, servidor ou caixas aleatórias.
- XP, nível, partidas, vitórias, carteira e cosméticos persistidos com SharedPreferences.

## Mapa e apresentação 0.13.0 (preservado)

- Terreno esculpido com cristas laterais, colinas nas aproximações das bases, pequenas elevações na selva e vale fluvial.
- Três rotas pavimentadas curvas com acostamentos, conectores de terra e três pontes no rio.
- Quatro quadrantes de selva com 32 instâncias de árvores, manchas de solo, vegetação rasteira e formações rochosas low-poly.
- Oito acampamentos com clareiras físicas, piso de terra e anéis de rocha; os marcadores de bandeira foram removidos da representação do objetivo.
- Dois santuários de pedra modelados na geometria do mapa, um intacto e outro em ruínas.
- Aproximações das bases com muralhas baixas e pátios, além dos castelos, casas e igrejas KayKit.
- A função de altura do terreno é compartilhada pelo gerador da malha e pelo renderer para manter heróis, bots, torres e vegetação apoiados no relevo.
- Câmera isométrica com direção fixa; a rotação do herói não gira a câmera. O herói se desloca na tela dentro de uma zona morta de 1,85 m antes do acompanhamento.
- O eixo vertical do joystick foi alinhado com a direção superior/inferior da tela.
- Geometria de ambiente procedural permanece integrada no GLB de runtime; edifícios, pontes e árvores usam modelos KayKit CC0 1.0. Humanoide Quaternius CC0 1.0.

## Stack e distribuição

- Android nativo: Kotlin + C++20/NDK.
- Filament 1.77.3, Vulkan preferencial e fallback OpenGL ES.
- Orientação landscape fixa; funcionamento offline; sem WebView.
- applicationId: com.duckdream.neonbreach.
- versionCode 46 / versionName 0.15.0.
- APK de atualização usa a chave persistente NEON_BREACH_*.

## Limitações conhecidas

- A partida é offline contra IA; não há matchmaking, servidores ou cinco jogadores humanos por equipe.
- O corpo humanoide Quaternius continua compartilhado; a 0.15.0 amplia a distinção por equipamento articulado e proporções. Ainda não existem três malhas corporais completas produzidas independentemente.
- Os santuários dos objetivos agora têm geometria própria, mas ainda não incluem criaturas-chefes com malhas e animações exclusivas.
- Esta é uma base MOBA jogável, ainda sem Fog of War, seleção manual de alvo, draft, inventário de múltiplos espaços ou estratégia de equipe avançada.
- O CI executa testes determinísticos de física e compila/assina o APK, mas não substitui teste visual e de desempenho no Realme C53: FPS sustentado, temperatura, câmera, colisões percebidas, leitura do mapa e controles touch ainda precisam ser medidos no aparelho.
- A física 0.14.0 usa colisores cinemáticos aproximados de cenário; ainda não há navegação inteligente completa em torno de todos os obstáculos nem física rígida dinâmica para cada prop.
