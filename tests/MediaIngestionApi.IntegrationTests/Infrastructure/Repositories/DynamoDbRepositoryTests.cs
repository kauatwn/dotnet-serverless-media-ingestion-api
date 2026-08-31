using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.Model;
using MediaIngestionApi.Core.Entities;
using MediaIngestionApi.Infrastructure.Repositories;
using MediaIngestionApi.IntegrationTests.Abstractions;

namespace MediaIngestionApi.IntegrationTests.Infrastructure.Repositories;

[Collection(nameof(IntegrationTestCollection))]
public class DynamoDbRepositoryTests
{
    private readonly AmazonDynamoDBClient _dynamoClient;

    private readonly DynamoDbRepository _sut;

    public DynamoDbRepositoryTests(IntegrationTestFixture fixture)
    {
        // Creates the client pointing to the LocalStack Docker container
        _dynamoClient = new AmazonDynamoDBClient(new AmazonDynamoDBConfig
        {
            ServiceURL = fixture.LocalStack.GetConnectionString()
        });

        _sut = new DynamoDbRepository(_dynamoClient);
    }

    [Fact(DisplayName = "SaveMetadataAsync should persist the item correctly in the DynamoDB table")]
    public async Task SaveMetadataAsync_ShouldPersistItem()
    {
        // Arrange
        ImageMetadata metadata = ImageMetadata.Create(
            fileName: "test-image.jpg",
            sizeInBytes: 1024L,
            s3Url: "https://s3.amazonaws.com/bucket/test-image.jpg",
            timeProvider: TimeProvider.System
        );

        // Act
        await _sut.SaveMetadataAsync(metadata, TestContext.Current.CancellationToken);

        // Assert
        GetItemRequest request = new()
        {
            TableName = IntegrationTestFixture.TargetTableName,
            Key = new Dictionary<string, AttributeValue>
            {
                { "imageId", new AttributeValue { S = metadata.ImageId } }
            }
        };

        GetItemResponse? response = await _dynamoClient.GetItemAsync(request, TestContext.Current.CancellationToken);

        Assert.True(response.IsItemSet);
        Assert.Equal(metadata.FileName, response.Item["fileName"].S);
        Assert.Equal(metadata.S3Url, response.Item["s3Url"].S);
    }
}