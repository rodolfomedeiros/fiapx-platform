# Arquitetura FIAP X

O Nginx expõe `/auth` e `/videos`. O auth-service emite JWTs e o serviço de vídeos os valida por `POST /api/v1/auth/introspect`.

Após o upload, o serviço Python armazena o original no MinIO e publica `video.received`. O worker Rust consome esse evento, publica `PROCESSING`, extrai um frame por segundo com FFmpeg, armazena o ZIP e publica `COMPLETED`. O serviço de vídeos consome `video.status.changed`, persiste o resultado e transmite-o ao WebSocket do usuário.

Após três falhas, o worker publica `video.failed`; o notification-service consome o evento e envia o e-mail ao Mailpit/SMTP. O contrato JSON de todos os eventos está em `contracts/video-event.schema.json`.

## APIs públicas

- `POST /auth/register`, `POST /auth/login`
- `POST /videos/upload`, `GET /videos`, `GET /videos/{id}/download`
- WebSocket: `/videos/ws?token=<jwt>`
