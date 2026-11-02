# Projeto Arena 0.12.0

MOBA 3D nativo para Android, landscape e offline. Esta versão reúne o HUB e a animação anteriores com a reconstrução da gameplay: três rotas curvas, duas selvas, ondas alternadas, três camadas de torre por rota, dois objetivos neutros, IA com cinco papéis e progressão dentro da partida.

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

## Mapa e apresentação

- Terreno de vale com três rotas curvas pavimentadas, rio transversal, pontes e trilhas de terra.
- Duas áreas de selva, oito acampamentos marcados no chão e duas áreas de objetivo neutro ao longo do rio.
- Três torres por rota em cada lado, com posições externas, intermediárias e internas.
- Modelos ambientais do KayKit Medieval Hexagon Pack sob CC0 1.0; humanoide Quaternius sob CC0 1.0.
- A cena não usa imagens externas em runtime.

## Stack e distribuição

- Android nativo: Kotlin + C++20/NDK.
- Filament 1.77.3, Vulkan preferencial e fallback OpenGL ES.
- Orientação landscape fixa; funcionamento offline; sem WebView.
- applicationId: com.duckdream.neonbreach.
- versionCode 43 / versionName 0.12.0.
- APK de atualização usa a chave persistente NEON_BREACH_*.

## Limitações conhecidas

- A partida é offline contra IA; não há matchmaking, servidores ou cinco jogadores humanos por equipe.
- Os três heróis ainda compartilham uma geometria-base; papéis e kits são diferenciados, mas não há três malhas exclusivas.
- Os objetivos neutros usam marcos de mapa e marcadores funcionais, não modelos animados dedicados de chefes.
- Esta é uma base MOBA jogável, ainda sem Fog of War, seleção manual de alvo, draft, inventário de múltiplos espaços ou estratégia de equipe avançada.
- CI não substitui validação física no Realme C53: FPS sustentado, temperatura, câmera, minimapa, controles touch e estabilidade precisam ser medidos no aparelho.
