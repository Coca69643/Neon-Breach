# NEON BREACH — Android nativo

Projeto de jogo Android em landscape, com Kotlin para o ciclo de vida e entrada, C++17/NDK para simulação e OpenGL ES 3.0 para renderização.

## Estado do repositório

O workflow **Build NEON BREACH APK** foi configurado em `.github/workflows/android.yml` e pode ser executado manualmente na aba **Actions**. O workflow só compilará depois que os arquivos-fonte Android estiverem presentes na raiz do repositório.

Estrutura necessária:
- `settings.gradle`
- `build.gradle`
- `gradle.properties`
- `app/build.gradle`
- `app/src/main/AndroidManifest.xml`
- `app/src/main/java/com/duckdream/neonbreach/MainActivity.kt`
- `app/src/main/cpp/CMakeLists.txt`
- `app/src/main/cpp/game.cpp`
- `tools/verify_project.py`

Consulte [BUILD_ON_GITHUB_MOBILE.md](BUILD_ON_GITHUB_MOBILE.md) para as etapas pelo celular.

**Importante:** o workflow não transforma um ZIP em APK automaticamente. O conteúdo do projeto precisa ser extraído e publicado mantendo os caminhos acima. Um build verde confirma compilação, não valida gameplay ou desempenho em aparelho real.
