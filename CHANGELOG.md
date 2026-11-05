# Changelog — Projeto Arena

## [1.7.8] — 2026-11-05

### Correções
- Confirmar a escolha do herói retorna ao hub; ASCENDER inicia a partida.
- Corrigida a orientação frontal dos heróis no seletor e durante a movimentação.
- Reduzida a escala das armas equipadas.
- Corrigida a composição do HUD de interação com NPCs.
- Identificação de equipe por cores nos heróis controlados pela IA e nas tropas.
- Minions agora mantêm formação distribuída em quatro posições por rota.
- Quatro pontos internos com NPCs receberam marcadores no minimapa.

### Ainda em auditoria
- Diversidade visual de bots e minions, navegação tática e exploração de interiores continuam pendentes de validação visual e funcional.

## [1.7.7] — 2026-11-05

### Combate e leitura de alvo
- Adicionado botão touch dedicado para alternar entre heróis e tropas inimigas dentro do raio de seleção.
- HUD contextual exibe o alvo travado, tipo de unidade e barra de vida; desaparece quando não há alvo válido.
- Ataque básico mantém a confirmação imediata de animação, mas o marcador de impacto só aparece quando dano real é aplicado.
- Feedback de acerto separado de swing vazio, cobrindo heróis, minions, coberturas, torres e núcleo.
- Testes cobrem seleção de alvo, confirmação de dano e ataque sem contato.

### Validação
- Análise, testes, build ARM64, inspeção de assets e assinatura exigem aprovação do CI 1.7.7.
- Teste físico no Realme C53 continua necessário para validar posição dos controles, legibilidade e desempenho.

## [1.7.6] — 2026-11-05

### Rotas verticais e posicionamento
- Duas rotas de mezanino opostas com escada, deck e guarda-corpos CC0.
- Navegação por elevação incremental; sem teleporte entre pisos.
- Ataques e aquisição de alvos respeitam a diferença de altura.
- Acesso por escada e limite de plataforma cobertos por testes automatizados.

### Coberturas destrutíveis
- Barricada e grade de construção CC0 nas entradas dos edifícios.
- Coberturas têm 180 HP, bloqueiam o corredor e recebem dano de ataques básicos.
- A destruição remove a colisão e libera a passagem; recompensa de 28 G.
- Mobiliário interno reposicionado para não bloquear o eixo de entrada.

### Objetivo central
- Reator central com barra de captura e estado neutro/contestado.
- Heróis, bots e minions contribuem com presença ponderada.
- Disputa simultânea congela a captura; o controle persiste até retomada inimiga.
- Controle concede +12% de dano à equipe; a posse persiste enquanto o adversário drena o medidor, sendo perdida apenas quando ele retorna a zero. A primeira captura rende 150 G / 90 XP.

### Equipamento dos heróis
- Lyra, Bastion e Kairo recebem espadas CC0 distintas.
- GLBs presos ao osso `Palm.R`; bots recebem clones dos templates para compartilhar recursos.
- Pipeline verifica os hashes dos modelos e exige o socket `Palm.R` nos três rigs.

### Validação
- Análise, testes, build ARM64, pacote de assets e assinatura precisam passar no CI da 1.7.6.
- Câmera, alinhamento das armas, resposta visual dos impactos, FPS, temperatura e memória ainda exigem teste no Realme C53.
- Não declarar a partida completa: loja, itens MOBA e efeitos de impacto continuam pendentes.

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
- Kairo recebe um GLB masculino distinto (Quaternius Man-fjHyMd5Wxw, CC0), com paleta própria; o pipeline exige Man_Idle, Man_Walk e Man_SwordSlash.
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
