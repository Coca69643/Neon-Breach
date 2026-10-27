# NEON BREACH 0.7.1 — Android nativo

Projeto mobile-first de Duck Dream Studios: Kotlin para interface e entrada; C++17/NDK e OpenGL ES 3.0 para a simulação 3D.

## Novidades 0.7.1

- Ícone de launcher definido explicitamente no manifesto e incluído como vector drawable.
- Configuração de compilação para reutilizar uma chave de assinatura persistente quando os quatro GitHub Actions secrets de assinatura estiverem configurados.
- Mantém a missão Protocolo de Ruptura, menu, HUD, pausa, configurações e tela de resultado da 0.7.0.

## Atualização por cima de uma versão instalada

O Android aceita uma atualização quando o `applicationId` é o mesmo, o certificado de assinatura é o mesmo e o `versionCode` é igual ou maior. O `applicationId` continua `com.duckdream.neonbreach`; o `versionCode` desta versão é 8.

**Importante:** os APKs anteriores foram gerados em runners temporários usando a chave debug automática. Ela não é persistente entre execuções, portanto não é possível garantir uma atualização por cima desses APKs. Para os builds futuros poderem atualizar a instalação sem desinstalar, configure uma única chave privada persistente nos GitHub Actions secrets antes de distribuir a versão de migração. A migração da instalação v0.7.0 atual exigirá desinstalar essa versão uma vez, pois a assinatura antiga não pode ser recuperada do APK.

### Secrets necessários no repositório

Em **Settings → Secrets and variables → Actions**, crie:

- `NEON_BREACH_KEYSTORE_BASE64`: conteúdo Base64 de um keystore privado JKS.
- `NEON_BREACH_KEYSTORE_PASSWORD`: senha do keystore.
- `NEON_BREACH_KEY_ALIAS`: alias da chave.
- `NEON_BREACH_KEY_PASSWORD`: senha da chave.

Não coloque o keystore nem as senhas em arquivos versionados ou no código público. Depois de configurar os secrets, execute novamente o workflow. O log avisará quando o APK usar a assinatura persistente; sem os secrets, o build continuará como debug temporário e não será adequado para atualizações sobre builds de outras execuções.

## Baixar o APK

1. Abra [GitHub Actions](https://github.com/Coca69643/Neon-Breach/actions).
2. Abra o build mais recente com conclusão verde.
3. Em **Artifacts**, baixe `neon-breach-debug-apk`.
4. Extraia o ZIP e instale o APK.

## Limitações

Build verde confirma compilação e empacotamento, não substitui teste físico. A 0.7.1 ainda é um protótipo 3D nativo; é necessário testar menu, HUD, controles, relés, combate, extração e estabilidade no Realme C53.
