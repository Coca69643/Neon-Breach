# Projeto Arena

MOBA 3D nativo para Android, com partidas 5v5 offline contra IA. Inclui três rotas, selva localizada, acampamentos neutros, torres, objetivos, progressão e seleção de heróis. Desenvolvido com Kotlin, Filament e C++20; orientação landscape, sem WebView e sem conexão de rede durante o jogo.

## Log de atualizações

- **1.7.0 (reconstrução do campo + hotfix de assets)** — Corrigido URI do buffer do modelo KayKit `fence_wood`; CI agora verifica os 12 modelos carregados e todos os seus recursos externos. Build de manutenção versionCode 171.
- **1.7.0 (reconstrução do campo)** — Campo aberto com bolsões de selva localizados; pontos ambientais CC0 posicionados por geração procedural offline; paleta própria da Lyra e equipamentos visuais por função nos minions; referências do GLB do mundo corrigidas e cobertas por teste estrutural; pacote Android alinhado à versão 1.7.0.
- **0.16.0 (base anterior)** — Personagens CC0, NPCs com três corpos, animações Idle/Walk/Run, terreno PBR, vegetação e iluminação ambiental.
- **0.15.12** — Corrigida a orientação dos três heróis e aplicadas paletas de materiais individuais.
- **0.15.11** — Novo ícone e identificador Android próprio, sem conflito de instalação com ORION-9.
- **0.15.10** — Fauna reposicionada perto das rotas; culling acompanha os animais em movimento.
- **0.15.9** — Lyra, Bastion e Kairo com modelos CC0 independentes.
- **0.15.8** — Seis animais, oito guardiões e vegetação agrupada.
- **0.15.6** — Recuperação de inicialização 3D e correções de rig.
- **0.15.5** — Primeiro modelo 3D autoral da Lyra.
- **0.15.4** — Ajustes de câmera, seleção de heróis e leitura do cenário.
- **0.15.0** — Reconstrução do mapa, relevo, funções dos personagens e HUB.
