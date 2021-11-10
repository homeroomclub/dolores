import { CloudFormation } from "@aws-sdk/client-cloudformation"
import * as Time from "@dashkite/joy/time"

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
  context.stack.status

nodes = [

    pattern: "start"
    next: getStatus
    nodes: [
      pattern: /COMPLETE$/, next: -> "update"
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
    pattern: /^ROLLBACK_(COMPLETE|FAILED)$/
    next: -> "delete"
  ,
    pattern: /IN_PROGRESS$/
    action: -> Time.sleep 5000
    next: getStatus
  
]

turn = (nodes, state, context) ->
  console.log state.name
  for node in nodes
    if node.pattern == state.name || node.pattern.test? state.name
      if node.action?
        await node.action context, state
      if node.result?
        state.result = await node.result context, state
      else if node.next?
        state.name = await node.next context, state
        if node.nodes?
          await turn node.nodes, state, context
      return undefined


deployStack = (name, template, capabilities) ->

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

  loop
    await turn nodes, state, context
    if state.result?
      return state.result

export {
  hasStack
  getStack
  deployStack
}