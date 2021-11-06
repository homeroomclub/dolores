import { CloudFormation } from "@aws-sdk/client-cloudformation"
import * as Time from "@dashkite/joy/time"

AWS =
  CloudFormation: new CloudFormation region: "us-east-1"

hasStack = (name) -> (await getStack name)?

getStack = (name) ->
  try
    { Stacks } = await AWS.CloudFormation.describeStacks StackName: name
    # TODO is there anything else to return here?
    _: Stacks[0]
  catch
    undefined

deployStack = (name, template) ->

  _template =
    StackName: name
    Capabilities: [ "CAPABILITY_IAM" ]
    # Tags: [{
    #   Key: "domain"
    #   Value: configuration.tld
    # }]
    TemplateBody: template

  if await hasStack name
    await AWS.CloudFormation.updateStack _template
  else
    await AWS.CloudFormation.createStack _template

  loop
    if ( stack = await getStack name )?
      { StackStatus, StackStatusReason } = stack._
      break if !StackStatus
      switch StackStatus
        when "CREATE_IN_PROGRESS", "UPDATE_IN_PROGRESS", "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS"
          await Time.sleep 5000
        when "CREATE_COMPLETE", "UPDATE_COMPLETE"
          return stack
        else
          throw new Error "stack creation failed:
            status: #{StackStatus}, reason: #{StackStatusReason}"
    else
      # ... wtf
      throw new Error "unable to load stack: #{name}"

export {
  hasStack
  getStack
  deployStack
}