# Changelog — Projeto Arena

## [0.3.0] — 2026-11-01

### Reconstrução visual
- Corrigida a ordem dos índices das esferas; a malha anterior estava com winding invertido, fazendo o backface culling descartar a face externa de copas, rochas e props arredondados.
- Adicionada iluminação indireta por harmônicos esféricos e ajustada a luz solar do Filament para uma direção oblíqua, com exposição de câmera explícita.
- Paleta do céu e do cenário ajustada para leitura diurna; vegetação e superfícies arredondadas deixam de depender de faces internas.
- Terreno recortado para perímetro orgânico arredondado, removendo a borda quadrada do mapa.
- Três rotas ganharam ombros escuros e faixas centrais de pedra, com folga de vegetação para manter corredores legíveis.
- Bots deixaram de ser montagens de cilindros/esferas: agora são instâncias do humanoide Quaternius CC0 que já acompanha o APK, com matiz por equipe e animação procedural de locomoção no rig.
- Câmera de overview enquadra o mapa no menu, pausa e resultado; câmera de partida acompanha o jogador.
- Painel de pausa centralizado com largura controlada para evitar o título colado à borda.

### Mantido
- Partida local 5v5: jogador + quatro bots aliados contra cinco bots adversários.
- Três rotas com pressão independente, ondas simplificadas de tropas, três heróis e habilidades fictícias sem armas.
- Android nativo landscape, Filament 1.77.3, Kotlin e C++20.
- Vulkan preferencial e fallback OpenGL ES.

### Limitações conhecidas
- A IA, a economia das tropas e a pressão de rotas continuam simplificadas.
- Os bots compartilham o mesmo modelo humanoide base e diferem por cor/equipe; ainda não há elenco de silhuetas exclusivas.
- Build e renderização ainda precisam ser verificados. Mesmo com CI aprovado, enquadramento, qualidade visual, Vulkan/GLES, FPS sustentado e temperatura exigem teste físico no Realme C53.

### Verificação da entrega
- GitHub Actions run #132 (41271623682): concluído com sucesso em 2026-11-01.
- Passaram: verificação estrutural, compilação Android/Kotlin/C++20, verificação de app-debug.apk e upload do artefato.
- Artefato: `project-arena-0.3.0-debug`, baixado e extraído.
- APK: 16.602.232 bytes; integridade ZIP e presença de DEX, bibliotecas nativas arm64-v8a/armeabi-v7a e asset humanoide CC0 verificadas.
- SHA-256 do APK: `ec8cbc771af40905cbe63ca84a8f6c75cff3b2ad307c90c18e9a208c5eb37326`.
- Run: https://github.com/Coca69643/Neon-Breach/actions/runs/41271623682
- Teste físico no Realme C53, renderização visual em Vulkan/GLES, FPS sustentado e temperatura: ainda pendentes.

## [0.2.0] — 2026-11-01
- Primeira fatia de MOBA offline 5v5, com três rotas, bots, três arquétipos de herói, habilidades de ressonância/defesa e minimapa.
- Base Android nativa em landscape com Filament 1.77.3, Kotlin e simulação C++20.
- Build de CI #120 gerou o primeiro APK 0.2.0. A inspeção visual posterior reprovou a apresentação e motivou a reconstrução da versão 0.3.0.
