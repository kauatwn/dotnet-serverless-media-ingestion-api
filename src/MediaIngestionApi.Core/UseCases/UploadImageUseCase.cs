using MediaIngestionApi.Core.Entities;
using MediaIngestionApi.Core.Interfaces;
using Microsoft.Extensions.Logging;

namespace MediaIngestionApi.Core.UseCases;

public sealed partial class UploadImageUseCase(IStorageService storage, IMetadataRepository repository, ILogger<UploadImageUseCase> logger, TimeProvider? timeProvider = null)
{
    private static readonly HashSet<string> AllowedContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "image/jpeg",
        "image/png",
        "image/webp",
        "image/gif",
        "image/bmp",
        "image/tiff",
        "image/svg+xml"
    };

    public async Task<ImageMetadata> ExecuteAsync(string base64Image, string fileName, string contentType, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(base64Image);
        ArgumentException.ThrowIfNullOrWhiteSpace(fileName);
        ArgumentException.ThrowIfNullOrWhiteSpace(contentType);

        string sanitizedFileName = Path.GetFileName(fileName.Trim());
        ArgumentException.ThrowIfNullOrWhiteSpace(sanitizedFileName, nameof(fileName));

        if (!AllowedContentTypes.Contains(contentType.Trim()))
        {
            throw new ArgumentException($"Unsupported content type: '{contentType}'.", nameof(contentType));
        }

        byte[] imageBytes;
        try
        {
            imageBytes = Convert.FromBase64String(base64Image);
        }
        catch (FormatException ex)
        {
            LogInvalidBase64(logger, sanitizedFileName);
            throw new ArgumentException("Invalid Base64 image payload.", nameof(base64Image), ex);
        }

        ArgumentOutOfRangeException.ThrowIfZero(imageBytes.Length, nameof(base64Image));
        ArgumentOutOfRangeException.ThrowIfGreaterThan(imageBytes.Length, ImageMetadata.MaxSizeBytes, nameof(base64Image));

        try
        {
            LogUploadProcessStarted(logger, sanitizedFileName);

            string s3Url = await storage.UploadImageAsync(imageBytes, sanitizedFileName, contentType.Trim(), cancellationToken);
            ImageMetadata metadata = ImageMetadata.Create(sanitizedFileName, imageBytes.Length, s3Url, timeProvider ?? TimeProvider.System);

            try
            {
                await repository.SaveMetadataAsync(metadata, cancellationToken);
                LogMetadataPersisted(logger, metadata.ImageId, sanitizedFileName);
                return metadata;
            }
            catch (Exception ex)
            {
                LogPersistenceFailedTriggeringRollback(logger, s3Url, sanitizedFileName, ex.Message);
                try
                {
                    await storage.DeleteImageAsync(s3Url, cancellationToken);
                    LogRollbackCompleted(logger, s3Url);
                }
                catch (Exception rollbackEx)
                {
                    LogRollbackFailed(logger, s3Url, rollbackEx.Message, rollbackEx);
                }

                throw;
            }
        }
        catch (Exception ex)
        {
            LogUploadProcessFailed(logger, ex, sanitizedFileName);
            throw;
        }
    }

    [LoggerMessage(Level = LogLevel.Information, Message = "Initiating image upload process for file: {FileName}.")]
    static partial void LogUploadProcessStarted(ILogger<UploadImageUseCase> logger, string fileName);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Failed to parse Base64 data for file: {FileName}.")]
    static partial void LogInvalidBase64(ILogger<UploadImageUseCase> logger, string fileName);

    [LoggerMessage(Level = LogLevel.Information, Message = "Metadata {ImageId} successfully persisted for file {FileName}.")]
    static partial void LogMetadataPersisted(ILogger<UploadImageUseCase> logger, string imageId, string fileName);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Failed to persist metadata for file {FileName}. Triggering compensatory rollback on S3 object {S3Url}. Error: {ErrorMessage}")]
    static partial void LogPersistenceFailedTriggeringRollback(ILogger<UploadImageUseCase> logger, string s3Url, string fileName, string errorMessage);

    [LoggerMessage(Level = LogLevel.Information, Message = "Compensatory rollback succeeded. Deleted S3 object: {S3Url}.")]
    static partial void LogRollbackCompleted(ILogger<UploadImageUseCase> logger, string s3Url);

    [LoggerMessage(Level = LogLevel.Error, Message = "Compensatory rollback failed for S3 object {S3Url}. Error: {ErrorMessage}")]
    static partial void LogRollbackFailed(ILogger<UploadImageUseCase> logger, string s3Url, string errorMessage, Exception ex);

    [LoggerMessage(Level = LogLevel.Error, Message = "Critical error during image upload process for file {FileName}.")]
    static partial void LogUploadProcessFailed(ILogger<UploadImageUseCase> logger, Exception ex, string fileName);
}