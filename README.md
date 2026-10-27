# NEON BREACH 0.6.0 — protótipo 3D nativo para Android

Projeto mobile-first de Duck Dream Studios, com orientação landscape fixa e sem engine: Kotlin cuida do ciclo de vida/entrada; C++17, NDK e OpenGL ES 3.0 fazem a simulação e a renderização 3D.

## Correção central da 0.6.0

A versão anterior desenhava o setor por meio de um shader de tela cheia com formas 2D. Isso não correspondia ao objetivo de um jogo top-down 3D. A versão 0.6.0 substitui esse renderer por uma cena volumétrica com câmera em perspectiva, profundidade, malhas de cubos e esferas, iluminação direcional, piso, paredes, obstáculos elevados, unidades tridimensionais e plataforma de extração.

## O que esta versão contém

- Cena 3D com perspectiva e buffer de profundidade.
- Piso modular, limites elevados, obstáculos com colisão e terminais do cenário.
- Unidades com silhuetas distintas, movimento de perseguição e barras de integridade.
- Movimento e mira em áreas independentes, com IDs de ponteiros para dois dedos simultâneos.
- Simulação com passo fixo e delta de tempo limitado após interrupções.
- Indicadores visuais de integridade, unidades restantes e estado da extração.
- Renderer de emergência e registro de erro para que uma falha de shader seja diagnosticável.
- GitHub Actions para validar fontes, compilar APK debug e publicar o artefato.

## Controles

Segure e arraste no lado esquerdo para deslocar a unidade. No lado direito, toque e arraste a partir do ponto inicial para direcionar a mira; mantenha o dedo pressionado para continuar a ação. Depois que todas as unidades hostis forem neutralizadas, alcance a plataforma verde de extração. Se a integridade acabar, toque para reiniciar a missão.

## Compilar e instalar

1. Abra [GitHub Actions](https://github.com/Coca69643/Neon-Breach/actions).
2. Escolha a execução mais recente de **Build NEON BREACH APK** com conclusão verde.
3. Em **Artifacts**, baixe `neon-breach-debug-apk`.
4. Extraia o ZIP e instale o APK no Android.

## Limitações que ainda precisam ser resolvidas

Esta é uma fatia de gameplay 3D inicial, não um jogo completo nem um build de produção. A arte ainda é procedural; faltam áudio, menus de verdade, texto de missão integrado, persistência, fases e variedade ampla de conteúdos. Os testes automáticos confirmam compilação e verificações estáticas, mas não confirmam que a renderização e os controles funcionem corretamente no Realme C53. É necessário instalar a 0.6.0 e testar no aparelho, incluindo temperatura e estabilidade em sessão prolongada.

## Arquivos principais

- `app/src/main/java/com/duckdream/neonbreach/MainActivity.kt`
- `app/src/main/cpp/game.cpp`
- `app/src/main/cpp/CMakeLists.txt`
- `app/build.gradle`
- `.github/workflows/android.yml`
- `tools/verify_project.py`
