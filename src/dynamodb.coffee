import * as DynamoDB from "@aws-sdk/client-dynamodb"
import { lift, partition } from "./helpers"

AWS =
  DynamoDB: lift DynamoDB

region = "us-east-1"

getTable = (name) ->
  try
    { Table } = await AWS.DynamoDB.describeTable TableName: name
    Table
  catch error
    if /ResourceNotFoundException/.test error.toString()
      null
    else
      throw error

hasTable = (name) ->
  if ( await getTable name )?
    true
  else
    false

getTableARN = (name) ->
  "arn:aws:dynamodb:#{region}:*:table/#{name}"

createTable = (configuration) ->
  AWS.DynamoDB.createTable configuration

deleteTable = (name) ->
  if await hasTable name
    AWS.DynamoDB.deleteTable TableName: name

export {
  getTable
  hasTable
  getTableARN
  createTable
  deleteTable
}