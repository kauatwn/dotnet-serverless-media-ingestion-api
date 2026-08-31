using MediaIngestionApi.Core.Entities;
using MediaIngestionApi.Core.Interfaces;
using MediaIngestionApi.Core.UseCases;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;

namespace MediaIngestionApi.UnitTests.UseCases;

public class UploadImageUseCaseTests
{
    private readonly Mock<IStorageService> _storageMock = new();
    private readonly Mock<IMetadataRepository> _repositoryMock = new();
    private readonly DateTimeOffset _fixedTime = new(2026, 8, 31, 12, 0, 0, TimeSpan.Zero);

    private readonly UploadImageUseCase _sut;

    public UploadImageUseCaseTests()
    {
        Mock<TimeProvider> timeProviderMock = new();
        timeProviderMock.Setup(t => t.GetUtcNow()).Returns(_fixedTime);

        _sut = new UploadImageUseCase(
            _storageMock.Object,
            _repositoryMock.Object,
            NullLogger<UploadImageUseCase>.Instance,
            timeProviderMock.Object);
    }

    [Fact(DisplayName = "ExecuteAsync should upload to S3, save to DynamoDB and return metadata")]
    public async Task ExecuteAsync_ShouldProcessSuccessfully()
    {
        // Arrange
        const string validBase64Image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=";
        const string expectedFileName = "photo.png";
        const string expectedContentType = "image/png";
        const string expectedS3Url = $"s3://my-bucket/{expectedFileName}";

        _storageMock
            .Setup(s => s.UploadImageAsync(It.IsAny<byte[]>(), expectedFileName, expectedContentType, It.IsAny<CancellationToken>()))
            .ReturnsAsync(expectedS3Url);

        // Act
        ImageMetadata result = await _sut.ExecuteAsync(validBase64Image, expectedFileName, expectedContentType, TestContext.Current.CancellationToken);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(expectedFileName, result.FileName);
        Assert.Equal(expectedS3Url, result.S3Url);
        Assert.NotEqual(Guid.Empty.ToString(), result.ImageId);
        Assert.True(result.SizeInBytes > 0);
        Assert.Equal(_fixedTime.UtcDateTime, result.UploadDate);

        _repositoryMock.Verify(r => r.SaveMetadataAsync(
            It.Is<ImageMetadata>(m => m.ImageId == result.ImageId && m.S3Url == expectedS3Url),
            It.IsAny<CancellationToken>()),
            Times.Once);

        _storageMock.Verify(s => s.DeleteImageAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact(DisplayName = "ExecuteAsync should trigger compensatory rollback in S3 when DynamoDB persistence fails")]
    public async Task ExecuteAsync_ShouldTriggerRollback_WhenRepositoryFails()
    {
        // Arrange
        const string validBase64Image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=";
        const string expectedFileName = "photo.png";
        const string expectedContentType = "image/png";
        const string expectedS3Url = $"s3://my-bucket/{expectedFileName}";

        _storageMock
            .Setup(s => s.UploadImageAsync(It.IsAny<byte[]>(), expectedFileName, expectedContentType, It.IsAny<CancellationToken>()))
            .ReturnsAsync(expectedS3Url);

        _repositoryMock
            .Setup(r => r.SaveMetadataAsync(It.IsAny<ImageMetadata>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("DynamoDB write failed"));

        // Act & Assert
        InvalidOperationException ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _sut.ExecuteAsync(validBase64Image, expectedFileName, expectedContentType, TestContext.Current.CancellationToken));

        Assert.Equal("DynamoDB write failed", ex.Message);

        // Assert compensatory rollback
        _storageMock.Verify(s => s.DeleteImageAsync(expectedS3Url, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact(DisplayName = "ExecuteAsync should throw ArgumentException when Base64 is invalid")]
    public async Task ExecuteAsync_ShouldThrowArgumentException_WhenBase64IsInvalid()
    {
        // Arrange
        const string invalidBase64 = "this-is-not-valid-base64!!!";

        // Act & Assert
        ArgumentException ex = await Assert.ThrowsAsync<ArgumentException>(() =>
            _sut.ExecuteAsync(invalidBase64, "test.png", "image/png", TestContext.Current.CancellationToken));

        Assert.Contains("Invalid Base64", ex.Message);
        _storageMock.Verify(s => s.UploadImageAsync(It.IsAny<byte[]>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact(DisplayName = "ExecuteAsync should throw ArgumentException when ContentType is unsupported")]
    public async Task ExecuteAsync_ShouldThrowArgumentException_WhenContentTypeIsUnsupported()
    {
        // Arrange
        const string validBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=";

        // Act & Assert
        ArgumentException ex = await Assert.ThrowsAsync<ArgumentException>(() =>
            _sut.ExecuteAsync(validBase64, "script.sh", "application/x-sh", TestContext.Current.CancellationToken));

        Assert.Contains("Unsupported content type", ex.Message);
        _storageMock.Verify(s => s.UploadImageAsync(It.IsAny<byte[]>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact(DisplayName = "ExecuteAsync should sanitize fileName to avoid path traversal")]
    public async Task ExecuteAsync_ShouldSanitizeFileName()
    {
        // Arrange
        const string validBase64Image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=";
        const string maliciousPath = "../../etc/passwd/malicious.png";
        const string expectedSanitizedFileName = "malicious.png";
        const string expectedS3Url = $"s3://my-bucket/{expectedSanitizedFileName}";

        _storageMock
            .Setup(s => s.UploadImageAsync(It.IsAny<byte[]>(), expectedSanitizedFileName, "image/png", It.IsAny<CancellationToken>()))
            .ReturnsAsync(expectedS3Url);

        // Act
        ImageMetadata result = await _sut.ExecuteAsync(validBase64Image, maliciousPath, "image/png", TestContext.Current.CancellationToken);

        // Assert
        Assert.Equal(expectedSanitizedFileName, result.FileName);
    }
}
