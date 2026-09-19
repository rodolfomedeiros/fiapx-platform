# Homologação do FIAP X para o hackathon

Data: 19/09/2026.

**Parecer: conformidade parcial; homologação final pendente.** A arquitetura cobre o escopo do enunciado e os fluxos principais possuem implementação. Há lacunas concretas em proteção dos arquivos, confiabilidade da mensageria e CI/CD, além de problemas na configuração Kubernetes. Não foi comprovado o funcionamento integrado nesta avaliação.

## Escopo e método

Base: [enunciado](POSTECH%20-%20SOAT%20-%20Fase%205%20-%20Hacka.md), [README da plataforma](../README.md) e [arquitetura](architecture.md), confrontados com os seis projetos locais, configurações, testes e workflows. A avaliação considera os arquivos atuais do workspace, incluindo alterações locais já existentes, e não apenas o último commit.

“Implementado” significa evidência no código, não aprovação em teste de execução. Não foram feitas alterações de implementação nem iniciados serviços. Kubernetes e as tecnologias da stack são recomendações/opções do enunciado; não são obrigatórios quando a alternativa escolhida satisfaz o requisito.

## Matriz de conformidade

| Requisito | Situação | Evidência e ressalva |
| --- | --- | --- |
| Enviar vídeo, extrair imagens e baixar ZIP | Implementado; execução pendente | API em `fiapx-video-management-service/app/main.py`; FFmpeg e ZIP em `fiapx-video-processor-worker/src/lib.rs`; interface em `fiapx-web/src/`. Validar o download com bucket privado e endereço público correto. |
| Processar mais de um vídeo simultaneamente | Implementado; carga pendente | Worker usa `tokio::spawn` e `basic_qos`, com `PREFETCH=4`; Compose permite réplicas e Kubernetes configura pelo menos duas. Falta medição de simultaneidade e capacidade. |
| Não perder requisições em picos | Parcial | Filas duráveis, mensagens persistentes, ACK e retentativas existem. Persistência do broker, publicação após commit e confirmação do worker deixam lacunas, detalhadas abaixo. |
| Proteção por usuário e senha | Parcial | Auth com BCrypt/JWT; API exige autenticação e verifica proprietário. Compose permite leitura anônima do bucket, contornando a proteção dos arquivos. |
| Listar status dos vídeos do usuário | Implementado com falha de consistência | Listagem filtra `user_id`, tem paginação/filtro e atualização por WebSocket. Eventos atrasados podem fazer o status regredir. |
| Notificar usuário em caso de erro | Implementado; execução pendente | Worker publica `video.failed`; notification-service envia SMTP. Mailpit permite demonstrar o recebimento local. Indisponibilidade prolongada do SMTP pode descartar a notificação. |
| Persistir dados | Atendido para dados e arquivos; parcial para trabalho pendente | PostgreSQL e MinIO têm volumes no Compose e PVCs no Kubernetes; RabbitMQ não possui armazenamento de dados explicitamente persistente nesses manifestos. |
| Arquitetura escalável | Atendido no desenho; validação operacional pendente | Serviços separados, fila, réplicas, HPA e Redis distribuindo atualizações de WebSocket. Há erro na configuração de conexão do serviço de vídeos no Kubernetes. |
| Versionamento no GitHub | Evidenciado localmente | Os seis repositórios têm `origin` no GitHub; README aponta os cinco serviços. Publicação do estado atual e acesso da banca não foram verificados remotamente. |
| Testes de qualidade | Parcialmente evidenciado | Quatro serviços têm suítes e gates de cobertura de 80%; existem 20 requests/40 assertions Postman. As suítes não foram executadas nesta avaliação; frontend tem lint/build, sem suíte de testes identificada. O enunciado não exige percentual específico. |
| CI/CD da aplicação | Parcial | GitHub Actions valida/testa e constrói imagens. Não há publicação de imagens, release ou deploy nos workflows inspecionados. Há CI, mas não foi encontrada entrega contínua configurada. |
| Documentação da arquitetura | Atendido | README contém diagramas, fluxos e operação; `docs/architecture.md` complementa. Algumas garantias descritas precisam de correção. |
| Scripts de banco e recursos | Atendido | `postgres/init.sql`, Flyway no auth, Compose, Kustomize, manifestos e definições RabbitMQ. |
| Links dos projetos | Atendido no README | Links dos serviços presentes; incluir também o link explícito da plataforma no pacote final de entrega. |
| Vídeo de até 10 minutos | Não evidenciado | Não foi encontrado link de apresentação nos documentos inspecionados. Isso não prova que o vídeo inexista fora do workspace. |
| Stack recomendada | Atendida no Compose | Docker, RabbitMQ, PostgreSQL, Redis, Prometheus, Grafana e Actions presentes. O Kustomize não inclui instalação de Prometheus/Grafana; as anotações de métricas não substituem esses serviços. |

## Pendências prioritárias

### 1. Recuperação de trabalho em picos e falhas

- **Broker sem volume de dados explícito:** `docker-compose.yml`, serviço `rabbitmq`, monta apenas configuração; `k8s/infra.yaml`, deployment `rabbitmq`, também só monta configuração. Filas duráveis não bastam se o armazenamento se perde ao substituir o container/pod. No Compose, um eventual volume anônimo da imagem não oferece o mesmo vínculo explícito de recuperação de um volume nomeado. Declarar volume/PVC e comprovar preservação após recriação.
- **Upload sem publicação atomicamente recuperável:** `fiapx-video-management-service/app/main.py:119` confirma o registro antes de publicar `video.received`. Se a publicação falhar, o arquivo e o registro podem ficar em `RECEIVED` sem trabalho na fila. A resposta 202 ainda não foi enviada nesse caso, mas não há recuperação automática do upload persistido. Adotar outbox transacional ou mecanismo equivalente de reconciliação e idempotência.
- **Publicação do worker:** `fiapx-video-processor-worker/src/main.rs` não habilita `confirm_select` nem trata explicitamente ACK/NACK de publicação antes do ACK da mensagem consumida. Conferir o comportamento da versão Lapin 2.5 e implementar confirmação efetiva de recebimento, incluindo falhas de roteamento. A API Lapin documenta que aguardar a publicação sem habilitar confirms pode resultar em `NotRequested`, sem confirmação do broker ([referência da API](https://docs.rs/lapin/latest/lapin/struct.PublisherConfirm.html)).

Critério de aceite: sob uma carga definida, todos os uploads aceitos devem chegar a um desfecho rastreável; interrupções de broker/API/worker não podem deixar trabalho perdido ou sem possibilidade de recuperação. Registrar quantidade enviada, aceita, concluída, com erro e pendente.

### 2. Arquivos acessíveis sem autenticação no Compose

`docker-compose.yml:36` executa `mc anonymous set download local/videos`, e a porta 9000 está publicada. Quem tiver o caminho de um objeto pode tentar acessá-lo diretamente sem passar pelo login e pela verificação de proprietário da API. Remover a política anônima e validar acesso negado sem assinatura, isolamento entre usuários e expiração do link autorizado.

`fiapx-video-management-service/app/storage.py:47` também troca o endpoint depois de gerar a URL assinada. Para SigV4, o host faz parte da assinatura: alterar esse host compromete sua validade ([documentação AWS](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_sigv-create-signed-request.html)). O código não fixa explicitamente a versão da assinatura; portanto, a falha exata de download precisa ser reproduzida com a configuração efetiva. Gerar a assinatura para o endereço público correto e testar em MinIO real com bucket privado. Os testes atuais usam um cliente falso e não validam a assinatura.

### 3. CI sem etapa de entrega

Os workflows dos serviços terminam em `docker build .`; o da plataforma valida Compose e Kustomize. Não há publicação de artefato versionado em registry, promoção de release ou deploy. Implementar um fluxo de entrega rastreável, com publicação das imagens e implantação verificável no ambiente escolhido. A implantação pode ter aprovação manual; o problema é a ausência de um fluxo de entrega evidenciado.

### 4. Configuração Kubernetes incompleta para o fluxo documentado

Em `k8s/services.yaml:79`, `DATABASE_URL` referencia `$(POSTGRES_USER)` e `$(POSTGRES_PASSWORD)` antes da declaração dessas variáveis em `env`. A expansão depende da ordem da lista ([documentação Kubernetes](https://kubernetes.io/docs/tasks/inject-data-application/define-interdependent-environment-variables/)). Reordenar as entradas para evitar credenciais não expandidas.

Além disso, `k8s/config.yaml` não define `S3_PUBLIC_ENDPOINT_URL`; o padrão em `app/config.py` é o endpoint interno `http://minio:9000`. Não há rota pública do MinIO nos Ingress fornecidos. O link entregue a um navegador externo não tem caminho público configurado. Definir esse acesso e validar download antes de apresentar Kubernetes como alternativa funcional. Esses problemas não tornam Kubernetes obrigatório para a entrega: é possível homologar a alternativa Compose após resolver suas próprias pendências.

### 5. Eventos atrasados podem regredir o status

`fiapx-video-management-service/app/main.py:36` substitui o status sem verificar versão, ordem do evento ou transição permitida. O teste `test_transicao_intermediaria_preserva_o_zip_ja_gravado`, em `tests/test_status_flow.py`, confirma que um vídeo `COMPLETED` pode voltar para `PROCESSING`. Com reentregas e múltiplos consumidores, isso pode bloquear o download de um ZIP já pronto.

Definir transições válidas e tratamento de eventos repetidos/atrasados, com atualização condicional no banco. Validar especialmente `COMPLETED` seguido de um evento antigo `PROCESSING`.

## Outras ressalvas da arquitetura

- `terminationGracePeriodSeconds: 120` não implementa sozinho a espera pelos trabalhos ativos. Não foi identificado tratamento de SIGTERM e drenagem das tasks no worker; a afirmação de que o vídeo em curso termina antes da saída precisa de implementação e teste.
- Extração FFmpeg e compactação usam operações síncronas dentro de tasks Tokio. Há paralelismo por réplicas, mas o `PREFETCH=4` não comprova quatro extrações efetivamente simultâneas nem ausência de bloqueio do runtime. Medir e considerar isolamento dessas operações bloqueantes.
- O notification-service rejeita sem reenfileirar após uma segunda falha de SMTP; `video-processing-dlq` não tem outra DLQ configurada. Se for desejada recuperação da notificação, implementar retenção/reprocessamento. A notificação local via Mailpit é adequada para demonstração, mas não comprova entrega em caixa externa.
- O README menciona esperas de 1s, 2s e 4s. Com `MAX_ATTEMPTS=3` e eventos começando em zero, `decide` produz três tentativas totais, com esperas de 1s e 2s; não há terceira espera de 4s nesse fluxo.
- `video-status-dlq` conserva falhas para inspeção, mas não foi encontrado um fluxo automatizado de reprocessamento. Preservar a mensagem não garante que o status do usuário será atualizado sem intervenção.

## Verificações realizadas

- `docker compose config --quiet`: passou.
- Comparação JSON dos contratos de eventos: as três cópias dos serviços coincidem com a plataforma.
- Inspeção da collection Postman: 20 requests e 40 chamadas `pm.test`, coerentes com o README. Contagem não equivale a testes aprovados.
- Remotes Git locais: seis repositórios apontam para GitHub.
- Consulta somente de leitura ao Docker: auth, gateway, web, PostgreSQL, RabbitMQ, Redis, MinIO, Mailpit, Prometheus e Grafana estavam parados; somente notification, video-management e worker apareciam em execução. O ambiente não estava apto a um teste integrado.
- Não foram executados testes unitários, carga, collection Postman ou implantação Kubernetes. Maven, Cargo, Node e kubectl não estavam disponíveis no PATH consultado. Não foram verificadas execuções remotas de CI nem cobertura atual. Os containers existentes também não comprovam correspondência com o código atual.

## Condições para homologação final

1. Corrigir proteção dos arquivos, recuperação de publicação e persistência do broker; tratar confirmação do worker e regressão de status.
2. Completar e evidenciar o fluxo de CI/CD.
3. No ambiente escolhido, executar as suítes e a collection; verificar o conteúdo do ZIP, autenticação, isolamento entre dois usuários e notificação de falha.
4. Demonstrar processamento concorrente e executar teste de pico com interrupções controladas e reconciliação de todos os uploads aceitos.
5. Se Kubernetes fizer parte da demonstração, validar as correções de conexão, acesso ao storage, réplicas e HPA.
6. Entregar os links acessíveis dos repositórios e um vídeo de no máximo dez minutos cobrindo documentação, arquitetura e sistema funcionando.

O desenho está alinhado ao desafio, mas a aprovação integral depende das correções e das evidências acima. Não é necessário acrescentar tecnologias além das pedidas para resolver essas pendências.
