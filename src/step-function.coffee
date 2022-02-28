import * as StepFunction from "@aws-sdk/client-sfn"
import * as STS from "@aws-sdk/client-sts"
import { lift } from "./helpers"

import YAML from "js-yaml"

import { deployStack, deleteStack } from "./stack"

AWS =
  StepFunction: lift StepFunction
  STS: lift STS

createStepFunction = ({ name, dictionary, resources, description }) ->
  account = ( await AWS.STS.getCallerIdentity() ).Account
  # TODO make the region dynamic?
  arn = "arn:aws:states:us-east-1:#{account}:stateMachine:#{name}"
  _template =
    AWSTemplateFormatVersion: "2010-09-09"
    Description: "Create step function [ #{name} ]"
    Resources:
      StatesExecutionRole:
        Type: "AWS::IAM::Role"
        Properties:
          AssumeRolePolicyDocument:
            Version: "2012-10-17"
            Statement: [
                Effect: "Allow"
                Principal:
                  Service: [ "states.amazonaws.com" ]
                Action: "sts:AssumeRole"
            ]
          Path: "/"
          Policies: [
            PolicyName: "StatesExecutionPolicy"
            PolicyDocument:
              Version: "2012-10-17"
              Statement: [
                  Effect: "Allow"
                  Action: [ "lambda:InvokeFunction" ]
                  Resource: resources.lambdas
                ,
                  Effect: "Allow"
                  Action: [ 
                    "states:startExecution" 
                  ]
                  Resource: [ arn, resources.stepFunctions... ]
                ,
                  Effect: "Allow"
                  Action:[
                    "states:DescribeExecution"
                    "states:StopExecution"
                  ]
                  Resource: '*'
                ,
                  Effect: "Allow"
                  Action:[
                    "events:PutTargets"
                    "events:PutRule"
                    "events:DescribeRule"
                  ]
                  Resource: [
                    "arn:aws:events:us-east-1:618441030511:rule/StepFunctionsGetEventsForStepFunctionsExecutionRule"
                  ]
              ]
          ]
      StateMachine:
        Type: "AWS::StepFunctions::StateMachine"
        Properties: 
          DefinitionString: JSON.stringify description
          DefinitionSubstitutions: {
            dictionary...
            self: arn
          }
          RoleArn: "Fn::GetAtt": [ "StatesExecutionRole" , "Arn" ]
          StateMachineName: name
          StateMachineType: "STANDARD"

  deployStack "#{name}-sf", YAML.dump _template

deleteStepFunction = ( name ) -> deleteStack "#{name}-sf"

getStepFunction = (name) ->
  { stateMachines } = await AWS.StepFunction.listStateMachines()
  machine = stateMachines.find (machine) -> machine.name == name
  if machine?
    _: machine
    arn: machine.stateMachineArn
    name: machine.name

hasStepFunction = ( name ) -> ( await getStepFunction name )?

getStepFunctionARN = (name) -> ( await getStepFunction name )?.arn

startStepFunction = (name, input) ->
  if ( arn = await getStepFunctionARN name )?
    parameters = if input?
      stateMachineArn: arn
      input: JSON.stringify input
    else
      stateMachineArn: arn

    AWS.StepFunction.startExecution parameters

  else
    throw new Error "Step Function [ #{ name } ] not found"

haltStepFunction = (name) ->
  if ( arn = await getStepFunctionARN name )?
    response = await AWS.StepFunction.listExecutions
      stateMachineArn: arn
      statusFilter: "RUNNING"
    for execution in response.executions
      AWS.StepFunction.stopExecution
        executionArn: execution.executionArn
    if response.nextToken?
      throw new Error "More executions remain for step function [ #{name} ]"
  else
    throw new Error "Step Function [ #{ name } ] not found"

export {
  createStepFunction
  deleteStepFunction
  getStepFunction
  hasStepFunction
  haltStepFunction
  getStepFunctionARN
  startStepFunction
}