# Projeto Arena 0.11.0 — controlador de movimento do herói

## Objetivo
Reduzir rigidez sem trocar a engine, reimportar uma malha não validada ou aumentar o custo de animação de todos os personagens simultaneamente.

## Pipeline
1. O snapshot JNI entrega posição, velocidade, vida, duração de impulso, habilidade ativa, proteção e tempo de retorno.
2. MainActivity encaminha o snapshot ao renderer antes da atualização de pose.
3. O renderer escolhe o estado de movimento e produz uma pose-alvo.
4. Cada junta do herói faz blend temporal da pose atual para a pose-alvo.
5. Animator.updateBoneMatrices() envia o resultado ao skinning do Filament.

## Estados
- IDLE: respiração leve e postura estável.
- WALK / RUN: ciclo de passada derivado da distância percorrida, com balanço recíproco de braços e pernas.
- DASH: inclinação curta e compensação dos braços; a duração vem do estado nativo.
- CAST: gesto estilizado de habilidade acionado pelo snapshot e pelo botão.
- GUARD: postura compacta enquanto a proteção está ativa.
- HIT: reação corporal curta quando a vida diminui.
- DOWN / RESPAWN: pose baixa e retorno gradual à postura neutra.

As prioridades evitam que uma pose de repouso sobrescreva impulso, dano ou retorno.

## Orçamento móvel
- Apenas o jogador usa o conjunto estendido de juntas.
- Bots e tropas mantêm os 11 ossos anteriores.
- Nenhum novo renderer, engine ou pacote de runtime foi adicionado.
- As atualizações usam delta time limitado a 50 ms para evitar saltos de pose após pausas de frame.

## Verificações
O verificador estrutural lê o GLB embarcado e confirma a presença das juntas exigidas, do skin humanoide e das conexões entre snapshot, estados e botões. O CI confirma compilação Android e integridade do APK.

## Limitações honestas
- O mesmo mesh humanoide base ainda é compartilhado pelos três heróis; perfis de postura e proporção não equivalem a modelos exclusivos.
- A animação é procedural por poses, não um conjunto importado de clipes.
- O CI não prova qualidade visual, FPS sustentado, temperatura ou estabilidade no Realme C53. Esses pontos exigem teste físico.
