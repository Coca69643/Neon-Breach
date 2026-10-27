# NEON BREACH 0.6.0 — baixar o APK pelo Android

## Baixar
1. Abra [Actions do NEON BREACH](https://github.com/Coca69643/Neon-Breach/actions).
2. Abra a execução mais recente de **Build NEON BREACH APK** com status verde.
3. Em **Artifacts**, baixe `neon-breach-debug-apk`.
4. Extraia o ZIP e instale o APK. Caso o Android solicite, autorize a instalação a partir do aplicativo usado para abrir o arquivo.

## Esta versão
A 0.6.0 troca a cena procedural plana por um renderer com perspectiva 3D, profundidade, piso/parede com volume, obstáculos elevados, unidades tridimensionais, colisão e suporte a dois dedos em controles separados.

## Se ainda aparecer uma tela preta
O build verde confirma apenas que o APK foi compilado. No aparelho:
- confirme que instalou o artefato da execução mais recente;
- se a tela continuar preta, abra uma issue no repositório incluindo modelo do aparelho, versão Android e logs de `NeonBreach` do Logcat;
- não use um artefato antigo após uma correção mais recente.

## Testes pendentes
Esta versão ainda é protótipo. Precisa ser testada no Realme C53, incluindo iniciação da cena, movimento e mira simultâneos, colisão, missão concluída/derrota, retomada após minimizar e aquecimento em sessão prolongada. A verificação estática e o build do GitHub não substituem esses testes.
