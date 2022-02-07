import { SecretsManager } from "@aws-sdk/client-secrets-manager"

manager = new SecretsManager region: "us-east-1"
secrets = {}

parseSecretName = (name) ->
  return [] if !name?
  name.split "/"

hasSecret = (_name) ->
  [ name ] = parseSecretName _name

  try
    await manager.describeSecret SecretId: name
    true
  catch error
    if /ResourceNotFoundException/.test error.toString()
      false
    else
      throw error

__getSecret = (_name) ->
  [ name, subName ] = parseSecretName _name
  secret = await manager.getSecretValue SecretId: name
  if subName? 
    secret = { secret... }
    try
      bundle = JSON.parse secret.SecretString
    catch _error
      error = new Error "Unable to parse JSON for secrets bundle [ #{name} ],
        using reference [ #{_name} ]"
      error._error = _error
      throw error
    secret.SecretString = bundle?[subName]
  secret

# TODO replace this primitive expiry mechanism with a means to message lambdas?
# and/or we can use worker message queues...
_getSecret = (name) ->
  if !( secret = secrets[name] )? || ( Date.now() > secret.expires )
    secret =
      value: await __getSecret name
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

_updateSecret = (_name, _value) ->
  [ name, subName ] = parseSecretName _name
  if subName?
    value = JSON.parse await getSecret name
    value[ subName ] = _value
    value = JSON.stringify value
    await manager.updateSecret SecretId: name, SecretString: value
  else
    await manager.updateSecret SecretId: name, SecretString: _value

_createSecret = (_name, _value) ->
  [ name, subName ] = parseSecretName _name
  if subName?
    value = JSON.stringify [ subName ]: _value
    await manager.createSecret Name: name, SecretString: value
  else
    await manager.createSecret Name: name, SecretString: _value

setSecret = (name, value) ->
  if await hasSecret name
    _value = await _updateSecret name, value
  else
    _value = await _createSecret name, value
  
  secrets[name] = 
    value: _value
    expires: Date.now() + 60000

_deleteSecret = (_name) ->
  [ name, subName ] = parseSecretName _name
  if subName?
    value = JSON.parse await getSecret name
    delete value[ subName ]
    value = JSON.stringify value
    await setSecret name, value
  else
    await manager.deleteSecret
      SecretId: name
      ForceDeleteWithoutRecovery: true

deleteSecret = (name) ->
  await _deleteSecret name
  delete secrets[ name ]

export {
  parseSecretName
  hasSecret
  getSecret
  getSecretARN
  getSecretReference
  setSecret
  deleteSecret
}