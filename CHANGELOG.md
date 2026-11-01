# Changelog — Projeto Arena

## [0.4.0] — 2026-11-01

MOBA offline 5v5 para Android, com partidas locais contra bots.

### IA e navegação
- Removida a perseguição por alvo móvel entre bots e jogador, que causava trocas contínuas de alvo e trajetórias orbitais.
- Cada unidade agora mantém uma rota e um slot de formação persistentes: equipe, faixa, posição lateral e linha de avanço.
- Navegação por chegada com frenagem baseada em distância e aceleração; a unidade desacelera e para no ponto da rota, sem ultrapassar o destino.
- Bots deixam de usar a posição do herói como alvo de navegação. O joystick do jogador não altera a rota dos NPCs.
- Bots temporariamente desativados retornam à formação de sua rota quando a recuperação termina.
- Pressão das rotas considera apenas unidades que realmente alcançaram a zona de disputa, em vez de contar todos os bots desde a base.

### Identidade do aplicativo
- Substituído o ícone legado do ORION-9 por um emblema próprio do Projeto Arena: fortaleza, três rotas e núcleo energético azul.
- Nome do aplicativo simplificado para Projeto Arena.
- Versão Android avançada para 0.4.0 (versionCode 34).

### Mantido
- Partida 5v5 totalmente offline, com jogador, quatro aliados e cinco bots adversários.
- Três rotas e habilidades fictícias sem armas.
- Android nativo landscape, Filament 1.77.3, Kotlin e simulação C++20.

### Limitações conhecidas
- A IA atual faz avanço/posicionamento por rota e disputa de zona; comportamento tático avançado, papéis complexos e objetivos completos continuam em desenvolvimento.
- O modelo humanoide e o mapa precisam continuar evoluindo; esta atualização corrige a lógica orbital, não certifica a qualidade visual geral.
- Teste de execução, renderização Vulkan/GLES, FPS sustentado e temperatura no Realme C53 ainda pendentes.

### Verificação da entrega
- O APK 0.4.0 só será considerado entregue após o CI compilar, confirmar app-debug.apk e publicar project-arena-0.4.0-debug.
- Run e checksum serão adicionados após a validação do artefato.

## [0.3.0] — 2026-11-01
- Corrigida a orientação das faces arredondadas e adicionada luz indireta.
- Terreno arredondado, rotas com bordas legíveis e bots humanoides instanciados.
- Câmera de overview para menu/pausa e câmera de acompanhamento durante a partida.
- CI gerou o APK 0.3.0; teste físico no aparelho permaneceu pendente.

## [0.2.0] — 2026-11-01
- Primeira fatia de MOBA offline 5v5, com três rotas, bots, heróis e habilidades.
- Base Android nativa em landscape com Filament 1.77.3, Kotlin e C++20.
