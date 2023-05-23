import YAML from "js-yaml"
import * as SQS from "@aws-sdk/client-sqs"
import * as STS from "@aws-sdk/client-sts"
import * as Obj from "@dashkite/joy/object"
import * as Type from "@dashkite/joy/type"
import * as Text from "@dashkite/joy/text"
import { lift } from "./helpers"
import * as Stack from "./stack"


cache =
  account: null

AWS =
  SQS: lift SQS
  STS: lift STS

region = "us-east-1"

nameStack = ( name ) -> "#{ Text.dashed name }-queue"

getQueueARN = ( name ) ->
  account = await do ->
    cache.account ?= ( await AWS.STS.getCallerIdentity() ).Account
  "arn:aws:sqs:#{region}:#{account}:#{name}"

getQueueURL = ( name ) ->
  try
    { QueueUrl } = await AWS.SQS.getQueueUrl QueueName: name
    QueueUrl
  catch error
    if /AWS\.SimpleQueueService\.NonExistentQueue/.test error.toString()
      null
    else
      throw error

# For now, this will be idempotent. Some aspects of queues cannot be updated
#   and require a delete-create cycle (~60s) to perform an effective update.
putQueue = ( name, options ) ->
  defaults =
    QueueName: name
    MessageRetentionPeriod: 345600  # 4 days
    ReceiveMessageWaitTimeSeconds: 20

  # These settings give us high-throughput FIFO by default
  if name.endsWith ".fifo"
    defaults.FifoQueue = true
    defaults.ContentBasedDeduplication = true
    defaults.DeduplicationScope = "messageGroup"
    defaults.FifoThroughputLimit = "perMessageGroupId"

  _template =
    AWSTemplateFormatVersion: "2010-09-09"
    Description: "Specify Queue [ #{name} ]"
    Resources:
      Queue:
        Type: "AWS::SQS::Queue"
        Properties: Obj.merge defaults, options

  await Stack.deployStack ( nameStack name ), YAML.dump _template
  undefined
  

# AWS indicates this can take 60 seconds to complete.
emptyQueue = ( name ) ->
  if ( url = await getQueueURL name )?
    await AWS.SQS.purgeQueue QueueUrl: url

# AWS indicates this can take 60 seconds to complete.
deleteQueue = ( name ) ->
  await Stack.deleteStack nameStack name
  undefined

pushMessage = ( name, message, options ) ->
  if !message?
    throw new Error "dolores:queue cannot push undefined message"
  
  if (Type.isString message) && (message.length == 0)
    throw new Error "dolores:queue message strings must have a minium length 1"

  if Type.isObject message
    message = JSON.stringify message

  if !(Type.isString message)
    throw new Error "dolores:queue unable to queue unknown message type"

  if name.endsWith ".fifo"
    defaults =
      MessageGroupId: "DefaultMessageGroupID"
  else
    defaults = {}

  if ( url = await getQueueURL name )?
    await AWS.SQS.sendMessage Obj.merge defaults, options,
      MessageBody: message
      QueueUrl: url
  else
    throw new Error "dolores:queue: the queue #{name} is not available"

_receiveMessages = ( url, options ) ->
  defaults = 
    AttributeNames: [ "All" ]
    MessageAttributeNames: [ "All" ]

  { Messages } = await AWS.SQS.receiveMessage Obj.merge defaults, options,
    QueueUrl: url

  Messages

_deleteMessage = ( url, handle ) ->
  AWS.SQS.deleteMessage
    QueueUrl: url
    ReceiptHandle: handle

_deleteMessages = ( url, handles ) ->
  AWS.SQS.deleteMessageBatch
    QueueUrl: url
    Entries: do ->
      for handle, index in handles
        Id: "#{index}"
        ReceiptHandle: handle

popMessages = ( name, options ) ->
  if ( url = await getQueueURL name )?
    _messages = await _receiveMessages url, options
    _messages ?= []
    handles = []
    messages = []
    
    for { ReceiptHandle, Body } in _messages
      handles.push ReceiptHandle
      messages.push Body
    
    if handles.length > 0
      await _deleteMessages url, handles
    
    messages

  else
    throw new Error "dolores:queue: the queue #{ name } is not available"


receiveMessages = ( name, options ) ->
  if ( url = await getQueueURL name )?
    defaults = 
      AttributeNames: [ "All" ]
      MessageAttributeNames: [ "All" ]

    { Messages } = await AWS.SQS.receiveMessage Obj.merge defaults, options,
      QueueUrl: url

    Messages

  else
    throw new Error "dolores:queue: the queue #{ name } is not available"



# TODO: handle the batch versions of these operations...

export {
  getQueueARN
  getQueueURL
  putQueue
  emptyQueue
  deleteQueue
  pushMessage
  popMessages
  receiveMessages
}