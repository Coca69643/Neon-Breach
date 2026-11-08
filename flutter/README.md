# Projeto Arena — Flutter Scene Foundation 0.3

Migração do runtime 3D para Flutter Scene. Flutter/Dart controla a aplicação e a FSM; Flutter Scene fornece o scene graph e a renderização 3D. Não há runtime C++ ou OpenGL ES manual nesta arquitetura.

## Stack fixada

- Flutter 3.47 stable ou superior
- Dart 3.10 ou superior
- flutter_scene: 0.24.3
- Android landscape, offline-first
- applicationId: com.duckdream.projectarena
- Nome instalado: Projeto Arena
- minSdk: 24 (Android 7.0 ou superior)
- versionName/versionCode: 1.8.1 / 74
- APK de CI: ARM64 para aparelhos Android atuais, incluindo o Realme C53

## Política visual e desempenho

- Sem sombras dinâmicas.
- PBR com iluminação de ambiente controlada e materiais bem trabalhados.
- Assets orgânicos com rigs e animações; geometria primitiva só em testes técnicos.
- Meta inicial: 30 FPS sustentados no Realme C53.
- Arena urbana 224 × 188, com seis distritos, três avenidas de siege, seis edifícios acessíveis, ruas secundárias e cinco travessias do canal.
- Distritos com silhuetas comerciais distintas, sinalização/iluminação de rua, praças laterais, árvores grandes e mobiliário urbano CC0.
- Navegação com colisão de paredes/mobiliário, portas, cinco travessias do canal e duas escadas que conectam mezaninos com elevação real.
- Câmera de ação aproximada com arrasto independente por pointer tracking na zona central/direita; joystick esquerdo reservado exclusivamente ao movimento.
- Implementado nesta revisão: seleção touch de alvo, HUD contextual, confirmação de acerto, locomoção walk/run vinculada à velocidade Rapier e rotação do herói para o alvo durante ataques. Próximas prioridades: loja/itens MOBA, efeitos de impacto por classe de ataque e validação física no aparelho.
- Escalas de leitura: herói 1.0, bots 0.98, minions 0.94–1.02.
- LOD, instancing, culling e limites de partículas/transparências fazem parte do orçamento mobile.

## Identidade e assinatura Android

O host Android gerado reutiliza o ícone vetorial e a identidade "Projeto Arena" já existentes no repositório. O applicationId permanece idêntico ao APK 0.16.0, e o versionCode é maior que 59.

A chave persistente de atualização (variáveis NEON_BREACH_KEYSTORE_*) só é carregada em execuções confiáveis da branch `main`. Builds de branches de desenvolvimento executam análise, testes, build ARM64 e verificação da assinatura, mas não recebem essa chave e não publicam APK de atualização. Builds locais sem essas variáveis usam a assinatura de debug do Flutter e não devem ser instalados como substituição de uma versão assinada.

O minSdk é 24 porque as versões atuais do Flutter elevaram o mínimo Android suportado para API 24.

## Status técnico

- Máquina de estados de aplicação em Dart: implementada.
- Validação do manifesto offline: implementada.
- Dependência Flutter Scene: fixada em 0.24.3.
- Build hook e pré-processamento de modelos/materiais: implementados.
- Menu principal com fundo ilustrado 2D em `CustomPainter`; leve, estático e sem instanciar a cena 3D de gameplay.
- O perfil do jogador abre uma sub-tela própria para nome, foto, estatísticas e moldura equipada.
- `HERÓIS` abre a seleção em tela cheia; `ASCENDER` mantém a entrada da partida.
- Baús, Desafios e Mercador são sub-telas funcionais, com recompensas locais persistentes e cosméticos sem atributos competitivos.
- A ilustração de combate é referência para uma futura tela de carregamento, não para o menu.
- Partida 3D com câmera de ação baixa, traseira e suavizada; personagem em primeiro plano; aguarda validação visual no aparelho.
- Preview 3D dos três heróis CC0 com clips Idle via SceneModel: integrado; renderização ainda não validada em aparelho.
- A ilustração 2D do menu mantém a identidade da torre; modelos 3D urbanos são carregados exclusivamente na gameplay.
- Mapa District Control: 224 × 188, seis distritos capturáveis, cinco pontes, ruas secundárias pavimentadas e seis interiores ampliados.
- Pipeline offline do terreno GLB com concreto/asfalto, assets urbanos CC0 e bolsões de parque.
- Colisões de paredes, móveis, obstáculos, torres e limites do mapa; unidades de rota podem atravessar a pegada das torres sem ocupar o centro de uma estrutura inimiga.
- MATCH_LOADING cria uma partida MOBA com herói, bots, minions, torres, HUD touch e minimapa.
- Duas rotas de mezanino com subida gradual, colisão por altura e bloqueio de ataques entre pisos.
- Coberturas CC0 nas entradas recebem dano; destruí-las remove a colisão e abre a passagem.
- Reator central capturável/contestável; equipe controladora recebe +12% de dano e recompensa inicial.
- Armas CC0 distintas de Lyra, Bastion e Kairo anexadas ao rig; bots, tropas e NPCs usam seis aparências CC0 independentes dos heróis selecionáveis.
- Joystick relativo à câmera; perspectiva baixa traseira com follow suavizado e balanço sutil proporcional à velocidade física.
- Locomoção com aceleração, frenagem, tração por superfície, colisão de cápsula e passo fixo Rapier a 60 Hz. Bastion usa golpe pesado próprio; Lyra e Kairo mantêm cortes de espada distintos.
- Rigs humanoides usam eixo frontal local +Z; caminhada/corrida muda pela velocidade real, e ataques orientam o herói para o alvo.
- Verificador de release: checa package id, versionamento, orientação, Flutter GPU, minSdk, ABI e assets pré-processados.
- CI: análise estática, testes, geração e verificação dos assets offline, build ARM64 e verificação de assinatura. A chave persistente só é carregada em builds confiáveis da branch principal.
- Build candidato 1.8.1+74: hub 2D ampliado, perfil local do jogador, seleção de heróis reorganizada e sub-telas de Baús, Desafios e Mercador. Mapa District Control com seis setores, captura territorial, recompensas e bots roamers. Teste visual e desempenho sustentado no Realme C53 continuam pendentes.

## Comandos

~~~bash
cd flutter
python3 -m pip install -r tool/requirements-world.txt
python3 tool/prepare_world_assets.py
python3 tool/prepare_hero_assets.py
python3 tool/prepare_city_assets.py
python3 tool/prepare_npc_assets.py
python3 tool/prepare_match_assets.py
python3 tool/prepare_weapon_assets.py
python3 tool/prepare_android.py
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
python3 tool/verify_release_apk.py build/app/outputs/flutter-apk/app-release.apk
~~~

Para assinar uma atualização compatível com instalações existentes, configure as quatro variáveis NEON_BREACH_KEYSTORE_* antes de executar prepare_android.py e o build. Consulte https://fscene.dev/getting-started/installation/.


## Fundação de salas Online e Rede Local — em validação

- Tela própria de salas acessível pelo atalho REDE no menu.
- Online: Supabase Realtime em canal privado arena:lobby:<código>, com autenticação de convidado e presença.
- Rede local: host TCP no aparelho, conexão manual por IP/porta e código de convite de 128 bits.
- Lista de presença, criação/entrada/saída e encerramento de sessão.
- supabase_flutter fixado na linha estável 2.18.x; não usar pré-release 3.x nesta entrega.
- O manifesto gerado inclui INTERNET; targetSdk está fixado em 36. Se futuramente subir para 37, implementar ACCESS_LOCAL_NETWORK runtime antes de habilitar sockets LAN no Android 17.
- O Supabase precisa ter Anonymous Sign-Ins habilitado. A chave incluída no app é apenas publishable; nunca incluir service_role.
- Limite desta fatia: o transporte sincroniza somente presença no lobby. A partida 3D e a simulação seguem offline; não existe ainda sincronização de movimento, objetivos ou eventos da partida.
- LAN usa TCP local e código temporário. Não enviar dados privados por esse canal.

Critérios pendentes: testar duas instalações em Wi-Fi real, alternância de rede, reconexão, encerramento inesperado do host e autorização dos canais privados. A fundação não deve bloquear o boot nem o modo offline.
