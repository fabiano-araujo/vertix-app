# Vertix

Responda em português.

## Versões (o que roda = o que o guia descreve)

Não inventar versão. O número no guia é o da fonte abaixo. Se o arquivo mudar, atualizar este guia no mesmo commit.

### App Flutter (o que `flutter run` / Android usa)

| Campo | Valor |
| --- | --- |
| Repositório | `https://github.com/fabiano-araujo/vertix-app.git` |
| Versão | `pubspec.yaml` → `1.0.0+1` |
| versionName | `1.0.0` |
| versionCode | `1` |
| SDK Dart | `^3.9.2` |
| applicationId | `com.example.vertix` |
| API que o app chama | `https://vertix-api.snapdark.com` (`lib/core/constants/api_constants.dart`) |

Esta é a versão que está no aparelho/emulador quando o app sobe. Pedido `deploy` **não** publica Flutter, web nem Play Store.

Quando o pedido for commitar/enviar o app: incluir **todo** o código-fonte que está rodando (`lib/`, `android/`, `pubspec.yaml`, testes, tools de bridge). Não omitir arquivo da working tree “porque não era do chat”.

### API Node (o que o host deve receber)

| Campo | Valor |
| --- | --- |
| Repositório | `https://github.com/fabiano-araujo/vertix-server.git` |
| Código local | pasta `server/` (git próprio; `git pull` no host **não** puxa o `vertix-app`) |
| Versão em `server/package.json` | `1.0.0` |
| Node no host | `20.19.5` (`package.json` pede `>=22` → `YARN_IGNORE_ENGINES=1`) |
| Host | `root@46.202.89.177` |
| Pasta remota | `/var/vertix` |
| Porta | `3005` |
| Processo PM2 | `vertix` |
| Chave SSH | `C:\Users\Fabiano\Documents\server_oracle\private.ppk` |

O host só recebe o que foi para `origin/main` **deste** remoto. A versão publicada tem de ser a pasta `server/` inteira que está na máquina, não um subconjunto.

## Deploy

Quando o pedido for `deploy`, `deploy do servidor`, `/deploy`, `restart`, `logs` ou `status`:

- Publicar **somente** o Node.js em `server/` (Vertix API).
- Não usar a skill de deploy da Music API (`whatlisten2019-master`).
- Não publicar o app Flutter, web, Play Store, nem o site snapdark.com.
- **Enviar tudo** de `server/`: src, prisma (schema + migrations), rotas, controllers, services, testes, `package.json`, `yarn.lock`, `deploy.md`. Não fazer commit parcial do “escopo do chat”.
- Não commitar `.env`, `dist/`, `node_modules`, logs, `public/dola-runs/`, `public/openrouter-video-runs/` nem secrets.
- `git push origin main` em `server/` **antes** de atualizar o host.
- No servidor: `git pull`. Se o pull falhar (árvore suja, conflito, untracked no caminho), `git reset --hard origin/main`. Não usar `git clean` (preserva `.env` e untracked).
- Compilar **antes** de recarregar o processo, para o downtime ser só o `pm2 reload`.

Procedimento e comandos: `server/deploy.md`.

- Recarregar com `pm2 reload vertix` (cluster). `pm2 restart` só se o reload falhar.
- Nunca apagar nem alterar dados do banco.
