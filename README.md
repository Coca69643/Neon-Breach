# Projeto Arena

**Duck Dream Studios · Android nativo · 3D · paisagem**

Projeto Arena está em reconstrução visual e funcional. A prioridade desta linha é abandonar a identidade sci-fi genérica, substituir personagens procedurais por modelos CC0 com rigs/animações reais e remover a apresentação baseada em cartões e blocos opacos.

## Identidade e interface

- Nome do aplicativo: **Projeto Arena**.
- O nome exibido no Android e dentro do jogo não contém número de versão.
- A interface usa composição em tela cheia; menus e seletores não colocam cartões opacos atrás dos textos.
- A orientação de execução permanece em paisagem.

## Arquitetura mantida

- Kotlin: ciclo de vida Android, telas e entrada por toque.
- C++17: simulação nativa e integração com a física.
- OpenGL ES 3.0: renderização no Android.
- cgltf: leitura de arquivos glTF/GLB.
- stb_image: carregamento de imagens.
- Jolt Physics: colisões e movimento físico.

O `applicationId` atual é preservado para permitir atualização sobre a instalação existente. `versionCode` e `versionName` continuam existindo apenas como metadados internos do Android; não são exibidos como parte do nome do app.

## Reconstrução de personagens e animação

O renderer atual ainda contém personagens construídos com primitivas e animação senoidal. A primeira fatia do runtime `CharacterAnimation` agora decodifica hierarquia de nós, skins, inverse-bind matrices, `JOINTS_0`/`WEIGHTS_0` e canais glTF de translação, rotação e escala. O avaliador suporta STEP, LINEAR com slerp e CUBICSPLINE, além de gerar a paleta CPU de juntas.

O módulo já está compilado no alvo nativo, mas ainda não está conectado a `drawImportedModel()` nem ao shader de skinning. Portanto, os modelos atuais ainda não mudaram em runtime. O próximo passo é integrar atributos de juntas e paleta no renderer, validar um arquivo CC0 real e só então remover os personagens procedurais. A seleção final será limitada a conteúdo CC0 com licença preservada no repositório.

## Política de assets CC0

Fontes oficiais auditadas para a próxima etapa:

- [Quaternius — Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html): modelos humanoides rigados, topologia preparada para animação e licença CC0.
- [Quaternius — Cute Animated Monsters](https://quaternius.com/packs/cutemonsters): criaturas texturizadas e animadas, licença CC0.
- [Kenney — Mini Characters](https://kenney.nl/assets/mini-characters): conjunto de personagens 3D com animação, licença CC0.
- [Kenney — Modular Dungeon Kit](https://kenney.nl/assets/modular-dungeon-kit): módulos ambientais 3D, licença CC0.
- [Poly Haven](https://polyhaven.com/): modelos, materiais PBR e HDRIs sob CC0.

**Regra de integração:** cada asset importado deve manter o arquivo de licença e a referência da fonte; a CI não deve aceitar conteúdo sem origem/licença documentada. Um asset listado aqui é uma fonte aprovada para avaliação, não uma declaração de que já foi integrado ao APK.

## Validação

A compilação automatizada confirma apenas a integridade do build. A validação final de fluidez, temperatura, controles e retomada após interrupção ainda exige teste físico no aparelho de referência.
