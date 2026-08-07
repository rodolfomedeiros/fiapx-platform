# Collection Postman — FIAP X E2E

Fluxo de ponta a ponta pelos quatro microsserviços mais a infraestrutura (RabbitMQ,
MinIO, Mailpit, Prometheus, Grafana), validado com Newman contra o ambiente real:
**20 requests, 40 assertions, 0 falhas**.

## Pré-requisito

O ambiente precisa estar de pé. Na raiz deste repositório:

```sh
docker compose up -d
```

## Importar

No Postman: **Import** → arraste os dois arquivos:

- `FIAP-X.postman_collection.json`
- `FIAP-X.postman_environment.json`

Selecione o environment **FIAP X — Local (docker compose)** no canto superior direito
antes de rodar qualquer request.

## Ordem

As pastas são numeradas e dependem umas das outras (token, `video_id`, `fail_video_id`
fluem de uma request para a próxima via collection variables):

1. **Auth** — cadastro, login, introspecção
2. **Vídeos, caminho feliz** — upload → aguardar → listar/filtrar → baixar o `.zip`
3. **Caminho de falha** — upload de vídeo inválido → 3 tentativas → `ERROR`
4. **Infraestrutura** — RabbitMQ (fila e DLQ), Mailpit (e-mail recebido), Prometheus
   (métricas), Grafana (dashboard)

## Rodando pela GUI

Clique request por request, na ordem. Os itens "Aguardar..." (2.2 e 3.2) seguram
~10s de propósito antes de continuar — é o tempo do worker consumir a fila e rodar
o FFmpeg.

## Rodando pelo Collection Runner ou Newman

A partir **desta pasta**, para que os caminhos relativos dos fixtures resolvam:

```sh
cd postman
npx newman run FIAP-X.postman_collection.json \
  -e FIAP-X.postman_environment.json \
  --delay-request 3000
```

O `--delay-request 3000` dá folga extra entre requests, somado ao busy-wait interno
dos itens "Aguardar...". Rodando de outro diretório, aponte o `--working-dir`:

```sh
npx newman run postman/FIAP-X.postman_collection.json \
  -e postman/FIAP-X.postman_environment.json \
  --working-dir postman --delay-request 3000
```

## Arquivos de teste

Em `fixtures/`: `test-video-valido.mp4` (5s, gera 5 frames) e
`test-video-quebrado.mp4` (`.mp4` truncado, sem *moov atom* — o FFmpeg rejeita,
disparando o caminho de retentativa).

Os requests de upload referenciam esses arquivos por **caminho relativo**
(`fixtures/...`), para que a collection funcione em qualquer máquina. O Newman
resolve isso a partir do diretório de trabalho; o app do Postman usa um diretório
próprio configurado em Settings, então lá pode ser necessário selecionar o arquivo
manualmente em Body → form-data → campo `file`.

## WebSocket

Não está na collection — o formato de item WebSocket varia entre versões do Postman
e arriscava quebrar a importação. Para testar manualmente: `New > WebSocket Request`
→ `ws://localhost:8080/videos/ws?token={{token}}` (rode a pasta 1 antes, para ter o
token) → Connect. Faça o upload da pasta 2 em outra aba: as mensagens `PROCESSING` e
`COMPLETED` chegam ao vivo na conexão aberta.

## Nota de design

Variáveis **estáticas** (URLs, credenciais) vivem no *environment*. Variáveis
**mutáveis** durante a execução (`token`, `video_id`, `fail_video_id`...) vivem
*apenas* como collection variables — se existissem também no environment, mesmo
vazias, o Postman daria precedência ao valor do environment na hora de resolver
`{{...}}`, e o `pm.collectionVariables.set(...)` do pre-request script seria
mascarado. Foi exatamente isso que quebrou a primeira versão desta collection.
