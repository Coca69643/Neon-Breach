# NEON BREACH — compilar e baixar pelo Android

O repositório já contém os arquivos-base do projeto e o workflow de build.

## Baixar o APK
1. Abra [Actions do NEON BREACH](https://github.com/Coca69643/Neon-Breach/actions).
2. Entre na execução **Build NEON BREACH APK** mais recente.
3. Aguarde o job terminar. Se estiver verde, abra **Artifacts**.
4. Baixe `neon-breach-debug-apk`, extraia o ZIP do artefato e instale o APK no Android. O Android pode pedir autorização para instalar a partir da fonte escolhida.

## Se o build falhar
- Abra a execução vermelha e encontre a primeira etapa com erro.
- Copie o trecho do log que contém a causa original; a última linha pode ser apenas um resumo.
- A verificação estática só confere arquivos e algumas condições do código. A compilação é a confirmação de que o APK foi empacotado.

## Estado e limitações do jogo
Esta versão é um protótipo técnico nativo. A cena OpenGL é procedural e tem movimento de toque básico, setor, cobertura e inimigos animados. Ainda não representa o jogo completo: faltam sistemas completos de combate, armas, IA, objetivos, áudio, menus e persistência. Mesmo com build verde, ainda é necessário testar instalação, resposta ao toque, aquecimento e estabilidade no Realme C53.
