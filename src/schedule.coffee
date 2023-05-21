import YAML from "js-yaml"
import * as Scheduler from "@aws-sdk/client-scheduler"
import * as STS from "@aws-sdk/client-sts"
import * as Obj from "@dashkite/joy/object"
import * as Type from "@dashkite/joy/type"
import * as Text from "@dashkite/joy/text"
import { lift } from "./helpers"
import * as Stack from "./stack"
import * as SQS from "./queue"


cache =
  account: null

AWS =
  STS: lift STS
  Scheduler: lift Scheduler

region = "us-east-1"

nameStack = ({ group, name }) -> "#{ Text.dashed group }-#{ Text.dashed name }-schedule"

getScheduleARN = ({ group, name }) ->
  account = await do ->
    cache.account ?= ( await AWS.STS.getCallerIdentity() ).Account
  "arn:aws:scheduler:#{region}:#{account}:schedule/#{group}/#{name}"

createAccessRole = ({ group, name, target }) ->
  # TODO possibly use API directly for creating roles
  # so we don't exhaust our stack quota
  properties = 
    RoleName: "schedule-#{group}-#{name}-access"
    AssumeRolePolicyDocument:
      Version: "2012-10-17"
      Statement: [
        Effect: "Allow"
        Principal:
          Service: [
            "scheduler.amazonaws.com"
          ]
        Action:[ "sts:AssumeRole" ]
      ]
  
  switch target.type
    when "sqs"
      properties.Policies = [
        PolicyName: "schedule-sqs-#{group}-#{name}-policy"
        PolicyDocument:
          Version: "2012-10-17"
          Statement: [
            Effect: "Allow"
            Action: [
              "sqs:GetQueueUrl"
              "sqs:GetQueueAttributes"
              "sqs:DeleteMessage"
              "sqs:ReceiveMessage"
              "sqs:SendMessage"
            ]
            Resource: await SQS.getQueueARN target.name
          ]
      ]
    else
      throw new Error "dolores:schedule does not currently support this target type"
    
  Type: "AWS::IAM::Role"
  Properties: properties


getSchedule = ({ group, name }) ->
  try
    await AWS.Scheduler.getSchedule
      GroupName: group
      Name: name
  catch error
    if /ResourceNotFoundException/.test error.toString()
      null
    else
      throw error


putSchedule = ( { group, name }, accessRole, options ) ->

  _template =
    AWSTemplateFormatVersion: "2010-09-09"
    Description: "Specify Group of Schdules [ #{group} ]"
    Resources:
      IAMRole: accessRole
      Schedule:
        Type: "AWS::Scheduler::Schedule"
        Properties: options

  await Stack.deployStack ( nameStack { group, name } ), 
    ( YAML.dump _template ),
    [ "CAPABILITY_NAMED_IAM" ]
  
  undefined
  

deleteSchedule = ({ group, name }) ->
  await Stack.deleteStack nameStack { group, name }
  undefined


export {
  getScheduleARN
  getSchedule
  createAccessRole
  putSchedule
  deleteSchedule
}