# Project Arena 1.8.0 — District Control

## Mapa e navegação
- Campo lógico expandido para 224 × 188 unidades, com contorno orgânico e seis setores.
- Seis distritos: Distrito Cívico, Reserva Verde, Mercado Central, Pátio Industrial, Estação Intermodal e Orla do Canal.
- Três avenidas mantêm pressão de siege; ruas secundárias, vielas e cinco travessias conectam os setores.
- Seis interiores acessíveis com portas, mobiliário e colisões derivados do mesmo catálogo.
- Duas rampas conectam mezaninos; terreno, navegação e Rapier usam coordenadas lógicas comuns.

## Loop territorial
- Os seis distritos são objetivos neutros capturáveis.
- Presença aliada aumenta o controle; presença inimiga disputa ou reverte o progresso.
- Capturas concedem ouro e experiência e aumentam o dano da equipe por distrito controlado.
- Bots roamers procuram distritos neutros ou inimigos; o reator central permanece como objetivo adicional.
- Marcadores 3D indicam estado neutro, aliado, inimigo ou contestado; o HUD resume a posse territorial.

## Escala visual
- Herói: escala-base 1.0.
- Bots: 0.98.
- Minions: 0.94 (distância) e 1.02 (corpo a corpo).
- Armas: escalas reduzidas por rig para manter proporção com as mãos.
- Orientação dos rigs é corrigida para alinhar o eixo frontal do GLB ao vetor de deslocamento.

## Assets CC0
Assets são preparados offline e empacotados localmente; a partida não baixa modelos ou texturas.
Somente packs com licença CC0 explícita entram no bundle:
- Kenney City Kit Roads: https://kenney.nl/assets/city-kit-roads
- Kenney City Kit Commercial: https://kenney.nl/assets/city-kit-commercial
- Kenney City Kit Suburban: https://kenney.nl/assets/city-kit-suburban
- Kenney City Kit Industrial: https://kenney.nl/assets/city-kit-industrial
- Poly Haven: https://polyhaven.com/license
- ambientCG: https://ambientcg.com/

## Gate de validação
- `flutter analyze`
- `flutter test --reporter expanded`
- Build Android ARM64 e verificação de identidade/assinatura do APK.
- Validação visual e de desempenho prolongada no Realme C53 continua obrigatória antes da publicação.
