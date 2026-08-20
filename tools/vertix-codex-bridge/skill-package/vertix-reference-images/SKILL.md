---
name: vertix-reference-images
description: "Processa jobs de imagens de referencia do Vertix: le fichas de personagens, objetos e ambientes, gera cada bitmap com a skill imagegen e envia o arquivo imediatamente para a Vertix API. Use quando o pedido mencionar um job de reference images do Vertix, VERTIX_REFERENCE_JOB_ID, ou solicitar gerar masters visuais e devolve-los automaticamente ao projeto Vertix."
---

# Vertix Reference Images

Conclua o job inteiro sem pedir confirmacao. Este fluxo gera imagens reais; nao encerre entregando somente textos ou prompts.

## Entradas

A ponte local fornece estas variaveis ao processo:

- `VERTIX_REFERENCE_API_BASE`
- `VERTIX_REFERENCE_JOB_ID`
- `VERTIX_REFERENCE_JOB_TOKEN`

Nunca mostre, repita ou inclua o token na resposta final. O token so autoriza o job indicado e expira automaticamente.

Se a ponte cair no link nativo de contingencia, extraia API, job e token do pedido e passe-os como `--api-base`, `--job-id` e `--token` ao helper. Nao repita esses valores na resposta.

## Fluxo obrigatorio

1. Resolva `scripts/vertix_reference_job.py` em relacao a este `SKILL.md` e chame `manifest` sem passar o token na linha de comando:

   `python <script-absoluto> manifest`

2. Percorra na ordem apenas as referencias cujo status nao seja `COMPLETED`.
3. Antes de gerar cada item, chame:

   `python <script-absoluto> status --reference-id <id> --status GENERATING`

4. Invoque explicitamente a skill `$imagegen` e o gerador de imagens embutido uma vez para esse item. Use o `prompt` do manifesto como especificacao aprovada. Preserve identidade, categoria, descricao e restricoes; nao acrescente personagens, objetos, texto, logos ou marcas-dagua.
5. Obtenha o caminho local real do bitmap gerado. O modo embutido salva sob `$CODEX_HOME/generated_images`; nao use um preview remoto como substituto do arquivo.
6. Assim que a imagem terminar, antes de gerar o proximo item, envie-a:

   `python <script-absoluto> upload --reference-id <id> --file <arquivo-gerado>`

7. Confirme no JSON retornado que `reference.publicUrl` existe. Somente entao avance para a proxima ficha.
8. Se uma imagem falhar, registre a falha e continue com as demais:

   `python <script-absoluto> status --reference-id <id> --status FAILED --error <resumo-curto>`

9. Depois que todos os itens estiverem `COMPLETED` ou `FAILED`, chame:

   `python <script-absoluto> complete`

10. Responda de forma curta com quantas imagens foram enviadas e quantas falharam. Nao copie prompts longos nem credenciais.

## Regras de geracao

- Use o modo embutido da `$imagegen`; ele nao exige `OPENAI_API_KEY`.
- Faca uma chamada de geracao separada por referencia.
- Nao use o fallback CLI/API de imagem e nao solicite chave da OpenAI.
- Nao paralelize uploads do mesmo job: o progresso da API e sequencial e cada imagem deve aparecer no Vertix assim que pronta.
- Nao edite outros dados da serie nem use endpoints fora dos expostos pelo helper.
- Se o manifesto ja estiver terminal, apenas informe o estado; nao gere duplicatas.
