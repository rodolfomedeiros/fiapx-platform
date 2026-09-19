# HACKATON

## Sistema de Processamento de Vídeos - FIAP X

### Introdução

Vocês foram contratados pela empresa FIAP X que precisa avançar no desenvolvimento de um projeto de processamento de imagens. Em uma rodada de investimentos, a empresa apresentou um projeto simples que processa um vídeo e retorna as imagens dele em um arquivo .zip.

Os investidores gostaram tanto do projeto, que querem investir em uma versão onde eles possam enviar um vídeo e fazer download deste zip.

## PROJETO BASE

Projeto utilizado na apresentação para os investidores: [Download do projeto base](https://drive.google.com/file/d/1tFxsvY91Nc6J_iShvD1Evi3qdz61vaaa/view?usp=sharing)

## DESAFIO

O projeto desenvolvido está sem nenhuma das boas práticas de arquitetura de software que nós aprendemos durante o curso.

O seu desafio será desenvolver uma aplicação utilizando os conceitos apresentados, como:

- Desenho de arquitetura;
- Desenvolvimento de microsserviços;
- Qualidade de Software;
- Mensageria;
- E outros conceitos abordados.

## REQUISITOS FUNCIONAIS

Para ajudar o seu grupo nesta etapa de levantamento de requisitos, segue alguns dos pré-requisitos esperados para este projeto:

### Funcionalidades Essenciais

- A nova versão do sistema deve processar mais de um vídeo ao mesmo tempo.
- Em caso de picos, o sistema não deve perder uma requisição.
- O Sistema deve ser protegido por usuário e senha.
- O fluxo deve ter uma listagem de status dos vídeos de um usuário.
- Em caso de erro, um usuário pode ser notificado (e-mail ou outro meio de comunicação).

## REQUISITOS TÉCNICOS

### Arquitetura e Infraestrutura

- O sistema deve persistir os dados.
- O sistema deve estar em uma arquitetura que o permita ser escalado.
- O projeto deve ser versionado no Github.
- O projeto deve ter testes que garantam a sua qualidade.
- CI/CD da aplicação.

## STACK TECNOLÓGICA RECOMENDADA

- Containers: Docker + Kubernetes ou Docker Compose.
- Mensageria: RabbitMQ, Apache Kafka ou similar.
- Banco de Dados: PostgreSQL + Redis (cache) (ou um outro de preferência do grupo).
- Monitoramento: Prometheus + Grafana, ELK Stack ou algo de preferência do grupo.
- CI/CD: GitHub Actions (ou algo de preferência do grupo).

## ENTREGÁVEIS

### Documentação

- Documentação da arquitetura proposta para o projeto.
- Script de criação do banco de dados ou de outros recursos utilizados.

### Código

- Link do Github do(s) projeto(s).

## APRESENTAÇÃO

Vídeo de no máximo 10 minutos apresentando:

- Documentação.
- Arquitetura escolhida.
- O projeto funcionando.
