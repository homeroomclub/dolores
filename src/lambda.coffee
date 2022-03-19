import Crypto from "crypto"
import * as Lambda from "@aws-sdk/client-lambda"
import * as S3 from "@aws-sdk/client-s3"
import * as Text from "@dashkite/joy/text"
import * as Time from "@dashkite/joy/time"
import { lift } from "./helpers"

AWS =
  Lambda: lift Lambda
  S3: lift S3

md5 = (buffer) ->
  Crypto.createHash('md5').update(buffer).digest("base64")

hasLambda = (name) -> (await getLambda name)?

getLambda = (name) ->
  try
    lambda = await AWS.Lambda.getFunction FunctionName: name
    _: lambda
    arn: lambda.Configuration.FunctionArn
    state: lambda.Configuration.State
    lastStatus: lambda.Configuration.LastUpdateStatus
  catch error
    if /ResourceNotFoundException/.test error.toString()
      undefined
    else
      throw error

# AWS added internal state management to Lambda in an effort to improve the performance
# of the invocation cycle. This is a broad helper to wait until the lambda is ready
# to go and accept more changes to its state.
waitForReady = (name) ->
  loop
    { state, lastStatus } = await getLambda name
    if ( state == "Active" ) && ( lastStatus == "Successful" )
      break
    else if state == "Failed"
      throw new Error "Lambda [ #{name} ] State is Failed."
    else if lastStatus == "Failed"
      throw new Error "Lambda [ #{name} ] LastUpdateStatus is Failed."
    else
      await Time.sleep 1000

getLambdaVersion = (name, version) ->
  { Versions }  = await AWS.Lambda.listVersionsByFunction FunctionName: name
  for current in Versions
    if version == Text.parseNumber current.Version
      return
        _: current
        arn: current.FunctionArn
        version: Text.parseNumber currentVersion
  undefined

getLatestLambda = (name) ->
  { Versions }  = await AWS.Lambda.listVersionsByFunction FunctionName: name
  result = undefined
  max = 0
  for current in Versions
    if current.Version != "$LATEST"
      version = Text.parseNumber current.Version
      if version >= max
        max = version
        result = current
    else
      result = current
  if result?
    _: result
    arn: result.FunctionArn
    version: max

getLatestLambdaARN = (name) -> ( await getLatestLambda name ).arn
getLambdaARN = getLatestLambdaARN

defaults =
  bucket: "dolores.dashkite.com"
  role: "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  memory: 128 # max size for edge lambdas
  timeout: 5 # max timeout for edge lambdas
  handler: "build/lambda/index.handler"
  runtime: "nodejs14.x"

publishLambda = (name, data, configuration) ->

  { 
    role
    handler
    runtime
    bucket
    memory
    timeout
    environment
  } = { defaults..., configuration... }

  _configuration =
    FunctionName: name
    Handler: handler
    Runtime: runtime
    MemorySize: memory
    Timeout: timeout
    TracingConfig: Mode: "PassThrough"
    Role: role

  # if environment?
  #   _configuration.Environment = Variables: environment

  if await hasLambda name

    await AWS.Lambda.updateFunctionCode
      FunctionName: name
      Publish: false
      ZipFile: data

    await waitForReady name
    
    await AWS.Lambda.updateFunctionConfiguration _configuration

    waitForReady name

  else

    await AWS.Lambda.createFunction {
      _configuration...
      Code: ZipFile: data
    }

    waitForReady name

versionLambda = (name) ->
  result = await AWS.Lambda.publishVersion FunctionName: name
  _: result
  arn: result.FunctionArn
  version: Text.parseNumber result.Version

deleteLambda = (name) ->
  AWS.Lambda.deleteFunction FunctionName: name

_invokeLambda = (name, sync, input) ->
  parameters = if input?
    FunctionName: name
    Payload: JSON.stringify input
    InvocationType: if sync then "RequestResponse" else "Event"
  else
    FunctionName: name
    InvocationType: if sync then "RequestResponse" else "Event"

  AWS.Lambda.invoke parameters

invokeLambda = (name, input) -> _invokeLambda name, false, input
syncInvokeLambda = (name, input) -> _invokeLambda name, true, input

export {
  hasLambda
  getLambda
  waitForReady
  getLambdaVersion
  getLatestLambda
  getLatestLambdaARN
  getLambdaARN
  publishLambda
  versionLambda
  deleteLambda
  invokeLambda
  syncInvokeLambda
}
