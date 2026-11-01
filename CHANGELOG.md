# Changelog — Projeto Arena

## [0.2.0] — 2026-11-01

### Mudança de direção
- A linha evolui de uma arena individual de captura para um MOBA 3D com partidas locais **offline 5v5**.
- A arquitetura de partida não depende de conta, login, matchmaking, servidor ou conexão com a internet.
- A identidade visual e os nomes de heróis são originais/provisórios; Deadlock é referência de estrutura de gênero, não de conteúdo copiado.

### Adicionado
- Partida local 5v5: jogador + quatro bots aliados contra cinco bots adversários.
- Três rotas jogáveis (oeste, centro e leste), cada uma com pressão e condição de conquista independentes.
- IA local para bots: avanço por rota, seleção de alvos próximos, interrupção de oponentes e retorno à formação após desativação.
- Ondas simplificadas de tropas locais que afetam a pressão de cada rota.
- Três arquétipos selecionáveis: Lyra (suporte), Bastion (defesa) e Kairo (mobilidade).
- Habilidades estilizadas sem armas: impulso de mobilidade, pulso de ressonância em área e barreira defensiva.
- HUD de partida com cronômetro, placar, progresso das rotas e minimapa tático.
- Nove unidades visuais adicionais integradas ao cenário glTF para representar os bots.
- Estruturas defensivas distribuídas pelas três rotas.

### Base técnica
- Android nativo, paisagem obrigatória, renderização Filament 1.77.3 com Vulkan e fallback OpenGL ES.
- Simulação de partida em C++20; interface, ciclo de vida e controles em Kotlin.
- Compilador Kotlin externo 2.4.10 configurado para alinhar o build às bibliotecas Filament, com Kotlin integrado do AGP 9 desativado nesta linha.
- Gradle 9.6.0, Android Gradle Plugin 9.5.0 e compileSdk 37.
- CI exige verificação estrutural, compilação, existência do APK e upload do artefato.

### Limitações conhecidas
- Esta é a primeira fatia funcional da partida offline, não um MOBA de produção: IA, tropas, economia e pressão de rotas são simplificadas.
- Ainda não há seleção extensa de heróis, loja, árvore de progressão, objetivos neutros avançados, campanha ou rede.
- Os avatares dos bots são representações low-poly próprias; não reutilizam o rig completo do personagem principal.
- Vulkan/GLES, estabilidade, memória, temperatura e FPS prolongado ainda precisam ser testados no Realme C53. Build de CI não equivale a teste físico no aparelho.

### Verificação da entrega
- O APK só será considerado publicado quando o workflow terminar com sucesso, verificar o arquivo app-debug.apk e enviar o artefato project-arena-0.2.0-debug.
- Resultado do workflow e artefato: pendentes até a conclusão do build 0.2.0.
