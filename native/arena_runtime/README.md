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
