# Changelog — Projeto Arena

## [1.8.3] — candidata consolidada

### Recuperação de gameplay e estabilidade
- Correções de movimento, colisões e alinhamento de footprints de edifícios, interiores, portas e mobiliário.
- Loja de campo e Quartermaster com compra por proximidade, custos em ouro e upgrades de partida.
- Ajustes de orientação e escala visual de NPCs, bots e minions; melhorias de navegação e rotas.

### Salas Online e Rede Local
- Lobby Online com Supabase Realtime em canal privado e presença de convidados.
- Salas LAN por TCP local, convite temporário, código/IP/porta e roster.
- O transporte atual sincroniza somente a presença no lobby; partida, movimento e objetivos continuam locais/offline.
- Anonymous Sign-Ins precisa ser habilitado no projeto Supabase antes dos testes online com convidados.

### Identidade visual do launcher
- Ícone do Projeto Arena redesenhado como emblema robótico sci-fi em teal/ciano e âmbar, sem texto, com recurso WebP otimizado e cópia validada pelo gerador Android.

### Herói metamórfico — Linn (integração inicial)
- Linn adicionado ao elenco jogável e à seleção por espécie, com apresentação robótica humanoide.
- Ultimate Protocolo Feral: forma quadrúpede temporária por 8 s, transição de 0,55 s, cooldown de 22 s e bônus de movimento de 18%.
- Forma robótica utiliza emissor integrado ao antebraço; forma Feral tem alcance, dano e cadência de ataque próprios.
- As duas formas usam geometria procedural offline e recursos 3D cacheados. Rig/arte final e teste visual/performance no Realme C53 continuam pendentes; não é ainda um clip glTF de morph targets.

### Inicialização e identidade
- Splash Duck Dream Studios com logo transparente e transição curta.
- Inicialização em etapas, validação do manifesto, recuperação e fallback offline.
- Hub 2D mobile, perfil local com nome/foto/estatísticas/molduras e seleção de heróis reorganizada.
- Baú diário de créditos, desafios de marcos e mercador de molduras cosméticas.

### Novo mapa — Porto de Vésper
- Costa irregular remodelada e canal de navegação ampliado.
- Quatro praças de cais pavimentadas e 23 volumes comerciais/industriais com footprints medidos.
- Seis distritos, três rotas principais, cinco pontes, seis interiores e acessos elevados preservados.
- Identidade do mapa na prévia e na HUD; terreno e navegação usam a mesma escala lógica.

### Identidade Android
- versionName: 1.8.3.
- versionCode: 74 (o release anterior publicado é 1.8.0+73).
- applicationId preservado: `com.duckdream.projectarena`.

### Validação e limites conhecidos
- CI anterior do candidato passou em análise, 132 testes e preparação dos assets. A integração de Linn precisa de uma nova execução CI e de inspeção física no Realme C53.
- Builds QA Profile anteriores usam identidade isolada `com.duckdream.projectarena.qa`; não substituem a instalação de produção.
- Release assinado, comparação do certificado de produção e validação visual/performance no Realme C53 continuam pendentes.
- A camada Online exige habilitar Anonymous Sign-Ins; o modo offline não depende dela.

## [1.7.10] — 2026-11-05

### Direção visual e ambiente
- Quatro fachadas comerciais com silhuetas diferentes, em vez de repetir o mesmo modelo.
- Ruas recebem iluminação, semáforos, placas, faixas de pedestres, marquises e pontos de praça.
- Novas árvores grandes e floreiras reforçam a separação entre avenida, canal e áreas verdes.
- Operações, oficina, informação do parque e convivência têm interiores com arranjos próprios.
- O reator central comunica posse e disputa diretamente na geometria do cenário.

### Vida e sistemas táticos
- NPCs de serviço patrulham rotas curtas, pausam e respondem quando abordados.
- Um toque no minimapa ordena o aliado de flanco mais próximo a investigar um ponto acessível.
- Comandos táticos rejeitam água, paredes, torres, mezaninos e posições fora do mapa.
- A ordem expira automaticamente; combate contra heróis mantém prioridade.

### Correções de simulação e navegação
- Ondas de tropas removem unidades derrotadas antes de verificar o limite de entidades.
- Movimento do jogador e dash do Kairo validam o percurso em subpassos para impedir atravessar paredes.
- Bots e tropas usam pontos de aproximação para atacar torres e núcleos.
- Tropas convergem ao núcleo após abrir uma rota, em vez de permanecerem presas ao alinhamento lateral.
- Bots e tropas expõem estados de ataque para reproduzir animações correspondentes.
- Torres destruídas deixam de aparecer na cena e no minimapa.
- Corrigida a orientação dos rigs no movimento e o alinhamento das rotas no minimapa.

### Integridade de build
- CI executa análise estática, testes, geração de assets, build ARM64, inspeção do pacote e verificação de assinatura.
- A chave persistente de assinatura só é carregada em builds confiáveis da branch principal.
- Publicação isolada após o build verificado; tags e assets existentes não são sobrescritos.
- O verificador exige todos os novos GLBs e cenas compiladas.

### Validação
- CI de validação da branch: análise, testes, build ARM64, inspeção de assets e verificação de assinatura passaram.
- O upload do APK de atualização e a publicação foram pulados por política: a branch é de desenvolvimento, não a `main`.
- Teste visual/funcional e medição prolongada de FPS, temperatura e memória no Realme C53 ainda precisam de validação física.
- Savegame após encerramento forçado do processo ainda não está implementado; pausa/retomada preserva estado apenas enquanto o processo permanece ativo.

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
