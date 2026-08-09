# Serverless Native AOT Media Ingestion API

## 1. O Problema e o Domínio

APIs serverless tradicionais sofrem com o problema de _Cold Start_, onde o tempo de inicialização do runtime (.NET CLR) adiciona latência nas primeiras requisições.

O objetivo deste projeto é construir uma API de processamento de imagens que reduz essa latência de inicialização e mantém custos atrelados exclusivamente ao uso real da infraestrutura.

## 2. A Arquitetura da Aplicação e Padrões

O fluxo de processamento funciona de forma orquestrada, síncrona e com isolamento de responsabilidades:

- **Intercepção síncrona na Borda:** O tráfego HTTP é recebido e validado pelo **AWS API Gateway**, que atua como o gatilho central e síncrono da computação por meio de integrações do tipo `AWS_PROXY`.
- **Computação de Baixíssima Latência (Native AOT):** A função **AWS Lambda** foi desenvolvida utilizando C# 14 e **.NET 10**, compilada nativamente via _Ahead-of-Time (AOT)_. Ao remover o compilador JIT e a infraestrutura pesada do _runtime_ do contêiner, o tempo de inicialização a frio é reduzido a patamares de milissegundos.
- **Arquitetura Limpa (Ports and Adapters):** O núcleo da aplicação aplica inversão de dependência de forma rigorosa. A camada `ImageProcessor.Core` define as portas (`IStorageService`, `IMetadataRepository`), garantindo que a lógica de domínio e validação de imagens permaneça totalmente desacoplada dos SDKs físicos da AWS (`AWSSDK.S3` e `AWSSDK.DynamoDB`), facilitando a testabilidade unitária isolada.
- **Persistência Segregada e Distribuída:** O binário da imagem (recebido em formato Base64) é decodificado e armazenado de forma durável e imutável no **Amazon S3**. Simultaneamente, a indexação técnica e os metadados estruturados da mídia são persistidos em alta velocidade no **Amazon DynamoDB**.

## 3. Engenharia de Resiliência e Tolerância a Falhas

A operação síncrona e serverless exige garantias defensivas acopladas ao ciclo de vida da requisição para evitar vazamento de recursos e falhas em cascata:

| Componente / Cenário           | Risco Técnico                                                                              | Mecanismo de Proteção              | Estratégia de Implementação                                                                                                                                                      |
| ------------------------------ | ------------------------------------------------------------------------------------------ | ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Gargalo de Inicialização**   | _Cold Starts_ gerando timeouts e quebra de SLA em requisições concorrentes.                | Compilação Nativa (Native AOT)     | Otimização do binário executável no _multi-stage build_ do Docker, eliminando a sobrecarga de reflexão do CLR tradicional.                                                       |
| **Persistência no DynamoDB**   | Erros transitórios de rede ou throttling por picos de escrita simultâneas.                 | Retry com Exponential Backoff      | Configuração de políticas de resiliência nativas no cliente do DynamoDB para redefinir tentativas com atraso progressivo.                                                        |
| **Consistência de Escrita**    | Falha ao gravar metadados no banco após a imagem já ter sido enviada com sucesso ao S3.    | Transação Compensatória / Rollback | Bloco defensivo no `UploadImageUseCase`: caso o DynamoDB rejeite a inserção, um comando explícito de exclusão do objeto é disparado no S3 para evitar arquivos órfãos.           |
| **Vazamento de Escopo no IAM** | Exploração de brechas de segurança para acesso a dados de outros contextos da conta cloud. | Least Privilege IAM Policies       | As regras do IAM vinculadas à role da Lambda delimitam o acesso apenas para as ações `PutObject` e `PutItem` especificamente nos ARNs do bucket e da tabela criados no ambiente. |

## 4. Decisões Arquiteturais e Abordagem de FinOps

A escolha dos componentes foca em previsibilidade de custo e simplicidade operacional:

- **Escala a Zero:** Diferente de instâncias EC2 ou clusters ECS persistentes que cobram por capacidade ociosa provada, a combinação de AWS Lambda com o modelo de tabelas **DynamoDB On-Demand (Pay-Per-Request)** garante que o custo da infraestrutura seja **zero** quando não houver tráfego, alinhando-se perfeitamente às premissas de FinOps.
- **Por que Contêineres (ECR) no AWS Lambda?** A função Lambda é empacotada em uma imagem Docker e hospedada no **Amazon ECR**. Essa decisão de design mitiga o limite histórico de 250MB para uploads via arquivos ZIP no Lambda, além de padronizar os pipelines de CI/CD corporativos, permitindo rodar a mesma imagem de contêiner imutável localmente (via LocalStack) e em produção.
- **Abstração Total de Infraestrutura:** O uso do API Gateway integrado diretamente ao Lambda elimina a necessidade de manter instâncias de Application Load Balancers (ALB) ativos 24/7, reduzindo drasticamente o custo fixo de rede do ecossistema.

## 5. A Infraestrutura como Código

O provisionamento e o ciclo de vida do ambiente são gerenciados de forma 100% declarativa através do **Terraform**. O repositório adota o padrão estrutural de **Módulos Puros (Pure Modules)**, garantindo reutilização, testes isolados e alta manutenibilidade:

- **Módulo de Storage:** Centraliza o bucket S3 (com criptografia ativa AES256 e políticas explícitas de bloqueio de acesso público - `public_access_block`) e a tabela estruturada do DynamoDB.
- **Módulo de Compute:** Gerencia o repositório privado do ECR com políticas de ciclo de vida (para expurgar imagens antigas de build), a criação da função Lambda e suas respectivas roles de execução.
- **Módulo de API:** Configura a malha HTTP exposta do API Gateway, mapeando métodos, recursos e permissões de invocação (`lambda_permission`) cruzadas.

## 6. Limitações Conhecidas e Trade-offs

A escolha por uma arquitetura Serverless síncrona impõe restrições físicas explícitas que foram mapeadas no design:

- **Restrição de Payload HTTP (Limites da Borda):** O AWS API Gateway impõe um teto rígido de 10MB por payload. Somado ao limite síncrono de 6MB do AWS Lambda e ao _overhead_ de tamanho gerado pela codificação de arquivos em strings Base64, o sistema torna-se tecnicamente inadequado para a transferência de mídias pesadas (como vídeos).
- _Mitigação para Produção:_ Evolução da arquitetura para um modelo híbrido com geração de _Pre-signed URLs_ no S3, permitindo que o cliente faça o upload direto do binário para a nuvem sem onerar a memória e os limites da API Gateway.

- **Sincronismo Rígido e Acoplamento Temporal:** Como a API responde ao cliente apenas após a conclusão das operações no S3 e no DynamoDB, a latência final percebida pelo usuário é a soma dos tempos de execução de toda a cadeia. Falhas generalizadas em qualquer um dos serviços da AWS impactam o tempo de resposta diretamente.
- **Depuração de Native AOT:** Ao compilar o código diretamente para código de máquina nativo, ferramentas tradicionais de diagnóstico em tempo de execução e profiles de memória da CLR não podem ser anexados facilmente, tornando a observabilidade dependente de logs estruturados robustos via `Amazon.Lambda.Core`.
