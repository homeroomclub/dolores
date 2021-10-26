import { Lambda } from "@aws-sdk/client-lambda"
import { S3 } from "@aws-sdk/client-s3"

lambdaClient = new Lambda region: "us-east-1"
s3Client = new S3 region: "us-east-1"

md5 = (buffer) ->
  Crypto.createHash('md5').update(buffer).digest("base64")

hasLambda = (name) ->
  try
    await lambdaClient.getFunction FunctionName: name
    true
  catch error
    if /ResourceNotFoundException/.test error.toString()
      false
    else
      throw error

# TODO add function for creating bucket and then check for bucket
# existance before uploading...

# TODO make bucket name configurable

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

  await s3Client.putObject
    Bucket: bucket
    Key: name
    ContentType: "application/zip"
    ContentMD5: md5 data
    Body: data

  if await hasLambda name

    await lambdaClient.updateFunctionCode
      FunctionName: name
      Publish: false
      S3Bucket: bucket
      S3Key: name
  
    await lambdaClient.updateFunctionConfiguration _configuration

  else

    await lambdaClient.createFunction
      _configuration...
      Code:
        S3Bucket: bucket
        S3Key: name

versionLambda = (name) ->
  await context.aws.Lambda.publishVersion
    FunctionName: name

export {
  hasLambda
  publishLambda
  versionLambda
}
