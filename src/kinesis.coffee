import * as Kinesis from "@aws-sdk/client-kinesis"
import * as STS from "@aws-sdk/client-sts"
import { lift, partition } from "./helpers"

cache =
  account: null

AWS =
  Kinesis: lift Kinesis
  STS: lift STS

region = "us-east-1"

getStreamARN = (stream) ->
  account = await do ->
    cache.account ?= ( await AWS.STS.getCallerIdentity() ).Account
  "arn:aws:kinesis:#{region}:#{account}:stream/#{stream}"

getStream = (stream) ->
  try
    { StreamDescriptionSummary: _ } = 
      await AWS.Kinesis.describeStreamSummary StreamName: stream
    _: _
    arn: _.StreamARN
    status: _.StreamStatus
  catch error
    if /ResourceNotFoundException/.test error.toString()
      undefined
    else
      throw error

hasStream = (stream) ->
  if ( await getStream stream )?
    true
  else
    false

putStream = (stream) ->
  if !( await hasStream stream )
    await AWS.Kinesis.createStream 
      StreamName: stream
      StreamModeDetails: 
        StreamMode: "ON_DEMAND"

deleteStream = (stream) ->
  if await hasStream stream
    await AWS.Kinesis.deleteStream StreamName: stream

addRecord = ({ stream, partition, data }) ->
  await AWS.Kinesis.putRecord 
    StreamName: stream
    PartitionKey: partition
    Data: Buffer.from ( JSON.stringify data ), "utf8"

listConsumers = (stream) ->
  results = []
  next = undefined
  while true
    { Consumers, NextToken } = await AWS.Kinesis.listStreamConsumers
      StreamARN: stream.arn
      NextToken: next

    next = NextToken
    results.push Consumers...
    if !next?
      return results

export {
  getStreamARN
  getStream
  hasStream
  putStream
  deleteStream
  addRecord
  listConsumers
}