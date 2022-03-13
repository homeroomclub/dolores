import * as SQS from "@aws-sdk/client-sqs"
import * as STS from "@aws-sdk/client-sts"
import * as Obj from "@dashkite/joy/object"
import * as Type from "@dashkite/joy/type"
import { lift } from "./helpers"

createStepFunction = ({ name, dictionary, resources, description }) ->
  

AWS =
  SQS: lift SQS
  STS: lift STS

region = "us-east-1"

getQueueARN = (name) ->
  account = ( await AWS.STS.getCallerIdentity() ).Account
  "arn:aws:sqs:#{region}:#{account}:#{name}.fifo"

_createQueue = (name, options) ->
  AWS.SQS.createQueue
    QueueName: name
    Attributes: options

# Dolores will be opinionated and always assume a FIFO queue.
createQueue = (name, options = {}) ->
  name = "#{name}.fifo"
  defaults = 
    FifoQueue: true
    ReceiveMessageWaitTimeSeconds: 20
    ContentBasedDeduplication: true

  _createQueue name, Obj.merge defaults, options

# Dolores will be opinionated and always assume a FIFO queue.
getQueueURL = (name) ->
  name = "#{name}.fifo"
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
putQueue = (name, options) ->
  if !( await getQueueURL name )?
    console.log "creating..."
    await createQueue name, options
  else
    console.log "queue already exists"
    console.log await getQueueURL name

# AWS indicates this can take 60 seconds to complete.
emptyQueue = (name) ->
  if ( url = await getQueueURL name )?
    await AWS.SQS.purgeQueue QueueUrl: url

# AWS indicates this can take 60 seconds to complete.
deleteQueue = (name) ->
  if ( url = await getQueueURL name )?
    await AWS.SQS.deleteQueue QueueUrl: url

pushMessage = (name, message, options) ->
  if !(Type.isString message) || ( message.length == 0 )
    throw new Error "dolores:queue: message must be a string with
      minimum length 1."

  defaults =
    MessageGroupId: "DefaultMessageGroupID"

  if ( url = await getQueueURL name )?
    await AWS.SQS.sendMessage Obj.merge defaults, options,
      MessageBody: message
      QueueUrl: url
  else
    throw new Error "dolores:queue: the queue #{name} is not available"

_receieveMessages = (url, options) ->
  defaults = 
    AttributeNames: [ "All" ]
    MessageAttributeNames: [ "All" ]

  { Messages } = await AWS.SQS.receiveMessage Obj.merge defaults, options,
    QueueUrl: url

  Messages

_deleteMessage = (url, handle) ->
  AWS.SQS.deleteMessage
    QueueUrl: url
    ReceiptHandle: handle

_deleteMessages = (url, handles) ->
  AWS.SQS.deleteMessageBatch
    QueueUrl: url
    Entries: do ->
      for handle, index in handles
        Id: "#{index}"
        ReceiptHandle: handle

popMessages = (name, options) ->
  if ( url = await getQueueURL name )?
    _messages = await _receieveMessages url, options
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
    throw new Error "dolores:queue: the queue #{name} is not available"

# TODO: handle the batch versions of these operations...

export {
  _createQueue
  getQueueARN
  createQueue
  getQueueURL
  putQueue
  emptyQueue
  deleteQueue
  pushMessage
  popMessages
}




