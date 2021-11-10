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

deleteStack = (name) ->
  await AWS.CloudFormation.deleteStack StackName: name
  loop
    stack = await getStack name
    console.log "delete-wait": stack?.status
    switch stack?.status
      when "DELETE_IN_PROGRESS"
        await Time.sleep 5000
      when "DELETE_COMPLETE", undefined
        return
      else
        throw new Error "stack deletion failed:
          status: #{stack.status}, reason: #{stack._.StackStatusReason}"

deployStack = (name, template, capabilities) ->

  _template =
    StackName: name
    Capabilities: capabilities ? [ "CAPABILITY_IAM" ]
    # Tags: [{
    #   Key: "domain"
    #   Value: configuration.tld
    # }]
    TemplateBody: template

  if ( stack = await getStack name )?
    console.log deploy: stack.status
    if stack.status in [ "ROLLBACK_COMPLETE", "ROLLBACK_FAILED" ]
      await deleteStack name
      await AWS.CloudFormation.createStack _template
    else
      await AWS.CloudFormation.updateStack _template
  else
    await AWS.CloudFormation.createStack _template

  loop
    stack = await getStack name
    console.log "deploy-wait": stack?.status
    switch stack?.status
      when "CREATE_IN_PROGRESS", "UPDATE_IN_PROGRESS", "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS"
        await Time.sleep 5000
      when "CREATE_COMPLETE", "UPDATE_COMPLETE"
        return stack
      when undefined
        # ... wtf
        throw new Error "unable to load stack: #{name}"
      else
        throw new Error "stack creation failed:
          status: #{stack.status}, reason: #{stack._.StackStatusReason}"

export {
  hasStack
  getStack
  deployStack
}