# NEON BREACH 0.4

**Nova linha de desenvolvimento:** a numeração recomeça em 0.1. O Passo 1 estabelece a direção visual Stylized Game Art com iluminação toon de três bandas e pós-processamento de lente. As versões anteriores permanecem abaixo somente como histórico técnico da base existente.

**NEON BREACH** é um shooter tático 3D top-down nativo para Android. A operação começa no **Site ORION-9**, uma instalação de pesquisa bioexperimental atingida por uma falha de contenção. A contenção evolui por setores: após 20 eliminações, a passagem leste se abre e revela uma nova ala com identidade cromática própria.

O ciclo da missão está explícito: restaurar três relés, conter quatro ameaças e alcançar a zona de extração. O projeto continua em desenvolvimento e requer validação em dispositivos reais.

A missão reúne três relés, 24 ameaças organizadas em seis ondas e uma extração localizada no Setor 2.

## Sobre o jogo
Kotlin gerencia a camada Android e os controles; C++17 com OpenGL ES 3.0 executa a simulação e a renderização. O projeto não depende de uma engine tradicional nem de modelos gráficos importados.

## Log de atualizações

### 0.4 — Setores interconectados, novos operadores e identidade visual
- Adiciona `ProgressionManager.cpp`: cada eliminação atualiza a progressão e 20 eliminações expandem os limites jogáveis, abrem a passagem leste e liberam o Setor 2 com paleta enviada por uniform ao shader.
- Organiza 24 inimigos em seis ondas de quatro; as primeiras cinco ondas levam ao desbloqueio do novo setor e a sexta ocorre na nova ala antes da extração.
- Troca a seleção anterior por Neon-Vanguard (azul, velocidade padrão, tiro duplo) e Stellar-Reaper (dourado, velocidade +20%, disparo em cone).
- Acrescenta deslocamento de vértices com ruído multiescala à malha orgânica procedural.
- Implementa configuração persistente de som e sensibilidade de toque via SharedPreferences; a sensibilidade chega ao C++ por JNI e os efeitos de feedback usam ToneGenerator do Android.
- Define jogador azul/dourado, inimigos carmesim e projéteis aliados verde-limão; compila o renderer com `-O3`.
- Atualiza a versão Android para 0.4 e versionCode 19.

### 0.3 — Variabilidade de IA e renderização instanciada (Passo 3)
- Introduz slalom nos inimigos, com força lateral senoidal e fase, frequência e amplitude sorteadas por unidade via C++17 `<random>`.
- Dessincroniza as decisões táticas com atrasos iniciais aleatórios e intervalos de 75–145 ms; movimento e colisões continuam integrados a cada tick fixo.
- Agrupa projéteis aliados e hostis em um único draw indexado instanciado, usando buffer dinâmico e `glDrawElementsInstanced`.
- Acrescenta validação GLSL dos shaders de projéteis instanciados ao GitHub Actions.
- Atualiza a versão Android para 0.3 e versionCode 18.

### 0.2 — Game Feel mecânico (Passo 2)
- Troca o acompanhamento exponencial da câmera por uma mola linear amortecida com velocidade própria, integração em subpassos e resposta suavemente elástica.
- Aplica squash & stretch procedural ao corpo completo do operador: expansão lateral no eixo local X e compressão de profundidade no eixo local Z, com atenuação exponencial e janela de 150 ms após cada disparo.
- Adiciona um gerenciador nativo de camera shake por ruído suave interpolado; disparos geram impulsos pequenos e impactos recebidos geram impulsos mais fortes. O deslocamento é aplicado à matriz de visão antes de formar cada uMVP.
- Atualiza o rótulo Android para 0.2 e incrementa versionCode para 17.

### 0.1 — Stylized Game Art (Passo 1)
- Substitui a resposta difusa contínua por três bandas discretas de iluminação toon: sombra, meio-tom e luz.
- Adiciona um passe de pós-processamento OpenGL ES com vinheta de borda e aberração cromática sutil, por deslocamento dos canais vermelho e azul.
- Renderiza a cena em framebuffer limitado a 1600 × 900 para conter o custo de memória, com fallback para renderização direta se o framebuffer não puder ser criado.
- Atualiza o rótulo Android para 0.1. O versionCode passa para 16, mantendo a progressão monotônica exigida para atualizações Android.

### Histórico da linha anterior

### 0.13.0 — Instalação industrial e câmera dinâmica
- Remove as árvores, plantas e manchas de musgo da área jogável; o cenário passa a ser uma instalação com painéis metálicos, divisões de piso, anteparo de descontaminação, tubulações de serviço, painéis de diagnóstico, lâmpadas industriais e marcações de segurança.
- Adiciona acompanhamento suave da câmera durante a operação, mantendo a leitura do mapa; menu e configurações recuperam o enquadramento neutro.
- Ajusta a névoa atmosférica para uma paleta fria e industrial.
- Atualiza o rótulo visível e os metadados Android para 0.13.0 / versionCode 15.
- A compilação confirma que o APK foi empacotado; aparência, conforto da câmera e desempenho continuam dependendo do teste em dispositivo físico.

### 0.12.0 — Equipe ORION-9
- Adicionada seleção persistente de três operadores com papéis funcionais: Kestrel (mobilidade/esquiva), Bastion (resistência e dano) e Patch (cadência, alcance de interação e recuperação médica).
- Os atributos alteram velocidade, intervalo de disparo, dano, mitigação recebida, recarga da esquiva, cura e alcance de restauração de relés.
- Materiais e proporções corporais diferenciados por operador.
- Arena oval substituída por base modular retangular; coberturas de equipamento, relés, kits médicos e pad de extração agora têm leitura industrial.
- Menu e HUD passam a comunicar falha de contenção e extração.
- Versão Android atualizada para 0.12.0.

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
