namespace MediaIngestionApi.Core.Entities;

public sealed record ImageMetadata
{
    public const long MaxSizeBytes = 6 * 1024 * 1024; // 6MB synchronous Lambda payload limit

    public string ImageId { get; }
    public string FileName { get; }
    public long SizeInBytes { get; }
    public string S3Url { get; }
    public DateTime UploadDate { get; }

    private ImageMetadata(string imageId, string fileName, long sizeInBytes, string s3Url, DateTime uploadDate)
    {
        ImageId = imageId;
        FileName = fileName;
        SizeInBytes = sizeInBytes;
        S3Url = s3Url;
        UploadDate = uploadDate;
    }

    public static ImageMetadata Create(string fileName, long sizeInBytes, string s3Url, TimeProvider timeProvider)
    {
        ArgumentNullException.ThrowIfNull(timeProvider);
        
        ArgumentException.ThrowIfNullOrWhiteSpace(fileName);
        string sanitizedFileName = Path.GetFileName(fileName.Trim());
        ArgumentException.ThrowIfNullOrWhiteSpace(sanitizedFileName, nameof(fileName));
        
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(sizeInBytes);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(sizeInBytes, MaxSizeBytes);
        
        ArgumentException.ThrowIfNullOrWhiteSpace(s3Url);
        if (!s3Url.StartsWith("s3://", StringComparison.OrdinalIgnoreCase) && !Uri.IsWellFormedUriString(s3Url, UriKind.Absolute))
        {
            throw new ArgumentException("S3 URL must be a valid S3 URI or absolute URI.", nameof(s3Url));
        }
        
        string imageId = Guid.NewGuid().ToString();
        DateTime uploadDate = timeProvider.GetUtcNow().UtcDateTime;
        
        return new ImageMetadata(imageId, sanitizedFileName, sizeInBytes, s3Url, uploadDate);
    }

    public static ImageMetadata Rehydrate(string imageId, string fileName, long sizeInBytes, string s3Url, DateTime uploadDate)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(imageId);
        ArgumentException.ThrowIfNullOrWhiteSpace(fileName);
        ArgumentException.ThrowIfNullOrWhiteSpace(s3Url);

        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(sizeInBytes);
        
        string sanitizedFileName = Path.GetFileName(fileName.Trim());
        ArgumentException.ThrowIfNullOrWhiteSpace(sanitizedFileName, nameof(fileName));
        
        return new ImageMetadata(imageId, sanitizedFileName, sizeInBytes, s3Url, uploadDate);
    }
}
