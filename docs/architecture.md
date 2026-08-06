# Arquitetura FIAP X

O Nginx expõe `/auth` e `/videos`. O auth-service emite JWTs e o serviço de vídeos os valida por `POST /api/v1/auth/introspect`, guardando as claims no Redis para não repetir a chamada a cada requisição.

Após o upload, o serviço Python armazena o original no MinIO e publica `video.received`. O worker Rust consome esse evento, publica `PROCESSING`, extrai um frame por segundo com FFmpeg, armazena o ZIP e publica `COMPLETED`. O serviço de vídeos consome `video.status.changed`, persiste o resultado e reparte a atualização pelo canal `video.updates` do Redis, de onde todas as réplicas a entregam aos seus WebSockets.

Após três falhas, o worker publica `video.failed`; o notification-service consome o evento e envia o e-mail ao Mailpit/SMTP. O contrato JSON de todos os eventos está em `contracts/video-event.schema.json`.

## APIs públicas

- `POST /auth/register`, `POST /auth/login`
- `POST /videos/upload`, `GET /videos`, `GET /videos/{id}/download`
- WebSocket: `/videos/ws?token=<jwt>`

## Barramento

Exchange `video.events`, do tipo topic. `video-processing-queue` (chave `video.received`)
tem dead lettering para `video.failed`, de modo que uma mensagem rejeitada chega sozinha à
DLQ e vira e-mail. `video-status-queue` recebe `video.status.changed` e
`video-processing-dlq` recebe `video.failed`.

## Observabilidade

Os quatro serviços expõem métricas: `/actuator/prometheus` no auth-service e `/metrics` nos
demais. O Prometheus também raspa o RabbitMQ em `:15692`, e descobre as réplicas do worker
por DNS. O dashboard do Grafana sobe provisionado.

## Escala

O worker roda uma task por mensagem, limitada pelo `basic_qos` (`PREFETCH`, padrão 4). O
HPA em `k8s/autoscaling.yaml` cria réplicas por CPU; o sinal ideal seria a profundidade da
fila, o que depende do Prometheus Adapter no cluster.
