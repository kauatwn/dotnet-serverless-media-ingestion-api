using MediaIngestionApi.Core.Entities;
using Moq;

namespace MediaIngestionApi.UnitTests.Entities;

public class ImageMetadataTests
{
    private readonly Mock<TimeProvider> _timeProviderMock = new();
    private readonly DateTimeOffset _fixedTime = new(2026, 8, 31, 15, 30, 0, TimeSpan.Zero);

    public ImageMetadataTests()
    {
        _timeProviderMock.Setup(t => t.GetUtcNow()).Returns(_fixedTime);
    }

    [Fact(DisplayName = "Create should instantiate entity and protect invariants when parameters are valid")]
    public void Create_ShouldInstantiateSuccessfully_WhenParametersAreValid()
    {
        // Arrange
        const string fileName = "avatar.png";
        const long sizeInBytes = 2048L;
        const string s3Url = "s3://my-bucket/avatar.png";

        // Act
        ImageMetadata entity = ImageMetadata.Create(fileName, sizeInBytes, s3Url, _timeProviderMock.Object);

        // Assert
        Assert.NotNull(entity);
        Assert.False(string.IsNullOrWhiteSpace(entity.ImageId));
        Assert.Equal(fileName, entity.FileName);
        Assert.Equal(sizeInBytes, entity.SizeInBytes);
        Assert.Equal(s3Url, entity.S3Url);
        Assert.Equal(_fixedTime.UtcDateTime, entity.UploadDate);
    }

    [Theory(DisplayName = "Create should throw ArgumentException when fileName is null, empty or whitespace")]
    [InlineData("")]
    [InlineData("   ")]
    public void Create_ShouldThrowArgumentException_WhenFileNameIsInvalid(string invalidFileName)
    {
        // Act & Assert
        ArgumentException ex = Assert.Throws<ArgumentException>(() =>
            ImageMetadata.Create(invalidFileName, 1024L, "s3://my-bucket/file.png", _timeProviderMock.Object));

        Assert.Equal("fileName", ex.ParamName);
    }

    [Theory(DisplayName = "Create should throw ArgumentOutOfRangeException when sizeInBytes is zero or negative")]
    [InlineData(0)]
    [InlineData(-100)]
    public void Create_ShouldThrowArgumentOutOfRangeException_WhenSizeIsZeroOrNegative(long invalidSize)
    {
        // Act & Assert
        ArgumentOutOfRangeException ex = Assert.Throws<ArgumentOutOfRangeException>(() =>
            ImageMetadata.Create("test.png", invalidSize, "s3://my-bucket/test.png", _timeProviderMock.Object));

        Assert.Equal("sizeInBytes", ex.ParamName);
    }

    [Fact(DisplayName = "Create should throw ArgumentOutOfRangeException when sizeInBytes exceeds maximum limit")]
    public void Create_ShouldThrowArgumentOutOfRangeException_WhenSizeExceedsMaximum()
    {
        // Arrange
        long oversized = ImageMetadata.MaxSizeBytes + 1;

        // Act & Assert
        ArgumentOutOfRangeException ex = Assert.Throws<ArgumentOutOfRangeException>(() =>
            ImageMetadata.Create("test.png", oversized, "s3://my-bucket/test.png", _timeProviderMock.Object));

        Assert.Equal("sizeInBytes", ex.ParamName);
    }

    [Theory(DisplayName = "Create should throw ArgumentException when s3Url is empty or not a valid URI")]
    [InlineData("")]
    [InlineData("not-a-valid-uri")]
    public void Create_ShouldThrowArgumentException_WhenS3UrlIsInvalid(string invalidS3Url)
    {
        // Act & Assert
        ArgumentException ex = Assert.Throws<ArgumentException>(() =>
            ImageMetadata.Create("test.png", 1024L, invalidS3Url, _timeProviderMock.Object));

        Assert.Equal("s3Url", ex.ParamName);
    }

    [Fact(DisplayName = "Create should throw ArgumentNullException when timeProvider is null")]
    public void Create_ShouldThrowArgumentNullException_WhenTimeProviderIsNull()
    {
        // Act & Assert
        ArgumentNullException ex = Assert.Throws<ArgumentNullException>(() =>
            ImageMetadata.Create("test.png", 1024L, "s3://my-bucket/test.png", null!));

        Assert.Equal("timeProvider", ex.ParamName);
    }

    [Fact(DisplayName = "Create should sanitize fileName when path contains directory traversal")]
    public void Create_ShouldSanitizeFileName_WhenPathContainsTraversal()
    {
        // Arrange
        const string maliciousPath = "../../sensitive/system/photo.jpg";

        // Act
        ImageMetadata entity = ImageMetadata.Create(maliciousPath, 1024L, "s3://my-bucket/photo.jpg", _timeProviderMock.Object);

        // Assert
        Assert.Equal("photo.jpg", entity.FileName);
    }

    [Fact(DisplayName = "Rehydrate should instantiate entity successfully from persistence data")]
    public void Rehydrate_ShouldInstantiateSuccessfully()
    {
        // Arrange
        string imageId = Guid.NewGuid().ToString();
        DateTime date = DateTime.UtcNow;

        // Act
        ImageMetadata entity = ImageMetadata.Rehydrate(imageId, "pic.png", 500L, "s3://bucket/pic.png", date);

        // Assert
        Assert.Equal(imageId, entity.ImageId);
        Assert.Equal("pic.png", entity.FileName);
        Assert.Equal(500L, entity.SizeInBytes);
        Assert.Equal(date, entity.UploadDate);
    }
}
