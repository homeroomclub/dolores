import YAML from "js-yaml"

import { deployStack, deleteStack } from "./stack"

# TODO support patterns

createRule = ({ name, target, schedule }) ->
  # TODO possibly use API directly for creating rules
  # so we don't exhaust our stack quota
  _template =
    AWSTemplateFormatVersion: "2010-09-09"
    Description: "Create rule [ #{name} ]"
    Resources:
      Event:
        Type: "AWS::Events::Rule"
        Properties: 
          Description: name
          # EventBusName: String
          # EventPattern: Json
          Name: name
          ScheduleExpression: schedule
          State: "ENABLED"
          Targets: [ target ]
      EventPermission:
        DependsOn: [ "Event" ]
        Type: "AWS::Lambda::Permission"
        Properties:
          Action: "lambda:InvokeFunction"
          FunctionName: target.Arn
          Principal: "events.amazonaws.com"
          SourceArn:
            "Fn::GetAtt": [ "Event" , "Arn" ]

  await deployStack name, YAML.dump _template

  undefined

deleteRule = (name) -> deleteStack name

hasRule = (name) -> (await getRule name)?

getRule = (name) ->

getRuleARN = (name) -> (await getRule name).arn

export {
  createRule
  deleteRule
  hasRule
  getRule
  getRuleARN
}