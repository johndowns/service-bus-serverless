# Service Bus and serverless sample

This sample illustrates one approach to work with a Service Bus-based messaging system using Azure Functions.

Requirements:
* Use serverless technologies.
* Store a copy of all messages into an immutable storage account.
* Route all unprocessable (dead-lettered) messages to a single queue, and lg them to a Cosmos DB database for later analysis.

## Deployment and testing

To deploy this sample, deploy the `main.bicep` file into an empty resource group. By default, the sample deploys a Service Bus namespace using the Standard SKU, as well as two LRS storage accounts and a set of Azure Functions using the Consumption SKU.

Once the sample is deployed, you can test it by sending a POST request to one of the **Sender** functions. Specify the `?count=` query string parameter to send the message multiple times for ease of testing. You can then inspect the firehose blob container and the dead-letter Cosmos DB container to see how the messages are routed and saved.

## Architecture

This sample includes a number of components that are deployed and configured. To simplify the explanation, this section splits the functionality of the sample into three layers: the core processing layer, firehose logging, and dead-letter processing.

### Processing

The processing layer enables the core functionality of the application. The **Sender** function as as the client, sending messages into either Service Bus topic using an [Service Bus output binding](https://docs.microsoft.com/azure/azure-functions/functions-bindings-service-bus). There is a subscription on each topic called `process`. Each topic subscription is consumed by a function with a [Service Bus trigger](https://docs.microsoft.com/azure/azure-functions/functions-bindings-service-bus-trigger). For simplicity, the processing logic for both topic subscriptions is the same - but in a real application you would use your own business logic to process each type of message.

The following diagram illustrates the components included in the core processing layer of the sample, with green arrows showing the data flow direction:

![Architecture diagram showing sender function app, Service Bus namespace with topics for new-order and new-customer, and functions to process messages from each topic.](docs/images/architecture-processing.png)

### Firehose logging

One of our requirements is to log all messages that have passed through the Service Bus topics for later auditing. The sample shows how [immutable blob storage](https://docs.microsoft.com/azure/storage/blobs/storage-blob-immutable-storage) can be configured and used for this purpose.

The Bicep code that deploys the Service Bus resources deploys a subscription on each topic named `firehose`. This will receive a copy of all messages sent to that topic. Each of the `firehose` subscriptions are configured to [forward their messages](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-auto-forwarding) to a central queue, also named `firehose`. This architecture allows for more topics to be easily added, without having to provision new functions to process each topic's messages. [Subscription filter rule actions](https://docs.microsoft.com/azure/service-bus-messaging/topic-filters#actions) are used to automatically include a metadata field named `OriginalTopicName` on each message with the name of the topic that received the message.

The **ProcessFirehoseQueueMessage** function listens to the `firehose` queue, again using the Service Bus trigger. When a message is received, it writes it to the blob container within a date-based folder hierarchy. Azure Storage has an immutability policy configured, which will disallow anyone from modifying or deleting the blobs during the retention period. This sample configures a retention period of 365 days.

The following diagram illustrates the components included in the firehose layer of the sample, with blue arrows showing how messages are routed through to the firehose storage account.

![Architecture diagram with additional firehose queue, and each topic connected to the queue.](docs/images/architecture-firehose.png)

### Dead-letter processing

It's common to need to have centralised processing of dead-lettered messages. These often need to be logged and inspected by a human.

Service Bus has a built-in feature to forward dead-lettered messages from topic subscriptions to a queue. The sample uses this to forward any dead-lettered messages in the `process` subscriptions to a central queue named `deadletter-firehose`.

The **ProcessDeadLetterFirehoseQueueMessage** function listens to the `deadletter-firehose` queue and writes the data to a Cosmos DB container, which will make it easy to query and handle the messages (although doing so is out of the scope of this sample).

To simulate real dead-lettered messages for illustration processes, the processing functions randomly select some messages to dead-letter. The sample configures the dead-lettering behaviour of Service Bus so that a failed message will not be re-processed (i.e. it sets the `maxDeliveryCount` to `1`). For most real-world applications, you would want to leave this at the default of 10 attempts.

The following diagram illustrates the components included in the dead-lettering layer of the sample, with red arrows showing how messages are routed through to the Cosmos DB container.

![Architecture diagram with additional dead-letter queue, and each processing topic subscription connected to the queue.](docs/images/architecture-dead-letter.png)

## Other notes

* This sample is **NOT** usable for production deployments, and is for demonstration purposes only. Do not copy and paste the code without understanding what it is and does.
* In order to make the sample easy to deploy, the source code for each function is deployed inline from the Bicep templates. This is not a good practice for production deployments.
