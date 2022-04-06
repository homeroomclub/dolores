import { CloudFormation } from "@aws-sdk/client-cloudformation"
import * as Time from "@dashkite/joy/time"
import { runNetwork } from "./helpers"

AWS =
  CloudFormation: new CloudFormation region: "us-east-1"

hasStack = (name) -> (await getStack name)?

getStack = (name) ->
  try
    { Stacks } = await AWS.CloudFormation.describeStacks StackName: name
    # TODO is there anything else to return here?
    status: Stacks[0]?.StackStatus
    _: Stacks[0]
  catch
    undefined

getStatus = (context) ->
  context.stack = await getStack context.name
  context.stack?.status ? "create"

nodes = [

    pattern: "start"
    next: getStatus
    nodes: [
        pattern: /UPDATE_ROLLBACK_(COMPLETE|FAILED)$/
        next: -> "update"
      ,
        pattern: /ROLLBACK_(COMPLETE|FAILED)$/
        next: -> "delete"
      ,
        pattern: /COMPLETE$/
        next: -> "update"
    ]
  ,
    pattern: "create"
    action: ({ template }) -> AWS.CloudFormation.createStack template
    next: getStatus
  ,
    pattern: "update"
    action: ({ template }) -> AWS.CloudFormation.updateStack template
    next: getStatus
  ,
    pattern: "delete"
    action: ({ name }) -> AWS.CloudFormation.deleteStack StackName: name
    next: getStatus
  ,
    pattern: "done"
    result: ({ stack }) -> stack 
  ,
    pattern: /^(CREATE|UPDATE)_COMPLETE$/
    next: -> "done"
  ,
    pattern: "DELETE_COMPLETE"
    next: -> "create"
  ,
    pattern: /ROLLBACK_(COMPLETE|FAILED)$/
    next: ({name}) -> throw new Error "Deploy failed for [ #{name} ]"
  ,
    pattern: /IN_PROGRESS$/
    action: -> Time.sleep 5000
    next: getStatus
  ,
    pattern: /FAILED$/
    result: ({name}) -> throw new Error "Unable to gracefully recover from state [ #{name} ]"

]

deployStack = (name, template, capabilities) ->

  console.log template

  state = name: "start"

  context =
    name: name
    template: 
      StackName: name
      Capabilities: capabilities ? [ "CAPABILITY_IAM" ]
      # Tags: [{
      #   Key: "domain"
      #   Value: configuration.tld
      # }]
      TemplateBody: template

  try
    await runNetwork nodes, state, context
  catch error
    if /No updates/.test error.toString()
      console.log "no updates for stack [#{name}]"
    else
      throw error

deployStackAsync = (name, _template, capabilities) ->
  console.log _template

  template =
    StackName: name
    Capabilities: capabilities ? [ "CAPABILITY_IAM" ]
    TemplateBody: _template

  if await hasStack name
    AWS.CloudFormation.updateStack template
  else
    AWS.CloudFormation.createStack template
    

deleteStack = (name) ->
  AWS.CloudFormation.deleteStack StackName: name

export {
  hasStack
  getStack
  deployStack
  deployStackAsync
  deleteStack
}