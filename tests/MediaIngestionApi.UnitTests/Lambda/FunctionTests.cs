using System.Net;
using System.Text.Json;
using Amazon.Lambda.APIGatewayEvents;
using Amazon.Lambda.TestUtilities;
using MediaIngestionApi.Core.Interfaces;
using MediaIngestionApi.Core.UseCases;
using MediaIngestionApi.Lambda.UploadImage;
using MediaIngestionApi.Lambda.UploadImage.Contracts;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;

namespace MediaIngestionApi.UnitTests.Lambda;

public class FunctionTests
{
    private readonly Mock<IStorageService> _storageMock = new();
    private readonly Mock<IMetadataRepository> _repositoryMock = new();
    private readonly Function _sut;

    public FunctionTests()
    {
        UploadImageUseCase useCase = new(_storageMock.Object, _repositoryMock.Object, NullLogger<UploadImageUseCase>.Instance);
        _sut = new Function(NullLogger<Function>.Instance, useCase);
    }

    [Fact(DisplayName = "FunctionHandler should return 200 OK and CORS headers for valid request")]
    public async Task FunctionHandler_ShouldReturn200_WhenRequestIsValid()
    {
        // Arrange
        const string base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=";
        const string fileName = "test.png";
        const string contentType = "image/png";
        const string expectedS3Url = "s3://test-bucket/test.png";

        _storageMock
            .Setup(s => s.UploadImageAsync(It.IsAny<byte[]>(), fileName, contentType, It.IsAny<CancellationToken>()))
            .ReturnsAsync(expectedS3Url);

        UploadImageRequest requestDto = new(fileName, contentType, base64);
        APIGatewayProxyRequest request = new()
        {
            Body = JsonSerializer.Serialize(requestDto, LambdaFunctionJsonSerializerContext.Default.UploadImageRequest)
        };

        TestLambdaContext context = new();

        // Act
        APIGatewayProxyResponse response = await _sut.FunctionHandler(request, context);

        // Assert
        Assert.Equal((int)HttpStatusCode.OK, response.StatusCode);
        Assert.True(response.Headers.ContainsKey("Access-Control-Allow-Origin"));
        Assert.Equal("*", response.Headers["Access-Control-Allow-Origin"]);
        Assert.True(response.Headers.ContainsKey("Access-Control-Allow-Methods"));

        UploadImageResponse? body = JsonSerializer.Deserialize<UploadImageResponse>(response.Body, LambdaFunctionJsonSerializerContext.Default.UploadImageResponse);

        Assert.NotNull(body);
        Assert.Equal(expectedS3Url, body.S3Url);
    }

    [Fact(DisplayName = "FunctionHandler should return 400 Bad Request when request body is empty")]
    public async Task FunctionHandler_ShouldReturn400_WhenBodyIsEmpty()
    {
        // Arrange
        APIGatewayProxyRequest request = new() { Body = "" };
        TestLambdaContext context = new();

        // Act
        APIGatewayProxyResponse response = await _sut.FunctionHandler(request, context);

        // Assert
        Assert.Equal((int)HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("empty or invalid", response.Body);
    }

    [Fact(DisplayName = "FunctionHandler should return 400 Bad Request when Base64Image is missing")]
    public async Task FunctionHandler_ShouldReturn400_WhenBase64IsMissing()
    {
        // Arrange
        UploadImageRequest requestDto = new("file.png", "image/png", "");
        APIGatewayProxyRequest request = new()
        {
            Body = JsonSerializer.Serialize(requestDto, LambdaFunctionJsonSerializerContext.Default.UploadImageRequest)
        };
        TestLambdaContext context = new();

        // Act
        APIGatewayProxyResponse response = await _sut.FunctionHandler(request, context);

        // Assert
        Assert.Equal((int)HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("missing Base64", response.Body);
    }

    [Fact(DisplayName = "FunctionHandler should return 400 Bad Request when UseCase throws ArgumentException")]
    public async Task FunctionHandler_ShouldReturn400_WhenUseCaseThrowsArgumentException()
    {
        // Arrange
        UploadImageRequest requestDto = new("script.sh", "application/x-sh", "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=");
        APIGatewayProxyRequest request = new()
        {
            Body = JsonSerializer.Serialize(requestDto, LambdaFunctionJsonSerializerContext.Default.UploadImageRequest)
        };
        TestLambdaContext context = new();

        // Act
        APIGatewayProxyResponse response = await _sut.FunctionHandler(request, context);

        // Assert
        Assert.Equal((int)HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("Unsupported content type", response.Body);
    }

    [Fact(DisplayName = "FunctionHandler should return 500 Internal Server Error when an unexpected exception occurs")]
    public async Task FunctionHandler_ShouldReturn500_WhenUnexpectedExceptionOccurs()
    {
        // Arrange
        _storageMock
            .Setup(s => s.UploadImageAsync(It.IsAny<byte[]>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("AWS S3 connection timeout"));

        UploadImageRequest requestDto = new("test.png", "image/png", "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=");
        APIGatewayProxyRequest request = new()
        {
            Body = JsonSerializer.Serialize(requestDto, LambdaFunctionJsonSerializerContext.Default.UploadImageRequest)
        };
        TestLambdaContext context = new();

        // Act
        APIGatewayProxyResponse response = await _sut.FunctionHandler(request, context);

        // Assert
        Assert.Equal((int)HttpStatusCode.InternalServerError, response.StatusCode);
        Assert.Contains("Internal server error", response.Body);
    }
}
