# Serverless Image Processor (Native AOT)

## 1. O Problema e o Domínio

APIs desenvolvidas em ecossistemas Serverless tradicionais sofrem frequentemente com o problema de _Cold Start_ (inicialização a frio), onde o provisionamento do _runtime_ (como o CLR do .NET ou a JVM do Java) adiciona latência inaceitável nas primeiras requisições. O objetivo deste projeto é construir uma API de processamento de imagens estritamente síncrona, eliminando a latência de inicialização e garantindo custos atrelados exclusivamente ao uso real.

## 2. A Arquitetura da Aplicação e Padrões

O sistema é projetado em uma topologia Serverless síncrona:

- **Intercepção na Borda:** O tráfego HTTP é recebido pelo **AWS API Gateway**, que atua como gatilho síncrono para a computação.
- **Computação Otimizada (Native AOT):** A função **AWS Lambda** foi desenvolvida em C# 14 (.NET 10) e compilada nativamente (_Ahead-of-Time_). Isso remove o _runtime_ do .NET do contêiner, reduzindo o tempo de _Cold Start_ a patamares de milissegundos.
- **Desacoplamento de Domínio:** O código aplica Inversão de Dependência (Ports and Adapters), isolando a lógica de processamento de imagem dos SDKs específicos da AWS.
- **Persistência Distribuída:** O binário da imagem é armazenado de forma durável no **Amazon S3**, enquanto a indexação e os metadados são persistidos em alta velocidade no **Amazon DynamoDB**.

## 3. Decisões Arquiteturais e FinOps

A arquitetura Serverless pura impõe benefícios e limites que foram intencionalmente mapeados:

- **Escala a Zero e FinOps:** Diferente de instâncias EC2 ou contêineres ECS persistentes, esta infraestrutura escala organicamente a zero. A cobrança no AWS Lambda e no DynamoDB sob demanda ocorre estritamente pelos milissegundos de execução e pelas Unidades de Escrita (WCU) utilizadas, garantindo custo zero em períodos de ociosidade.
- **Por que Contêineres (ECR) no Lambda?** Para superar o limite estrito de 250MB para pacotes ZIP no Lambda e padronizar as esteiras de CI/CD, a função é empacotada em uma imagem Docker via _multi-stage build_ e servida através do **Amazon ECR**.

## 4. A Infraestrutura como Código

A orquestração do ambiente é gerenciada pelo **Terraform**, utilizando o padrão de Módulos Puros (IoC) para garantir isolamento e manutenibilidade:

- O ambiente de desenvolvimento (Glue Code) orquestra e injeta as dependências entre os módulos de Storage, Compute e API.
- A política IAM (Identity and Access Management) da função Lambda é restrita através do princípio do menor privilégio, possuindo liberação explícita apenas para os ARNs específicos do S3 e DynamoDB provisionados no escopo.

## 5. Limitações Conhecidas e Trade-offs

O fluxo síncrono apresenta limitações inerentes ao protocolo HTTP e à plataforma Serverless:

- **Tamanho do Payload:** O AWS API Gateway restringe payloads a 10MB, e requisições síncronas do Lambda são limitadas a 6MB. Juntamente com a sobrecarga de 33% do formato Base64, o sistema é adequado apenas para mídias leves (como avatares).
- **Evolução Arquitetural:** Para processamento de arquivos pesados, a arquitetura deve evoluir para um modelo assíncrono (Event-Driven), gerando _Pre-signed URLs_ na API e delegando o processamento para processos longos, como AWS Fargate.
