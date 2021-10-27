import { Lambda } from "@aws-sdk/client-lambda"
import { Route53 } from "@aws-sdk/client-route-53"
import { CloudFormation } from "@aws-sdk/client-cloudformation"
import Handlebars from "handlebars"
import * as Time from "@dashkite/joy/time"

clients =
  Lambda: new Lambda region: "us-east-1"
  Route53: new Route53 region: "us-east-1"
  CloudFormation: new CloudFormation region: "us-east-1"

hasStack = (name) ->
  try
    { Stacks } = await clients.CloudFormation.describeStacks StackName: name
    Stacks[0]?
  catch
    false

getStack = (name) ->
  try
    { Stacks } = await clients.CloudFormation.describeStacks StackName: name
    Stacks[0]
  catch
    undefined

deployStack = (template, configuration) ->
  _configuration = 
    StackName: name
    Capabilities: [ "CAPABILITY_IAM" ]
    Tags: [{
      Key: "domain"
      Value: configuration.tld
    }]
    TemplateBody: ( ( Handlebars.compile template ) configuration )

  if ( stack = await hasStack name )?
    await client.updateStack _configuration
  else
    await client.createStack _configuration

  loop
    if ( stack = await getStack name )?
      { StackStatus, StackStatusReason } = stack
      break if !StackStatus
      switch StackStatus
        when "CREATE_IN_PROGRESS", "UPDATE_IN_PROGRESS", "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS"
          await Time.sleep 5000
        when "CREATE_COMPLETE", "UPDATE_COMPLETE"
          break
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