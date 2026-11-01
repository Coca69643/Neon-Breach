# Changelog — Projeto Arena

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
