# fiapx-platform

Infraestrutura de desenvolvimento local, manifestos de Kubernetes e contratos compartilhados.

## Subindo com Docker Compose

```sh
docker compose up --build
```

| Serviço | Endereço |
| :--- | :--- |
| API (Nginx) | http://localhost:8080 |
| Swagger | http://localhost:8080/docs |
| RabbitMQ | http://localhost:15672 (fiapx / fiapx) |
| MinIO | http://localhost:9001 (fiapx / fiapx-minio-password) |
| Mailpit | http://localhost:8025 |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 (fiapx / fiapx) |

O dashboard **FIAP X — Processamento de vídeos** já vem provisionado no Grafana, com a
fonte de dados apontada para o Prometheus.

Para ver o paralelismo na prática, escale o worker e observe a fila esvaziar mais rápido:

```sh
docker compose up -d --scale video-processor-worker=4
```

O Prometheus descobre as réplicas por DNS, então todas aparecem sem editar configuração.

## Subindo no Kubernetes

```sh
./scripts/build-images.sh     # gera fiapx/*:latest
kubectl apply -k .
```

Os manifestos vivem em [k8s/](k8s/) e são montados pelo `kustomization.yaml` da raiz —
ele fica aqui, e não dentro de `k8s/`, porque o kustomize só lê arquivos abaixo da
própria raiz, e o schema do banco e a topologia do broker moram fora de `k8s/`,
compartilhados com o Compose para que as duas formas de subir o sistema não divirjam.

O HPA do worker precisa do metrics-server no cluster. O sinal ideal seria a profundidade
de `video-processing-queue`; enquanto o Prometheus Adapter não está instalado, a régua é
CPU, que é o recurso que a extração de quadros consome. A variante por fila está
comentada em [k8s/autoscaling.yaml](k8s/autoscaling.yaml).

O `Secret` em [k8s/config.yaml](k8s/config.yaml) tem valores de desenvolvimento. Em
qualquer ambiente compartilhado, gere-o fora do repositório.

## Contrato de eventos

[contracts/video-event.schema.json](contracts/video-event.schema.json) é a cópia canônica
do envelope trocado entre os serviços. Cada consumidor mantém uma cópia vendorizada e um
teste que acusa divergência quando este repositório está presente no checkout.

## Topologia do broker

`rabbitmq/definitions.json` declara o exchange `video.events`, as três filas e os
bindings. O `rabbitmq/rabbitmq.conf` é o que faz o broker realmente carregar esse arquivo.
