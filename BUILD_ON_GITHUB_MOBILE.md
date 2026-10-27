# NEON BREACH 0.7.1 — instalar e atualizar pelo Android

## Baixar
1. Abra [Actions](https://github.com/Coca69643/Neon-Breach/actions).
2. Abra a execução de build mais recente que esteja verde.
3. Em **Artifacts**, baixe `neon-breach-debug-apk`.
4. Extraia o ZIP e instale o APK.

## Ícone do aplicativo
A versão 0.7.1 declara explicitamente `android:icon` e `android:roundIcon` no manifesto e contém um vector drawable de launcher.

## Atualizações futuras
Android exige o mesmo `applicationId`, o mesmo certificado de assinatura e um `versionCode` igual ou superior para instalar por cima. NEON BREACH mantém o ID `com.duckdream.neonbreach` e aumenta o código de versão para 8. Os APKs debug antigos usavam chaves automáticas temporárias do runner do GitHub, portanto será necessária uma desinstalação única para migrar para uma chave persistente.

Para ativar builds atualizáveis, configure estes GitHub Actions secrets em Settings → Secrets and variables → Actions: `NEON_BREACH_KEYSTORE_BASE64`, `NEON_BREACH_KEYSTORE_PASSWORD`, `NEON_BREACH_KEY_ALIAS` e `NEON_BREACH_KEY_PASSWORD`. Guarde o keystore privado fora do repositório. O workflow emite um aviso quando usa a chave debug temporária.

Documentação: [como o Android trata atualizações](https://developer.android.com/google/play/app-updates) e [versionamento](https://developer.android.com/studio/publish/versioning).
