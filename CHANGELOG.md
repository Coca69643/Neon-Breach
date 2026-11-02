# Changelog — Projeto Arena

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
