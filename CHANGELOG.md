# Changelog — Projeto Arena

## [0.6.0] — 2026-11-01

### Câmera e escala
- Substituída a câmera ortográfica elevada por câmera perspectiva de ação, próxima ao personagem e seguindo sua orientação.
- Aumentada a escala visual do herói e dos bots no enquadramento.
- Menu agora enquadra o herói no cenário, em vez de exibir a arena inteira sem protagonista.

### Campo e IA local
- Campo retangular contínuo; removido o recorte circular que produzia uma borda serrilhada de ilha.
- Relevo do terreno ampliado e paleta do chão menos saturada.
- Limites do jogador alinhados ao retângulo do mapa; removida a antiga colisão radial.
- Aceleração do joystick ajustada para resposta mais imediata, mantendo desaceleração progressiva.
- Árvores e copas reduzidas para evitar volumes esféricos gigantes dominando a leitura.
- Bots avançam para zonas centrais fixas e permanecem disputando a captura.
- Slots laterais por rota e por equipe evitam sobreposição entre unidades no objetivo.
- A pontuação considera presença na zona real de captura, não apenas passagem ampla pelo meio da rota.
- Ritmo de captura ajustado para partidas locais mais curtas.
- Escudo agora aumenta a contribuição do jogador na captura enquanto ativo.
- Pulso mantém interrupção temporária de bots próximos; impulso serve para reposicionamento.

### Interface
- Menu reduzido a personagem em destaque, marca curta e toque para jogar.
- Removidos versão antiga hardcoded, tagline, regras, notas de tecnologia e botões de seleção no menu.
- HUD reduzido para cronômetro, progresso, minimapa, joystick, pausa e três habilidades.

### Instalação e assinatura
- applicationId preservado: com.duckdream.neonbreach.
- versionCode 36 / versionName 0.6.0.
- Restaurada assinatura persistente com os quatro secrets NEON_BREACH_* do repositório.
- Workflow de PR continua compilando para validação, mas não publica APK instalável; apenas workflow_dispatch usa a chave persistente e publica o APK de atualização.
- O Android exige applicationId igual, certificado de assinatura compatível e versionCode não inferior para instalar por cima. Como as versões anteriores de PR usaram chaves temporárias do runner, pode ser necessária uma única desinstalação antes de adotar a primeira build assinada de forma persistente. Depois disso, a mesma chave será reutilizada em futuras atualizações.

### Validação pendente
- A compilação CI não confirma qualidade visual nem jogabilidade em aparelho real.
- Câmera, movimento, ocupação dos objetivos, bots visíveis, FPS e temperatura ainda precisam de teste no Realme C53.
- Esta revisão é um MOBA-lite offline de captura e controle de zonas; ainda não tem a complexidade de um MOBA comercial completo.
