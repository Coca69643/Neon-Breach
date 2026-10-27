# NEON BREACH — Android nativo

Protótipo Android nativo para Duck Dream Studios: Kotlin para ciclo de vida/entrada, C++17/NDK e OpenGL ES 3.0. Orientação fixa em landscape; o renderizador usa uma cena procedural de setor industrial neon e unidades inimigas animadas.

## Estado atual

- Código Android e renderizador nativo publicados.
- GitHub Actions compila automaticamente em alterações relevantes na branch `main`; também pode ser executado manualmente em **Actions**.
- O workflow valida os caminhos essenciais, executa `gradle assembleDebug` e publica o artefato `neon-breach-debug-apk` por 14 dias quando o build passa.

**Limites importantes:** isto ainda é um protótipo técnico jogável, não uma versão completa de NEON BREACH. O cenário e os inimigos são desenhados proceduralmente; ainda faltam combate completo, armas/projéteis, IA de combate, objetivos reais, áudio, menus, salvamento e testes de desempenho em aparelho físico. A verificação estática não substitui a compilação nem o teste no Realme C53.

## Estrutura

- `settings.gradle`, `build.gradle`, `gradle.properties`
- `app/build.gradle`
- `app/src/main/AndroidManifest.xml`
- `app/src/main/java/com/duckdream/neonbreach/MainActivity.kt`
- `app/src/main/cpp/CMakeLists.txt`
- `app/src/main/cpp/game.cpp`
- `tools/verify_project.py`
- `.github/workflows/android.yml`

Consulte [BUILD_ON_GITHUB_MOBILE.md](BUILD_ON_GITHUB_MOBILE.md) para baixar o APK pelo celular.
