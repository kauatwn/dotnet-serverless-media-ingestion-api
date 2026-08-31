# Serverless Native AOT Media Ingestion API

## 1. The Problem and Domain

Traditional serverless APIs suffer from the _Cold Start_ problem, where the runtime initialization time (like the .NET CLR) adds latency to the first requests.

The goal of this project is to build a high-performance, resilient image processing API that reduces initialization latency to milliseconds, enforces domain invariants through Domain-Driven Design (DDD), and keeps costs tied exclusively to actual infrastructure usage.

## 2. Application Architecture and Patterns

The processing flow works in an orchestrated, synchronous manner with strict isolation of responsibilities:

- **Synchronous Edge Interception & Edge CORS:** HTTP traffic is received and validated by **AWS API Gateway**, which acts as the central and synchronous computation trigger through `AWS_PROXY` integrations. Pre-flight `OPTIONS` requests are handled directly at the API Gateway edge using `MOCK` integrations, returning CORS headers with zero Lambda invocation costs.
- **Ultra-Low Latency Computing (Native AOT):** The **AWS Lambda** function was developed using C# 14 and **.NET 10**, compiled natively via _Ahead-of-Time (AOT)_. By removing the JIT compiler and the heavy runtime infrastructure from the container, cold start time is reduced to milliseconds (< 15ms).
- **Domain-Driven Design (DDD) & Clean Architecture:** The application core strictly applies dependency inversion and rich domain encapsulation.
  - **Rich Domain Entity (`Entities/ImageMetadata.cs`):** Protects business invariants through private constructors and static factory methods (`Create` and `Rehydrate`), preventing any invalid state (e.g., path traversal, invalid file sizes, malformed URIs).
  - **Ports & Adapters:** The `MediaIngestionApi.Core` layer defines the ports (`IStorageService`, `IMetadataRepository`), ensuring that domain rules remain completely decoupled from physical AWS SDKs (`AWSSDK.S3` and `AWSSDK.DynamoDB`), facilitating isolated unit testing.
  - **Deterministic Time:** Injects `TimeProvider` to enable fully deterministic, time-frozen unit tests.
- **Segregated and Distributed Persistence:** The image binary is decoded in a single-pass buffer to optimize memory and stored immutably in **Amazon S3**. Simultaneously, technical indexing and structured media metadata are persisted at high speed in **Amazon DynamoDB**.

## 3. Resilience Engineering, SAGA Pattern, and Fault Tolerance

Synchronous serverless operations across distributed cloud resources require defensive guarantees to prevent resource leaks and data inconsistency:

| Component / Scenario               | Technical Risk                                                                              | Protection Mechanism                | Implementation Strategy                                                                                                                                                                               |
|------------------------------------| ------------------------------------------------------------------------------------------- | ----------------------------------- |-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Initialization Bottleneck**      | _Cold Starts_ causing timeouts and SLA breaches in concurrent requests.                     | Native Compilation (Native AOT)     | Optimization of the executable binary in the Docker _multi-stage build_, eliminating the reflection overhead of the traditional CLR.                                                                  |
| **Write Consistency (Dual-Write)** | Failure to write metadata to DynamoDB after the image binary was uploaded to S3.            | **SAGA Pattern (Compensatory Transaction)** | Defensive block in `UploadImageUseCase`: if DynamoDB persistence fails, an automated compensatory rollback (`DeleteImageAsync`) is executed in S3 to prevent orphaned ghost files.            |
| **DynamoDB Persistence**           | Transient network errors or throttling due to simultaneous write spikes.                    | Retry with Exponential Backoff      | Configuration of native resilience policies in the DynamoDB client to retry with progressive delays.                                                                                                  |
| **Input & Path Traversal**         | Malicious filenames or payloads overflowing memory.                                         | Encapsulated Domain Invariants      | Fail-fast validation in `UploadImageUseCase` and `ImageMetadata.Create`, restricting sizes to 6MB and sanitizing directory paths via `Path.GetFileName`.                                              |
| **IAM Scope Leakage**              | Exploitation of security breaches to access data from other contexts in the cloud account.  | Least Privilege IAM Policies        | IAM rules attached to the Lambda role restrict access solely to `PutObject`, `GetObject`, `DeleteObject`, and `PutItem` actions specifically on the bucket and table ARNs created in the environment. |

## 4. Testing Suite & CI/CD Tooling

The testing suite was built on top of modern .NET 10 standards:

- **Microsoft.Testing.Platform (MTP):** Migrated test projects to the standalone MTP runner with `xunit.v3` (v4.0.0) and `global.json`, eliminating deprecated VSTest collectors.
- **Native Cobertura Code Coverage:** Configured `Microsoft.Testing.Extensions.CodeCoverage` to output standard `coverage.cobertura.xml` reports, ready for native SonarQube Cloud ingestion.
- **Integration Tests with Testcontainers:** Comprehensive integration tests running real S3 and DynamoDB operations against a local **LocalStack** container.

## 5. Architectural Decisions and FinOps Approach

The choice of components focuses on cost predictability and operational simplicity:

- **Scale to Zero:** Unlike EC2 instances or persistent ECS clusters that charge for provisioned idle capacity, the combination of AWS Lambda with the **DynamoDB On-Demand (Pay-Per-Request)** table model ensures that infrastructure costs are **zero** when there is no traffic, perfectly aligning with FinOps premises.
- **Why Containers (ECR) on AWS Lambda?** The Lambda function is packaged in a Docker image and hosted on **Amazon ECR**. This design decision mitigates the historical 250MB limit for ZIP file uploads on Lambda, and standardizes corporate CI/CD pipelines, allowing the same immutable container image to run locally (via LocalStack) and in production.
- **Total Infrastructure Abstraction:** Using API Gateway integrated directly with Lambda eliminates the need to maintain Application Load Balancer (ALB) instances running 24/7, drastically reducing the fixed network cost of the ecosystem.

## 6. Infrastructure as Code

The provisioning and lifecycle of the environment are managed in a 100% declarative manner using **Terraform**. The repository adopts the **Pure Modules** structural pattern segregated by AWS service, adhering strictly to the HashiCorp Terraform Style Guide:

- **S3 Module (`modules/s3`):** Manages the S3 bucket with active AES256 server-side encryption and explicit public access block policies (`public_access_block`).
- **DynamoDB Module (`modules/dynamodb`):** Provisions the structured DynamoDB table with on-demand capacity (Pay-Per-Request) and Point-in-Time Recovery.
- **ECR Module (`modules/ecr`):** Manages the private Elastic Container Registry (ECR) repository with automated lifecycle policies to purge obsolete images.
- **Lambda Module (`modules/lambda`):** Provisions the containerized Lambda function, its CloudWatch Log Group, execution role, and least-privilege IAM policies.
- **API Gateway Module (`modules/apigateway`):** Configures the exposed REST API Gateway mesh, mapping resources (`/images`), POST method integration (`AWS_PROXY`), MOCK pre-flight OPTIONS CORS integration, stages, and Lambda invocation permissions.

## 7. Known Limitations and Trade-offs

Choosing a synchronous serverless architecture imposes explicit physical constraints that were mapped into the design:

- **HTTP Payload Restriction (Edge Limits):** AWS API Gateway imposes a strict 10MB payload ceiling. Combined with AWS Lambda's 6MB synchronous limit and the size overhead generated by encoding files in Base64 strings, the system becomes technically inadequate for transferring heavy media (such as videos).
- _Mitigation for Production:_ Evolution of the architecture to a hybrid model generating _Pre-signed URLs_ in S3, allowing the client to upload the binary directly to the cloud without burdening the API Gateway's memory and limits.
- **Rigid Synchronism and Temporal Coupling:** Because the API responds to the client only after completing operations in S3 and DynamoDB, the final latency perceived by the user is the sum of the execution times of the entire chain. Widespread failures in any of the AWS services directly impact response time.
- **Native AOT Debugging:** By compiling the code directly to native machine code, traditional runtime diagnostic tools and CLR memory profilers cannot be easily attached, making observability dependent on robust structured logging via `Amazon.Lambda.Core`.
