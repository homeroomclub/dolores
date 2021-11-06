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

# TODO maybe promote this to library status
_getSecret = (name) ->
  secrets[name] ?= await manager.getSecretValue SecretId: name

getSecret = (name) ->
  { SecretString } = await _getSecret name
  JSON.parse SecretString

getSecretARN = (name) ->
  { ARN } = await _getSecret name
  ARN

setSecret = (name, value) ->
  value = JSON.stringify value
  if await hasSecret name
    await manager.updateSecret SecretId: name, SecretString: value
  else
    await manager.createSecret Name: name, SecretString: value
  secrets[name] = value

export {
  hasSecret
  getSecret
  getSecretARN
  setSecret
}