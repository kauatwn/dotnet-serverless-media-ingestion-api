# Serverless Native AOT Media Ingestion API

## 1. The Problem and Domain

Traditional serverless APIs suffer from the _Cold Start_ problem, where the runtime initialization time (like the .NET CLR) adds latency to the first requests.

The goal of this project is to build an image processing API that reduces this initialization latency and keeps costs tied exclusively to actual infrastructure usage.

## 2. Application Architecture and Patterns

The processing flow works in an orchestrated, synchronous manner with strict isolation of responsibilities:

- **Synchronous Edge Interception:** HTTP traffic is received and validated by **AWS API Gateway**, which acts as the central and synchronous computation trigger through `AWS_PROXY` integrations.
- **Ultra-Low Latency Computing (Native AOT):** The **AWS Lambda** function was developed using C# 14 and **.NET 10**, compiled natively via _Ahead-of-Time (AOT)_. By removing the JIT compiler and the heavy _runtime_ infrastructure from the container, cold start time is reduced to milliseconds.
- **Clean Architecture (Ports and Adapters):** The application core strictly applies dependency inversion. The `MediaIngestionApi.Core` layer defines the ports (`IStorageService`, `IMetadataRepository`), ensuring that the domain and image validation logic remains entirely decoupled from physical AWS SDKs (`AWSSDK.S3` and `AWSSDK.DynamoDB`), facilitating isolated unit testing.
- **Segregated and Distributed Persistence:** The image binary (received in Base64 format) is decoded and stored durably and immutably in **Amazon S3**. Simultaneously, technical indexing and structured media metadata are persisted at high speed in **Amazon DynamoDB**.

## 3. Resilience Engineering and Fault Tolerance

Synchronous and serverless operations require defensive guarantees coupled with the request lifecycle to prevent resource leaks and cascading failures:

| Component / Scenario          | Technical Risk                                                                              | Protection Mechanism                | Implementation Strategy                                                                                                                                                 |
| ----------------------------- | ------------------------------------------------------------------------------------------- | ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Initialization Bottleneck** | _Cold Starts_ causing timeouts and SLA breaches in concurrent requests.                     | Native Compilation (Native AOT)     | Optimization of the executable binary in the Docker _multi-stage build_, eliminating the reflection overhead of the traditional CLR.                                    |
| **DynamoDB Persistence**      | Transient network errors or throttling due to simultaneous write spikes.                    | Retry with Exponential Backoff      | Configuration of native resilience policies in the DynamoDB client to retry with progressive delays.                                                                    |
| **Write Consistency**         | Failure to write metadata to the database after the image has been successfully sent to S3. | Compensatory Transaction / Rollback | Defensive block in `UploadImageUseCase`: if DynamoDB rejects the insertion, an explicit object deletion command is triggered in S3 to prevent orphaned files.           |
| **IAM Scope Leakage**         | Exploitation of security breaches to access data from other contexts in the cloud account.  | Least Privilege IAM Policies        | IAM rules attached to the Lambda role restrict access solely to `PutObject`, `GetObject`, `DeleteObject`, and `PutItem` actions specifically on the bucket and table ARNs created in the environment. |

## 4. Architectural Decisions and FinOps Approach

The choice of components focuses on cost predictability and operational simplicity:

- **Scale to Zero:** Unlike EC2 instances or persistent ECS clusters that charge for provisioned idle capacity, the combination of AWS Lambda with the **DynamoDB On-Demand (Pay-Per-Request)** table model ensures that infrastructure costs are **zero** when there is no traffic, perfectly aligning with FinOps premises.
- **Why Containers (ECR) on AWS Lambda?** The Lambda function is packaged in a Docker image and hosted on **Amazon ECR**. This design decision mitigates the historical 250MB limit for ZIP file uploads on Lambda, and standardizes corporate CI/CD pipelines, allowing the same immutable container image to run locally (via LocalStack) and in production.
- **Total Infrastructure Abstraction:** Using API Gateway integrated directly with Lambda eliminates the need to maintain Application Load Balancer (ALB) instances running 24/7, drastically reducing the fixed network cost of the ecosystem.

## 5. Infrastructure as Code

The provisioning and lifecycle of the environment are managed in a 100% declarative manner using **Terraform**. The repository adopts the **Pure Modules** structural pattern segregated by AWS service, ensuring reusability, isolated testing, and high maintainability:

- **S3 Module (`modules/s3`):** Manages the S3 bucket with active AES256 server-side encryption and explicit public access block policies (`public_access_block`).
- **DynamoDB Module (`modules/dynamodb`):** Provisions the structured DynamoDB table with on-demand capacity (Pay-Per-Request) and Point-in-Time Recovery.
- **ECR Module (`modules/ecr`):** Manages the private Elastic Container Registry (ECR) repository with automated lifecycle policies to purge obsolete images.
- **Lambda Module (`modules/lambda`):** Provisions the containerized Lambda function, its CloudWatch Log Group, execution role, and least-privilege IAM policies.
- **API Gateway Module (`modules/apigateway`):** Configures the exposed HTTP mesh of the REST API Gateway, mapping resources (`/images`), POST method integration (`AWS_PROXY`), stages, and Lambda invocation permissions.

## 6. Known Limitations and Trade-offs

Choosing a synchronous serverless architecture imposes explicit physical constraints that were mapped into the design:

- **HTTP Payload Restriction (Edge Limits):** AWS API Gateway imposes a strict 10MB payload ceiling. Combined with AWS Lambda's 6MB synchronous limit and the size _overhead_ generated by encoding files in Base64 strings, the system becomes technically inadequate for transferring heavy media (such as videos).
- _Mitigation for Production:_ Evolution of the architecture to a hybrid model generating _Pre-signed URLs_ in S3, allowing the client to upload the binary directly to the cloud without burdening the API Gateway's memory and limits.
- **Rigid Synchronism and Temporal Coupling:** Because the API responds to the client only after completing operations in S3 and DynamoDB, the final latency perceived by the user is the sum of the execution times of the entire chain. Widespread failures in any of the AWS services directly impact response time.
- **Native AOT Debugging:** By compiling the code directly to native machine code, traditional runtime diagnostic tools and CLR memory profilers cannot be easily attached, making observability dependent on robust structured logging via `Amazon.Lambda.Core`.
