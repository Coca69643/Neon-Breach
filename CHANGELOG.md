# Changelog — Projeto Arena

## [1.7.5] — 2026-11-05

### Reconstrução urbana
- Campo de batalha alinhado ao terreno gerado: 180 × 140 unidades, com três avenidas nas coordenadas -36 / 0 / +36.
- Bases reposicionadas para z = -66 / +66; torres alinhadas às três rotas.
- Removido o rodapé de penhasco que fazia o mapa parecer uma ilha flutuante.
- Superfícies do terreno alteradas para concreto urbano, asfalto escuro e bolsões de parque.
- Adicionados modelos CC0 de ruas, cruzamentos e edifícios comerciais.
- Quatro interiores de piso térreo montados com paredes, vãos de entrada, balcões, mesas, cadeiras e terminais.
- Colisão das paredes e móveis alinhada às entradas; a porta sul permanece transitável.
- Estruturas de rota e bases deixam de usar os modelos medievais antigos.

### Câmera e controles
- Arrasto de câmera isolado por pointer tracking na zona central/direita; joystick esquerdo permanece exclusivo para movimento.
- Câmera aproximada do herói: follow distance 9.4, look-ahead 3.0 e pitch inicial 0.34 rad.
- FOV vertical ajustado para 49°; herói 1.0, bots 0.86 e minions 0.54–0.58.

### Combate e personagens
- Ataque básico agora solicita os clipes SwordSlash dos rigs, em vez de exibir apenas o pulso visual.
- Alcance e intervalo de ataque passam a variar por herói.
- Pipeline de Kairo exige rig masculino e clipes Man_Idle, Man_Walk e Man_SwordSlash.
- Verificador do APK inspeciona o GLB de Kairo dentro do pacote e rejeita clipes femininos.

### Validação
- Testes de navegação atualizados para o mapa 180 × 140, portas, paredes, rotas e travessias.
- APK 1.7.5+67 ainda depende da execução completa do CI e de validação física no Realme C53.
- Nenhum FPS, temperatura ou qualidade visual é declarado aprovado antes do teste no aparelho.

## [1.7.4] — 2026-11-05

- Vale das Coroas expandido para 120 × 84 unidades, com três rotas, rio, pontes e acessos laterais.
- Câmera de ação traseira e escala ampliada dos heróis.
- Build ARM64 submetido ao CI; captura visual e desempenho ainda dependem de teste físico.

## [1.7.3] — 2026-11-05

- Câmera de combate reposicionada e escala de heróis, bots e minions ampliada.
- Validação física ainda pendente.

## [1.7.2] — 2026-11-05

- Migração para Flutter 3.47 / Dart 3.10 e Flutter Scene 0.24.3.
- Máquina de estados Dart, aplicativo offline e landscape.
- Hub 3D e seletor independente de Lyra, Bastion e Kairo.
- Primeira partida MOBA com rotas, bots, minions, torres, economia e HUD.

## Histórico legado

## [0.16.0 — build de teste]

- Runtime Android anterior e pipeline nativo.
- Personagens e NPCs com modelos CC0, animações e materiais próprios.
- Terreno PBR, vegetação e iluminação ambiental.

## [0.15.12]
- Corrigida a orientação dos três heróis e aplicadas paletas individuais.

## [0.15.11]
- Novo ícone e identificador Android próprio.

## [0.15.10]
- Fauna reposicionada e culling de animais em movimento.

## [0.15.9]
- Lyra, Bastion e Kairo com modelos CC0 independentes.

## [0.15.8]
- Fauna, guardiões e vegetação agrupada.

## [0.15.6]
- Recuperação de inicialização 3D e correções de rig.

## [0.15.5]
- Primeiro modelo 3D da Lyra.

## [0.15.4]
- Ajustes de câmera, seleção de heróis e leitura do cenário.

## [0.15.0]
- Reconstrução inicial do mapa, funções de personagens e hub.
