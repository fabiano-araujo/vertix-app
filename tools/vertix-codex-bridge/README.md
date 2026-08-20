# Ponte local Vertix/Codex

Registra o protocolo `vertixcodex://` no Windows e instala a skill `vertix-reference-images` no perfil local do Codex. O editor Vertix usa esse protocolo para iniciar `codex exec`, abrir a tarefa criada no app Codex e deixar a geracao continuar automaticamente.

Instalacao no perfil do usuario:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\vertix-codex-bridge\install.ps1
```

A ponte aceita apenas a API de producao `https://vertix-api.snapdark.com` e APIs locais em `127.0.0.1`/`localhost`. A credencial recebida e limitada a um unico job de imagens e nao e gravada no log.

A execucao usa o `codex.cmd` publico, nao o executavel interno protegido do
pacote da Microsoft Store. O progresso da abertura e enviado para a API e os
logs locais, sem credenciais, ficam em
`%LOCALAPPDATA%\Vertix\CodexBridge`. Se o editor nao receber confirmacao em 15
segundos, ele oferece o botao **Tentar abrir o Codex novamente**.
