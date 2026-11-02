# Projeto Arena — reconstrução aprovada

Data do plano: 2 de novembro de 2026.

## Diagnóstico confirmado na branch de recuperação

1. A identidade Android vinha de `strings.xml` e ainda dizia ORION-9; o rótulo no instalador do aparelho estava desatualizado (o screenshot enviado mostra “Projeto Arena 0.7”).
2. A interface Android adicionava textos explicativos redundantes, botões preenchidos, conteúdo centrado e cartões no seletor de personagens.
3. Os personagens de runtime eram compostos por primitivas nativas. A animação de membros usava uma fase senoidal global, mesmo quando a entidade estava essencialmente parada.
4. O importador cgltf só copiava posição, normal, UV e índices, assando a transformação de nó na malha. Não havia importação de `JOINTS_0`, `WEIGHTS_0`, skins, inverse-bind matrices ou canais de animação. Portanto, GLBs animados não poderiam funcionar como personagens animados com o importador atual.

## Escopo da primeira fatia entregue nesta branch

- Rótulo Android alterado para **Projeto Arena**, sem versão visível.
- `applicationId` mantido para preservar a identidade de instalação e permitir atualização sobre o app existente.
- Menu principal e sub-telas simplificados; cartões e fundos retangulares dos botões removidos.
- Nomes e textos residuais da identidade ORION-9 removidos da interface tocada por esta alteração.
- Identificadores de log de inicialização padronizados como `ArenaStartup`.
- CI renomeada e preparada para validar pull requests cujo destino seja `recovery/mobile-stability`.
- Pesquisa CC0 atualizada com distinção entre personagens humanoides rigados e pacotes que realmente anunciam animações próprias.

## Critérios de aceitação

### Identidade e interface
- [x] Rótulo do instalador/launcher é exatamente “Projeto Arena”.
- [x] Nenhum número de versão é mostrado ao lado do nome do app ou no menu principal.
- [x] `applicationId` permanece inalterado.
- [x] Botões do menu e ações não usam fundos retangulares/cartões opacos.
- [x] Navegação entre menu, seleção, ajustes, pausa e resultado mantém os mesmos pontos de entrada.
- [ ] Confirmar a apresentação em execução num APK instalado e no Realme C53.

### Personagens e pipeline de animação
- [x] Causa do movimento artificial documentada a partir do código atual.
- [x] Limitações do importador cgltf documentadas a partir da implementação atual.
- [ ] Selecionar arquivos CC0 exatos após inspecionar os downloads e seus arquivos de licença.
- [ ] Implementar importação de rigs, pesos, inverse-bind matrices e canais glTF de animação.
- [ ] Implementar avaliação de pose e skinning GPU compatível com OpenGL ES 3.0.
- [ ] Estados de locomoção com blend/transições: idle, caminhar, correr, virar, parar e interagir.
- [ ] Testar em build com assets reais; rejeitar animação contínua quando a entidade está parada.

### Ambiente e performance
- [ ] Protótipo de uma sala, duas passagens e uma transição de altura com três silhuetas arquitetônicas.
- [ ] Validar colisão e dimensões junto da geometria visual.
- [ ] Medir triângulos, draw calls, tamanho dos GLBs e memória de textura.
- [ ] Validar quadro sustentado, aquecimento e retomada no Realme C53.

## Limites desta entrega

Os assets listados em `ASSET_PIPELINE_CC0.md` são fontes candidatas pesquisadas, não arquivos integrados. O pipeline de rigging/skinning ainda não foi implementado. A interface foi alterada no código, mas ainda depende de CI e teste visual no aparelho. Nenhuma aprovação de build equivale a prova de desempenho ou qualidade visual no telefone.

## Próximas etapas

1. Validar este patch de identidade/UI em CI e no aparelho.
2. Baixar e inspecionar os pacotes CC0 exatos; arquivar licença, origem, data e SHA-256.
3. Implementar o runtime de animação glTF em módulo isolado com testes determinísticos antes de conectá-lo ao renderer.
4. Substituir gradualmente os personagens temporários somente depois que os modelos e clips reais passarem em validação.
5. Construir uma fatia ambiental pequena no estilo de ruínas naturais; não migrar o mapa inteiro até a fatia passar na revisão visual e de performance.
