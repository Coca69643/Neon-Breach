# Projeto Arena 0.6.0

Arena 3D nativa para Android, partidas locais 5v5 contra bots, totalmente offline e em landscape.

## Revisão 0.6.0
- Câmera de jogo em perspectiva, próxima ao herói e com seguimento pela direção de movimento.
- Herói e bots ampliados no enquadramento.
- Menu imersivo com personagem em destaque e uma única ação de entrada.
- HUD reduzido a cronômetro, progresso do objetivo, minimapa e controles essenciais.
- Campo de jogo retangular, com relevo mais pronunciado e três corredores.
- Bots avançam até zonas de controle, ocupam posições laterais por equipe e permanecem disputando o objetivo em vez de atravessar a arena em órbita.
- Escudo passa a reforçar a captura enquanto estiver ativo; pulso interrompe temporariamente bots adversários próximos; impulso melhora reposicionamento.

## Stack
- Android nativo Kotlin + C++20/NDK.
- Filament 1.77.3, Vulkan e fallback OpenGL ES.
- Modelos humanoides Quaternius CC0 instanciados.
- Sem login, servidor ou permissão de internet.

## Distribuição
- applicationId preservado: com.duckdream.neonbreach.
- versionCode 36 / versionName 0.6.0.
- Builds de distribuição usam a chave persistente configurada nos secrets NEON_BREACH_*; builds de PR não são distribuíveis porque não recebem os secrets.

## Validação pendente
Compilação e testes estruturais não substituem teste físico. A câmera, visibilidade de bots, resposta do controle, legibilidade, FPS sustentado e temperatura precisam ser verificados no Realme C53.
