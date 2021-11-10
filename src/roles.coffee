import { IAM } from "@aws-sdk/client-iam"

import { deployStack } from "./stack"

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
                Service: [ "lambda.amazonaws.com" ]
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

  await deployStack "#{name}-stack",
    ( JSON.stringify _template ),
    [ "CAPABILITY_NAMED_IAM" ]

  # TODO maybe get this as an output from the template
  { Role } = await AWS.IAM.getRole RoleName: name
  Role.Arn

export {
  createRole
}