using MediaIngestionApi.Core.Entities;

namespace MediaIngestionApi.Core.Interfaces;

public interface IMetadataRepository
{
    Task SaveMetadataAsync(ImageMetadata metadata, CancellationToken cancellationToken = default);
}