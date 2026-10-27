# NEON BREACH 0.5.0 — Android nativo

Protótipo nativo de Duck Dream Studios para Android: Kotlin controla o ciclo de vida e o toque; C++17/NDK e OpenGL ES 3.0 renderizam a arena em landscape. O alvo inicial de teste é Android de entrada, incluindo o Realme C53.

## O que entrou na versão 0.5.0

- Movimento por arrasto no lado esquerdo da tela.
- Disparo contínuo enquanto mantém o toque no lado direito, mirando no ponto tocado.
- Quatro inimigos perseguem o jogador e causam dano ao contato.
- Projéteis, colisão de acerto, inimigos derrotados, indicador de vida e contagem visual de hostis restantes.
- Workflow GitHub Actions com validação, build do APK debug e upload de artefato.

## Compilar e instalar

1. Abra [GitHub Actions](https://github.com/Coca69643/Neon-Breach/actions).
2. Abra a execução mais recente de **Build NEON BREACH APK** que esteja verde.
3. Em **Artifacts**, baixe `neon-breach-debug-apk`.
4. Extraia o ZIP e instale o APK no Android.

## Estado real e próximos passos

Esta versão é uma fatia de gameplay inicial, não um jogo completo nem um lançamento de produção. A arte continua procedural e a interface não tem tipografia de missão completa. Ainda faltam menus, objetivos de extração com estado visual/textual claro, áudio, persistência, mais variedade de inimigos/armas, tratamento completo de pausa/fim de missão e testes em aparelho físico. A compilação verde confirma que o APK foi empacotado; não confirma sozinha a qualidade visual, equilíbrio, consumo térmico ou estabilidade no Realme C53.

## Estrutura principal

- `app/src/main/java/com/duckdream/neonbreach/MainActivity.kt`
- `app/src/main/cpp/game.cpp`
- `app/src/main/cpp/CMakeLists.txt`
- `.github/workflows/android.yml`
- `tools/verify_project.py`
