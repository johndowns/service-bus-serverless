# Service Bus and serverless sample

This sample illustrates one approach to work with a Service Bus-based messaging system using Azure Functions.

Requirements:
* Use serverless technologies.
* Store a copy of all messages into an immutable storage account.
* Route all unprocessable (dead-lettered) messages to a single queue, and lg them to a Cosmos DB database for later analysis.

## Processing

![Architecture diagram showing sender function app, Service Bus namespace with topics for new-order and new-customer, and functions to process messages from each topic.](docs/images/architecture-processing.png)

## Firehose logging

![Architecture diagram with additional firehose queue, and each topic connected to the queue.](docs/images/architecture-firehose.png)

## Dead-letter processing

![Architecture diagram with additional dead-letter queue, and each processing topic subscription connected to the queue.](docs/images/architecture-dead-letter.png)
