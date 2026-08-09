using MediaIngestionApi.Core.Models;

namespace MediaIngestionApi.Core.Interfaces;

public interface IMetadataRepository
{
    Task SaveMetadataAsync(ImageMetadata metadata);
}