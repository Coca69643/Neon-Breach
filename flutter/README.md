# Projeto Arena — Flutter Scene Foundation 0.2

Migração do runtime 3D para Flutter Scene. Flutter/Dart controla a aplicação e a FSM; Flutter Scene fornece o scene graph e a renderização 3D. Não há runtime C++ ou OpenGL ES manual nesta arquitetura.

## Stack fixada

- Flutter 3.47 stable ou superior
- Dart 3.10 ou superior
- flutter_scene: 0.24.3
- Android landscape, offline-first
- Identidade: com.duckdream.projectarena
- Próximo código de versão: 60 (acima da versão instalada 59)

## Política visual e desempenho

- Sem sombras dinâmicas.
- PBR com iluminação de ambiente controlada e materiais bem trabalhados.
- Assets orgânicos com rigs e animações; geometria primitiva só em testes técnicos.
- Meta inicial: 30 FPS sustentados no Realme C53.
- LOD, instancing, culling e limites de partículas/transparências fazem parte do orçamento mobile.

## Status

- Máquina de estados de aplicação em Dart: implementada.
- Validação do manifesto offline: implementada.
- Dependência Flutter Scene: fixada.
- Build hook de assets: implementado.
- Script reproduzível do host Android, Flutter GPU e landscape: implementado.
- Preview 3D dos três heróis CC0 com clips Idle via SceneModel: implementado; renderização ainda não validada em dispositivo.
- Bootstrap dos recursos estáticos Flutter Scene: implementado.
- APK: ainda não gerada.

## Comandos de validação

~~~bash
cd flutter
python3 tool/prepare_android.py
flutter pub get
flutter analyze
flutter test
flutter run --enable-flutter-gpu
~~~

Assets estáticos devem ficar em assets/ e ser pré-processados pelo hook do Flutter Scene. Consulte https://fscene.dev/getting-started/installation/.
