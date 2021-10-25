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
getSecret = (name) ->
  secrets[name] ?= await do ->
    { SecretString } = await manager.getSecretValue SecretId: name
    JSON.parse SecretString

export {
  hasSecret
  getSecret
}