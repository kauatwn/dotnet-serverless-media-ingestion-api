FROM mcr.microsoft.com/dotnet/runtime-deps:10.0-noble AS base
WORKDIR /var/task

# Uses the official .NET 10 AOT image (Ubuntu 24.04 Noble).
# This image comes pre-installed with clang, zlib, and all Native AOT build tools.
FROM mcr.microsoft.com/dotnet/sdk:10.0-noble-aot AS build
ARG TARGETARCH 
WORKDIR /src

# No apt-get required! The -aot tag natively supports compilation out of the box.

COPY ["src/MediaIngestionApi.Lambda.UploadImage/MediaIngestionApi.Lambda.UploadImage.csproj", "src/MediaIngestionApi.Lambda.UploadImage/"]
COPY ["src/MediaIngestionApi.Infrastructure/MediaIngestionApi.Infrastructure.csproj", "src/MediaIngestionApi.Infrastructure/"]
COPY ["src/MediaIngestionApi.Core/MediaIngestionApi.Core.csproj", "src/MediaIngestionApi.Core/"]
RUN dotnet restore "src/MediaIngestionApi.Lambda.UploadImage/MediaIngestionApi.Lambda.UploadImage.csproj"

COPY . .
WORKDIR "/src/src/MediaIngestionApi.Lambda.UploadImage"
ARG BUILD_CONFIGURATION=Release

# Resolves dynamic routing for the Native AOT compiler based on the GitHub Runner or Local Mac Architecture
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        RID="linux-x64"; \
    else \
        RID="linux-arm64"; \
    fi; \
    dotnet publish "MediaIngestionApi.Lambda.UploadImage.csproj" \
    -c "$BUILD_CONFIGURATION" \
    -r $RID \
    --self-contained true \
    -o /app/publish

FROM base AS final
WORKDIR /var/task
COPY --from=build /app/publish .
CMD ["./bootstrap"]