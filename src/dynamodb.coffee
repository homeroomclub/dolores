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

listTables = ->
  ExclusiveStartTableName = undefined
  loop
    { TableNames, LastEvaluatedTableName } = await AWS.DynamoDB.listTables { ExclusiveStartTableName }
    yield name for name in TableNames
    if LastEvaluatedTableName?
      ExclusiveStartTableName = LastEvaluatedTableName
    else
      break

query = ( query ) ->
  NextToken = undefined
  loop
    { Items, NextToken } = await AWS.DynamoDB.executeStatement {
      Statement: query
      NextToken
    }
    yield item for item in Items
    if NextToken? then continue else break

deleteItem = ( table, key ) ->
  AWS.DynamoDB.deleteItem TableName: table, Key: key

export {
  getTable
  hasTable
  getTableARN
  createTable
  deleteTable
  listTables
  query
  deleteItem
}