namespace MediaIngestionApi.Core.Interfaces;

public interface IStorageService
{
    Task<string> UploadImageAsync(byte[] imageBytes, string fileName, string contentType, CancellationToken cancellationToken = default);
    Task DeleteImageAsync(string s3Url, CancellationToken cancellationToken = default);
}