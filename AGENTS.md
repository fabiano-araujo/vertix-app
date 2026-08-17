# Vertix

Responda em português.

## Deploy

Quando o pedido for `deploy`, `deploy do servidor`, `/deploy`, `restart`, `logs` ou `status`:

- Publicar **somente** o submódulo Node.js em `server/` (Vertix API).
- Não usar a skill de deploy da Music API (`whatlisten2019-master`).
- Não publicar o app Flutter, web, Play Store, nem o site snapdark.com.
- Não fazer `git reset --hard` em produção: `/var/vertix` costuma ter alterações locais que não estão no git.

Procedimento, host e comandos: `server/deploy.md`.

- Servidor: `root@46.202.89.177`
- Pasta remota: `/var/vertix`
- Processo PM2: `vertix`
- Chave SSH: `C:\Users\Fabiano\Documents\server_oracle\private.ppk`
- Produção usa o remoto `https://github.com/fabiano-araujo/vertix-server.git`. O código local fica em `server/` dentro deste repo; `git pull` no host **não** puxa commits do `vertix-app`.
- O Node de produção é `20.19.5` e o `package.json` exige `>=22`. Compilar com `YARN_IGNORE_ENGINES=1 yarn build`.
- Nunca apagar nem alterar dados do banco.
