# Projeto Arena — Flutter Foundation 0.1

Base de migração para Android, com Flutter/Dart na aplicação e um runtime 3D próprio em C++20/OpenGL ES. Não utiliza engine.

## Estado

- Máquina de estados da aplicação: implementada.
- Validação do manifesto local: implementada.
- Orientação landscape: configurada.
- Testes de transição: adicionados.
- Runtime nativo e renderização 3D: ainda não integrados.

## Executar

Com Flutter stable instalado:

```bash
cd flutter
flutter pub get
flutter analyze
flutter test
flutter run
```

A tela atual é uma fundação de fluxo, não uma build jogável. A seleção de herói e o estado MATCH_LOADING existem para validar o fluxo; a partida só será liberada quando o runtime nativo estiver conectado e validado.
