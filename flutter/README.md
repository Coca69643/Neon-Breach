# Projeto Arena — Flutter Foundation 0.1

Base de migração para Android, com Flutter/Dart na aplicação e runtime 3D próprio em C++20/OpenGL ES. Não utiliza engine.

## Estado

- Máquina de estados da aplicação: implementada.
- Máquina de estados inicial de bots/minions em C++20: implementada e compilada localmente.
- Validação do manifesto local: implementada.
- Orientação landscape: configurada.
- Testes da FSM nativa: aprovados localmente.
- Testes Flutter: definidos no CI; ainda não executados neste ambiente.
- Host Android Flutter, renderizador e APK: ainda não integrados.

## Validar o pacote Flutter

Com Flutter stable instalado:

```bash
cd flutter
flutter pub get
flutter analyze
flutter test
```

O host Android ainda não foi gerado nesta etapa; portanto, `flutter run` e a instalação de APK ficam para a próxima integração.

A tela atual é uma fundação de fluxo, não uma build jogável. A seleção de herói e o estado MATCH_LOADING validam o fluxo; nenhuma partida é apresentada como funcional antes da conexão do runtime nativo.
