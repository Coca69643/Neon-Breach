# Projeto Arena — Flutter Scene Foundation 0.3

Migração do runtime 3D para Flutter Scene. Flutter/Dart controla a aplicação e a FSM; Flutter Scene fornece o scene graph e a renderização 3D. Não há runtime C++ ou OpenGL ES manual nesta arquitetura.

## Stack fixada

- Flutter 3.47 stable ou superior
- Dart 3.10 ou superior
- flutter_scene: 0.24.3
- Android landscape, offline-first
- applicationId: com.duckdream.projectarena
- Nome instalado: Projeto Arena
- minSdk: 24 (Android 7.0 ou superior)
- versionName/versionCode: 0.17.1 / 61
- APK de CI: ARM64 para aparelhos Android atuais, incluindo o Realme C53

## Política visual e desempenho

- Sem sombras dinâmicas.
- PBR com iluminação de ambiente controlada e materiais bem trabalhados.
- Assets orgânicos com rigs e animações; geometria primitiva só em testes técnicos.
- Meta inicial: 30 FPS sustentados no Realme C53.
- LOD, instancing, culling e limites de partículas/transparências fazem parte do orçamento mobile.

## Identidade e assinatura Android

O host Android gerado reutiliza o ícone vetorial e a identidade "Projeto Arena" já existentes no repositório. O applicationId permanece idêntico ao APK 0.16.0, e o versionCode é maior que 59.

Builds de CI carregam o mesmo keystore persistente usado pelo pipeline Android anterior (variáveis NEON_BREACH_KEYSTORE_*). Isso preserva a assinatura necessária para atualizar uma instalação existente. Builds locais sem essas variáveis usam a assinatura de debug do Flutter e não devem ser tratados como APK de atualização.

O minSdk é 24 porque as versões atuais do Flutter elevaram o mínimo Android suportado para API 24.

## Status técnico

- Máquina de estados de aplicação em Dart: implementada.
- Validação do manifesto offline: implementada.
- Dependência Flutter Scene: fixada em 0.24.3.
- Build hook e pré-processamento de modelos/materiais: implementados.
- Menu principal com cenário 3D de tela cheia, herói em destaque e CTA periférico inspirado na composição de hubs de Project R.I.S.E.; sem cartões opacos.
- Preview 3D dos três heróis CC0 com clips Idle via SceneModel: integrado; renderização ainda não validada em aparelho.
- Pipeline offline do Vale das Coroas: terreno GLB texturizado, rio curvo e quatro modelos CC0.
- Prévia do mundo em MATCH_LOADING: integrada como visualização, explicitamente sem gameplay.
- Verificador de release: checa package id, versionamento, orientação, Flutter GPU, minSdk, ABI e assets pré-processados.
- CI: análise estática, testes, build ARM64 e verificação da assinatura.
- APK: compilação ARM64 assinada e validada no CI; validação visual, FPS sustentado, temperatura e atualização sobre a instalação anterior ainda exigem teste no aparelho.

## Comandos

~~~bash
cd flutter
python3 -m pip install -r tool/requirements-world.txt
python3 tool/prepare_world_assets.py
python3 tool/prepare_android.py
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
python3 tool/verify_release_apk.py build/app/outputs/flutter-apk/app-release.apk
~~~

Para assinar uma atualização compatível com instalações existentes, configure as quatro variáveis NEON_BREACH_KEYSTORE_* antes de executar prepare_android.py e o build. Consulte https://fscene.dev/getting-started/installation/.
