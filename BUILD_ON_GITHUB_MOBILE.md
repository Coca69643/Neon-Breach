# Publicar y compilar NEON BREACH desde Android

## Estado importante
El repositorio puede tener este workflow, pero el APK solo se compila cuando se publiquen también los archivos fuente del proyecto. No subas el ZIP como único archivo esperando que Actions lo extraiga.

## Arquivos que precisam existir na raiz
- `settings.gradle`
- `build.gradle`
- `gradle.properties`
- `app/build.gradle`
- `app/src/main/AndroidManifest.xml`
- `app/src/main/java/com/duckdream/neonbreach/MainActivity.kt`
- `app/src/main/cpp/CMakeLists.txt`
- `app/src/main/cpp/game.cpp`
- `tools/verify_project.py`
- os recursos de `app/src/main/res/`

A pasta `.github/workflows/android.yml` já é gerenciada pelo repositório; não crie uma segunda cópia com outro nome.

## Pelo celular
1. Extraia o arquivo ZIP no gerenciador de arquivos.
2. No GitHub, abra o repositório e use **Add file → Upload files**.
3. Se o navegador não permitir selecionar pastas, use o app GitHub ou um cliente Git Android que permita adicionar diretórios. Preserve a estrutura relativa acima.
4. Faça commit dos arquivos na branch `main`.
5. Abra **Actions → Build NEON BREACH APK → Run workflow**.
6. Abra a execução. Se o job ficar verde, baixe `neon-breach-debug-apk` na seção **Artifacts**.

## Diagnóstico
- Se falhar em `tools/verify_project.py`, falta arquivo ou caminho.
- Se falhar no Gradle/CMake/Kotlin, abra o log da etapa vermelha e compartilhe o texto do erro.
- Se compilar, isso comprova que o APK foi empacotado; não comprova desempenho, estabilidade nem controles em hardware real.

O workflow é manual para evitar execuções vermelhas antes de o código-fonte completo ser enviado.
