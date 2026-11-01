# Changelog — Projeto Arena

## [0.5.0] — 2026-11-01

### IA e navegação independentes
- Removida a realimentação circular em que o progresso da rota deslocava a linha de avanço e a nova linha alterava novamente o progresso.
- Cada bot percorre waypoints fixos da sua própria rota; a posição do jogador e o placar das rotas não são entradas da navegação.
- Progressão dos waypoints é monotônica durante cada avanço; unidades param no destino em vez de orbitar um alvo móvel.
- Cadência de saída e velocidade variam por unidade para evitar que os nove bots iniciem e se desloquem como um único bloco sincronizado.
- Slots de rota permanecem separados por equipe/faixa.
- Pressão da rota é calculada em uma zona central fixa, independente da posição dinâmica do objetivo.
- Snapshot nativo inclui a velocidade vetorial do jogador.
- Orientação do herói usa o vetor real de movimento; quando parado, preserva a última direção. A rotação não depende mais da posição absoluta do herói em relação à origem.

### Identidade visual
- Ícone redesenhado: silhueta de herói mascarado, visor violeta/ciano e rotas convergentes.
- Removida a composição antiga de fortaleza/cristal e qualquer referência visual do ORION-9.
- Nome de exibição simplificado para Projeto Arena.

### Mantido
- Partidas Android nativas, landscape e totalmente offline.
- Equipes locais com bots, três rotas e habilidades fictícias sem armas.
- Kotlin, C++20, Filament 1.77.3, Vulkan e fallback OpenGL ES.
- Modelos humanoides CC0 instanciados para as unidades.

### Limitações e validação
- A navegação é determinística por rota; decisões táticas avançadas, papéis complexos e objetivos completos ainda precisam de evolução.
- CI comprova compilação e integridade do pacote, não a ausência visual de órbitas em todos os cenários.
- Teste físico no Realme C53 continua obrigatório para validar movimento, renderização, FPS e temperatura.
- APK 0.5.0 será marcado como entregue somente após o workflow compilar, verificar o APK e publicar o artefato correspondente.

## [0.4.0] — 2026-11-01
- Primeira separação de navegação dos bots em relação ao jogador, com slots de formação e frenagem de chegada.
- Ícone vetorial de fortaleza e três rotas, substituindo a referência antiga do ORION-9.
- CI run #143 gerou project-arena-0.4.0-debug; revisão 0.5.0 remove a realimentação de placar/linha de avanço e corrige a orientação do herói.

## [0.3.0] — 2026-11-01
- Corrigida a orientação das faces arredondadas e adicionada luz indireta.
- Terreno arredondado, rotas com bordas legíveis e bots humanoides instanciados.
