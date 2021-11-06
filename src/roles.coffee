import { IAM } from "@aws-sdk/client-iam"

import { deployStack } from "./stack"

AWS =
  IAM: new IAM region: "us-east-1"

createRole = ( name, policies ) ->
  await deployStack "#{name}-stack", JSON.stringify
    IAMRole:
      RoleName: name
      Type: "AWS::IAM::Role"
      Properties:
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
        Policies:
          PolicyName: "#{name}-policy"
          PolicyDocument:
            Version: "2012-10-17"
            Statement: policies
  # TODO maybe get this as an output from the template
  { Role } = await AWS.IAM.getRole RoleName: name
  Role.Arn

export {
  createRole
}