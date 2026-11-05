# Arena Native Runtime

Diretório reservado ao runtime C++20 próprio do Projeto Arena.

Não é uma engine e não deve receber dependências de engines. O módulo será separado em:
- platform/android: ciclo de vida, EGL e superfície;
- renderer: OpenGL ES, shaders, materiais, câmera e culling;
- assets: parsing e validação glTF/GLB;
- animation: skeletons, skinning e blending;
- simulation: timestep, colisão e movimento;
- gameplay: estados de heróis, bots, minions e objetivos.

A implementação começa somente após o contrato Flutter/plugin de superfície estar definido. Nenhum renderizador funcional está declarado neste commit.

## Núcleo de máquina de estados de agentes

Já implementado:
- `include/arena/ai/agent_state_machine.hpp`
- `src/ai/agent_state_machine.cpp`
- `tests/agent_state_machine_test.cpp`

Estados: `Idle`, `Patrol`, `AcquireTarget`, `Approach`, `Attack`, `Retreat`, `Dead`.

Bots podem entrar em recuo quando a condição de saúde é crítica; minions seguem a política de retorno à patrulha quando perdem o alvo. Transições inválidas não alteram o estado e `Dead` é terminal.

Teste local:

```bash
cmake -S native/arena_runtime -B build/arena-agent-fsm
cmake --build build/arena-agent-fsm
ctest --test-dir build/arena-agent-fsm --output-on-failure
```

Este núcleo não implementa ainda percepção, navegação, decisão tática, animação ou combate; ele formaliza e testa o fluxo comportamental que esses sistemas irão acionar.
