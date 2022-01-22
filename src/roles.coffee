import { IAM } from "@aws-sdk/client-iam"
import YAML from "js-yaml"

import { deployStack, deleteStack } from "./stack"

AWS =
  IAM: new IAM region: "us-east-1"

createRole = ( name, policies ) ->
  # TODO possibly use API directly for creating roles
  # so we don't exhaust our stack quota
  _template =
    AWSTemplateFormatVersion: "2010-09-09"
    Description: "Create role [ #{name} ]"
    Resources:
      IAMRole:
        Type: "AWS::IAM::Role"
        Properties:
          RoleName: name
          AssumeRolePolicyDocument:
            Version: "2012-10-17"
            Statement: [
              Effect: "Allow"
              Principal:
                Service: [
                  "lambda.amazonaws.com"
                  "edgelambda.amazonaws.com"
                ]
              Action:[ "sts:AssumeRole" ]
            ]
          # ManagedPolicyArns:
          #   TODO add managed policies
          Policies: [
            PolicyName: "#{name}-policy"
            PolicyDocument:
              Version: "2012-10-17"
              Statement: policies
          ]

  await deployStack name,
    ( YAML.dump _template ),
    [ "CAPABILITY_NAMED_IAM" ]

  undefined

deleteRole = (name) -> deleteStack name

hasRole = (name) -> (await getRole name)?

getRole = (name) ->
  # TODO handle not found explicitly
  # see lambda for example but unsure if the exception is always the same
  try
    { Role } = await AWS.IAM.getRole RoleName: name
    arn: Role.Arn
    _: Role

getRoleARN = (name) -> (await getRole name).arn

export {
  createRole
  hasRole
  getRole
  getRoleARN
}