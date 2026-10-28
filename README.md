# NEON BREACH 0.11.0

**NEON BREACH** é um jogo de ação e tiro em 3D visto de cima, desenvolvido pela Duck Dream Studios para Android. A proposta é entrar em instalações futuristas, enfrentar diferentes tipos de inimigos, ativar sistemas e encontrar uma rota de extração.

O projeto ainda está em desenvolvimento. A ideia é construir um jogo mobile de verdade, com controles pensados para a tela sensível ao toque e uma identidade visual própria — não apenas uma demonstração técnica.

## Sobre o jogo

NEON BREACH é feito com código próprio: Kotlin cuida da parte Android e dos controles, enquanto C++17 e OpenGL ES 3.0 são usados na simulação e na apresentação 3D. Os personagens, as arenas e os efeitos atuais são gerados por código, sem modelos ou texturas gráficas importados e sem uma engine de jogo tradicional.

O foco agora é dar personalidade ao mundo, diferenciar as criaturas, melhorar a leitura dos objetivos e acertar os controles. Esta versão continua em desenvolvimento e precisa ser testada em dispositivos reais.

## Log de atualizações

### 0.11.0 — Mira e disparo sem confusão

- Substituído o botão retangular de disparo por um controle circular com ícone de munição, rótulo **ATIRAR** e feedback visual ao manter pressionado.
- Separação explícita entre as ações: arrastar o lado direito controla a mira; manter **ATIRAR** pressionado dispara continuamente; soltar ou cancelar o toque interrompe o fogo.
- Redimensionados e reposicionados os controles de tiro e esquiva, preservando alvos de toque confortáveis e o espaço do botão de interação.
- Atualizadas as instruções de controle e o identificador da versão dentro do jogo.
- Reforçada a verificação do projeto para validar o novo controle e a versão 0.11.0.

### 0.10.0 — Fronteira selvagem

- Cenário refeito como uma clareira orgânica com solo terroso, vegetação, árvores e pedras irregulares geradas por código.
- Personagem principal redesenhado com volumes mais suaves; as quatro criaturas agora têm silhuetas e anatomias diferentes.
- Corrigida a conversão vertical do joystick e o eixo vertical da mira.
- Adicionados brotos restauradores opcionais que recuperam parte da vitalidade e focos de esporos que avisam antes de causar dano.
- Menu, HUD e botões atualizados para combinar com o novo ambiente, com menos azul, menos painéis pesados e cantos mais suaves.

### 0.9.0 — Controles e combate

- Adicionado joystick virtual para movimentação.
- Separado o botão de disparo, com mira por arrasto no lado direito da tela.
- Melhorada a orientação do personagem e adicionada uma esquiva com recarga.
- Incluídos inimigos com comportamentos diferentes: perseguição, ataque pesado anunciado e disparos à distância.
- Adicionadas três variações de arena, obstáculos que bloqueiam projéteis e ajustes no HUD.

### 0.8.0 — Personagens 3D

- Introduzidos personagens humanoides construídos a partir de malhas geradas pelo próprio jogo.
- Adicionados armadura, capacete com visor, mochila e arma.
- Criadas animações procedurais para braços, pernas e movimento corporal.
- Melhoradas a iluminação e a leitura dos volumes 3D.

### 0.7.1 — Identidade do aplicativo

- Definido um ícone próprio para o aplicativo Android.
- Preservados o menu, o HUD, a pausa, as configurações e as telas de resultado introduzidas na versão anterior.

## Como baixar e instalar

1. Abra a página [GitHub Actions](https://github.com/Coca69643/Neon-Breach/actions).
2. Entre na execução mais recente que terminou com sucesso (marca verde).
3. Na seção **Artifacts**, baixe o arquivo `neon-breach-debug-apk`.
4. Abra o ZIP baixado e extraia o APK para o celular.
5. Toque no arquivo APK para instalar. Se o Android pedir autorização para instalar aplicativos dessa origem, permita apenas para o aplicativo que você usou para abrir o arquivo e continue se confiar no APK.

---

*NEON BREACH está em desenvolvimento. As mudanças descritas registram o estado do projeto; a compilação de uma versão, por si só, não significa que todos os recursos tenham sido validados em um dispositivo físico.*
