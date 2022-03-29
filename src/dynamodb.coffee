import * as DynamoDB from "@aws-sdk/client-dynamodb"
import { lift, partition } from "./helpers"

AWS =
  DynamoDB: lift DynamoDB

region = "us-east-1"

hasTable = (name) ->
  try
    result = await AWS.DynamoDB.describeTable TableName: name
    console.log result
    true
  catch error
    if /ResourceNotFoundException/.test error.toString()
      false
    else
      throw error

getTableARN = (name) ->
  "arn:aws:dynamodb:#{region}:*:table/#{name}"

createTable = (configuration) ->
  AWS.DynamoDB.createTable configuration

deleteTable = (name) ->
  if await hasTable name
    AWS.S3.deleteBucket TableName: name

export {
  hasTable
  getTableARN
  createTable
  deleteTable
}