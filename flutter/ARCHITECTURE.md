# Projeto Arena — arquitetura Flutter / runtime próprio

## Decisão técnica

Flutter é a camada de aplicação, não uma engine de jogo. O projeto não usa Godot, Unity, Unreal, Flame, Filament ou outra engine.

- **Flutter/Dart:** inicialização, menus, HUD, input de toque, configurações, ciclo de vida e máquina de estados da aplicação.
- **C++20 + Android NDK:** runtime 3D próprio, simulação de alta frequência, física, animação, IA dos bots/minions e gerenciamento de recursos.
- **OpenGL ES:** renderização nativa no Android, com detecção de capacidades do dispositivo.
- **Dart FFI:** comandos e leitura de snapshots em lotes; não haverá uma chamada FFI por entidade ou por frame.
- **Flutter Texture / plugin Android:** apresentação no Flutter da superfície produzida pelo renderizador nativo. FFI isoladamente não registra uma textura de plataforma.

## Máquina de estados

A primeira implementação está em `lib/game/state/arena_state_machine.dart`.

Fluxo principal:

`BOOT → ASSET_VALIDATION → MAIN_MENU → HERO_SELECTION → MATCH_LOADING → IN_MATCH`

Estados laterais:

- `PAUSED`: pausa manual ou interrupção do ciclo de vida Android.
- `MATCH_RESULT`: resultado formal da partida.
- `RECOVERABLE_ERROR`: falha com estado-alvo explícito para recuperação.

Regras:
1. A interface envia eventos; não altera o estado diretamente.
2. Transições inválidas são rejeitadas e não notificam a UI.
3. Uma seleção de herói precisa ser válida antes de iniciar o carregamento.
4. Pausa manual não é removida automaticamente quando o app volta ao primeiro plano.
5. A recuperação preserva o estágio que precisa ser repetido.
6. Os testes unitários verificam o fluxo e os invariantes sem depender de renderização.

A máquina de estados da aplicação não substitui a IA dos personagens. Bots e minions terão máquinas de estados próprias no runtime nativo, com estados e transições determinísticos.

## Renderizador nativo — próxima integração

A integração proposta será um plugin Android estreito, sem engine:

1. Criar e controlar o contexto EGL/OpenGL ES no lado nativo.
2. Expor a saída através do registro de texturas de plataforma do Flutter.
3. Usar FFI para comandos de alto nível, input agregado e snapshots.
4. Manter simulação e render loop fora do isolate de UI.
5. Recriar recursos de GPU quando a superfície ou o contexto forem perdidos.
6. Validar suporte real do dispositivo antes de exigir recursos específicos de OpenGL ES.

O loader glTF/GLB será um módulo independente com validação explícita de buffers, imagens, materiais, skins e canais de animação. Bibliotecas de parsing poderão ser consideradas isoladamente, após revisão de licença; isso não autoriza incluir uma engine.

## Escopo da fundação 0.1

Implementado nesta etapa:
- pacote Flutter isolado em `flutter/`;
- orientação landscape;
- manifesto local e validação do contrato de conteúdo;
- máquina de estados da aplicação;
- seleção lógica dos três heróis existentes;
- testes automatizados de transição, pausa, retomada e recuperação.

Ainda não implementado:
- host Android Flutter definitivo;
- plugin de textura/OpenGL ES;
- renderizador 3D, loader GLB, animação ou física;
- HUD de combate, rede ou simulação de partida.

A validação atual do manifesto **não** afirma que modelos GLB ou texturas já foram auditados. A etapa de assets 3D terá verificações próprias antes de qualquer partida ser liberada.

## Critérios para avançar

Uma etapa só será considerada concluída depois de:
- análise estática e testes automatizados aprovados;
- lifecycle Android testado sem perder o estado;
- teste de superfície/contexto OpenGL em dispositivo real;
- teste prolongado de temperatura e estabilidade no Realme C53;
- APK instalado e executado no dispositivo, não apenas compilado.
