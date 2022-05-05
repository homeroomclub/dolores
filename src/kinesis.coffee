import * as Kinesis from "@aws-sdk/client-kinesis"
import { lift, partition } from "./helpers"

cache =
  account: null

AWS =
  Kinesis: lift Kinesis
  STS: lift STS

region = "us-east-1"

rescueNotFound = (error) ->
  code = error?.$response?.statusCode ? error.$metadata.httpStatusCode
  if ! ( code in [ 403, 404 ] )
    throw error

getStreamARN = (name) ->
  account = await do ->
    cache.account ?= ( await AWS.STS.getCallerIdentity() ).Account
  "arn:aws:kinesis:#{region}:#{account}:stream/#{name}"

getStream = (name) ->
  try
    { StreamDescriptionSummary: _ } = 
      await AWS.Kinesis.describeStreamSummary StreamName: name
    _: _
    arn: _.StreamARN
    status: _.StreamStatus
  catch error
    console.log error
    null

hasStream = (name) ->
  if ( await getStream name )?
    true
  else
    false

putStream = (name) ->
  if !( await hasStream name )
    await AWS.Kinesis.createStream 
      StreamName: name
      StreamModeDetails: "ON_DEMAND"

deleteStream = (name) ->
  if await hasStream name
    await AWS.Kinesis.deleteStream StreamName: name

addRecord = (name) ->
  await AWS.Kinesis.putRecordInput 
    StreamName: name


export {
  getStreamARN
  getStream
  hasStream
  putStream
  deleteStream
}