using Amazon.S3;
using Amazon.S3.Model;
using Amazon.S3.Util;
using MediaIngestionApi.Core.Interfaces;

namespace MediaIngestionApi.Infrastructure.Storage;

public sealed class S3StorageService(IAmazonS3 s3Client) : IStorageService
{
    private readonly string _bucketName = Environment.GetEnvironmentVariable("BUCKET_NAME") ??
        throw new InvalidOperationException("The 'BUCKET_NAME' environment variable is not configured.");

    public async Task<string> UploadImageAsync(byte[] imageBytes, string fileName, string contentType, CancellationToken cancellationToken = default)
    {
        string uniqueFileName = $"{Guid.NewGuid()}-{fileName}";
        using MemoryStream memoryStream = new(imageBytes);

        PutObjectRequest request = new()
        {
            BucketName = _bucketName,
            Key = uniqueFileName,
            InputStream = memoryStream,
            ContentType = contentType
        };

        await s3Client.PutObjectAsync(request, cancellationToken);

        return $"s3://{_bucketName}/{uniqueFileName}";
    }

    public async Task DeleteImageAsync(string s3Url, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(s3Url);

        string key = ExtractKey(s3Url);
        DeleteObjectRequest request = new()
        {
            BucketName = _bucketName,
            Key = key
        };

        await s3Client.DeleteObjectAsync(request, cancellationToken);
    }

    private static string ExtractKey(string s3Url)
    {
        if (AmazonS3Uri.TryParseAmazonS3Uri(s3Url, out AmazonS3Uri? parsedUri))
        {
            return parsedUri.Key;
        }

        if (Uri.TryCreate(s3Url, UriKind.Absolute, out Uri? uri))
        {
            return uri.AbsolutePath.TrimStart('/');
        }

        return s3Url.Trim();
    }
}