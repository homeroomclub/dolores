import { SecretsManager } from "@aws-sdk/client-secrets-manager"

manager = new SecretsManager region: "us-east-1"
secrets = {}

hasSecret = (name) ->
  try
    await manager.describeSecret SecretId: name
    true
  catch error
    if /ResourceNotFoundException/.test error.toString()
      false
    else
      throw error

# TODO replace this primitive expiry mechanism with a means to message lambdas?
# and/or we can use worker message queues...
_getSecret = (name) ->
  if !( secret = secrets[name] )? || ( Date.now() > secret.expires )
    secret =
      value: await manager.getSecretValue SecretId: name
      expires: Date.now() + 60000
    secrets[ name ] = secret
  secret.value

getSecret = (name) ->
  { SecretString } = await _getSecret name
  SecretString

getSecretARN = (name) ->
  { ARN } = await _getSecret name
  ARN

getSecretReference = (name) ->
  { VersionId } = await _getSecret name
  "{{resolve:secretsmanager:#{name}:SecretString:::#{VersionId}}}"

setSecret = (name, value) ->
  if await hasSecret name
    await manager.updateSecret SecretId: name, SecretString: value
  else
    await manager.createSecret Name: name, SecretString: value
  secrets[name] = value

export {
  hasSecret
  getSecret
  getSecretARN
  getSecretReference
  setSecret
}