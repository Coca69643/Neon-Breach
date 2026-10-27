# NEON BREACH 0.7.0 — Protocolo de Ruptura

Jogo de ação 3D top-down nativo para Android, desenvolvido pela Duck Dream Studios sem engine tradicional. Kotlin cuida do ciclo de vida, entrada e interface; C++17/NDK e OpenGL ES 3.0 executam a simulação e o renderer.

## Novidades da 0.7.0

- Menu principal em tela cheia com cenário 3D ao fundo: iniciar operação, continuar uma operação suspensa e configurações.
- HUD de missão com integridade, relés desativados, hostis neutralizados e objetivo atual.
- Sistema de pausa, retomada, reinício e telas de vitória/derrota com navegação funcional.
- Configuração persistente de vibração da interface.
- Objetivo "Protocolo de Ruptura": aproxime-se dos três relés distribuídos no setor e pressione **Desativar Relé**. A rede muda de vermelho para verde conforme os relés são desligados.
- A extração só termina a missão depois de desativar os três relés e neutralizar todos os hostis.
- Snapshot atômico do estado entre a simulação C++ e a interface Kotlin, sem ler diretamente variáveis de gameplay em threads diferentes.
- Build automatizado e verificações estáticas para os novos contratos de interface e gameplay.

## Controles

- **Lado esquerdo:** arraste para mover.
- **Lado direito:** toque e arraste para mirar; mantenha o dedo pressionado para disparar.
- **Desativar relé:** aproxime-se de uma consola, espere o botão ficar ativo e toque nele.
- **Pausar:** abre a pausa sem perder o estado da missão.
- Depois de desligar os três relés e eliminar todos os hostis, alcance o marcador de extração. Se a integridade chegar a zero, use **Tentar novamente**.

## Compilar e instalar pelo Android

1. Abra [GitHub Actions](https://github.com/Coca69643/Neon-Breach/actions).
2. Escolha a execução mais recente de **Build NEON BREACH APK** com conclusão verde.
3. Em **Artifacts**, baixe `neon-breach-debug-apk`.
4. Extraia o ZIP e instale o APK.

## Estado real e limitações

A 0.7.0 melhora o fluxo de jogo e acrescenta uma camada de interface nativa, mas continua sendo um protótipo em evolução. Os modelos do cenário ainda são gerados por malhas básicas em C++; não há biblioteca de modelos glTF integrada, áudio de combate, animações esqueléticas nem variedade ampla de níveis. A mudança de cor da rede é visual e está ligada ao estado dos relés; sistemas avançados de portas ou barreiras dinâmicas ainda não estão incluídos.

O build verde confirma compilação e empacotamento, não a qualidade do jogo no aparelho. É necessário testar no Realme C53: menu, toque simultâneo, interação com todos os relés, combate, extração, pausa/retomada e estabilidade em sessões prolongadas.

## Arquivos centrais

- `app/src/main/java/com/duckdream/neonbreach/MainActivity.kt` — menu, HUD, pausa, resultados, controles multitoque.
- `app/src/main/cpp/game.cpp` — simulação, colisões, relés, combate e renderer 3D.
- `app/src/main/cpp/CMakeLists.txt` — biblioteca C++.
- `tools/verify_project.py` — verificações estáticas.
- `.github/workflows/android.yml` — build APK.
