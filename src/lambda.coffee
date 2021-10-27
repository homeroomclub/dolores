import Crypto from "crypto"
import { Lambda } from "@aws-sdk/client-lambda"
import { S3 } from "@aws-sdk/client-s3"
import * as Text from "@dashkite/joy/text"

AWS =
  Lambda: new Lambda region: "us-east-1"
  S3: new S3 region: "us-east-1"

md5 = (buffer) ->
  Crypto.createHash('md5').update(buffer).digest("base64")

hasLambda = (name) -> (await getLambda name)?

getLambda = (name) ->
  try
    await AWS.Lambda.getFunction FunctionName: name
  catch error
    if /ResourceNotFoundException/.test error.toString()
      undefined
    else
      throw error

getLambdaVersion = (name, version) ->
  { Versions }  = await AWS.Lambda.listVersionsByFunction FunctionName: name
  for version in Versions
    if version == Text.parseNumber version.Version
      return version
  undefined

# TODO add function for creating bucket and then check for bucket
# existance before uploading...

defaults =
  bucket: "dolores.dashkite.com"
  role: "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  memory: 3000
  timeout: 30
  handler: "index.handler"
  runtime: "nodejs14.x"

publishLambda = (name, data, configuration) ->

  { 
    role
    handler
    runtime
    bucket
    memory
    timeout
  } = { defaults..., configuration... }

  _configuration =
    FunctionName: name
    Handler: handler
    Runtime: runtime
    MemorySize: memory
    Timeout: timeout
    TracingConfig: Mode: "PassThrough"
    Role: role

  await AWS.S3.putObject
    Bucket: bucket
    Key: name
    ContentType: "application/zip"
    ContentMD5: md5 data
    Body: data

  if await hasLambda name

    await AWS.Lambda.updateFunctionCode
      FunctionName: name
      Publish: false
      S3Bucket: bucket
      S3Key: name
  
    AWS.Lambda.updateFunctionConfiguration _configuration

  else

    AWS.Lambda.createFunction {
      _configuration...
      Code:
        S3Bucket: bucket
        S3Key: name
    }

versionLambda = (name) ->
  { Version } = await AWS.Lambda.publishVersion FunctionName: name
  Version

export {
  hasLambda
  publishLambda
  versionLambda
}
