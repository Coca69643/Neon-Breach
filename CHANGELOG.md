# Changelog — Projeto Arena

Todas as mudanças relevantes desta linha de desenvolvimento são registradas aqui.

## [0.1.0] — 2026-11-01

### Adicionado
- Nova base Android nativa em orientação landscape.
- Renderer Filament 1.77.3 com tentativa de backend Vulkan e fallback para OpenGL ES.
- Simulação nativa C++20 separada da renderização.
- Movimento com aceleração, desaceleração, impulso de mobilidade e colisão com obstáculos.
- Câmera top-down ortográfica com acompanhamento suave.
- Mundo glTF gerado no runtime com terreno contínuo, caminhos curvos, riacho, vegetação, rochas e marco central.
- Personagem humanoide rigged da Quaternius Universal Base Characters, distribuído sob CC0 1.0, com licença guardada em `ASSETS/`.
- Animação procedural de locomoção aplicada à hierarquia de ossos do personagem.
- Controles mobile: joystick virtual, impulso, HUD de captura, pausa e resultado.
- Estados distintos para inicialização, renderer, menu, partida, pausa, resultado e recuperação.

### Alterado
- A direção do projeto deixa de ser o shooter ORION-9 e passa a ser uma arena de controle territorial por equipes, sem armas.
- O código antigo de simulação e renderização OpenGL/C++17 deixou de fazer parte do caminho de build desta branch.
- Toolchain atualizada para Android Gradle Plugin 9.5.0, Gradle 9.6.0 e Android compileSdk 37 para atender aos requisitos do Filament 1.77.3.

### Limitações conhecidas da 0.1.0
- É uma fatia vertical individual de exploração e captura territorial, não uma partida MOBA completa.
- Ainda não há partidas 5v5, bots, rede online, seleção de heróis, rotas com tropas ou progressão de personagens.
- O caminho Vulkan e o fallback GLES precisam ser exercitados em aparelhos reais; a compilação não comprova compatibilidade de cada GPU.
- A resposta térmica, consumo de memória e desempenho prolongado ainda precisam ser medidos em dispositivos de entrada.
- Nome e ícone são provisórios; a pesquisa de identidade será feita após a validação visual da primeira versão.

### Verificação
- A verificação estrutural do projeto passou no workflow inicial.
- A primeira compilação foi bloqueada porque Filament 1.77.3 exige compileSdk 37 e a base estava em compileSdk 35. A toolchain foi atualizada para corrigir isso; o resultado do novo build será registrado quando terminar.
