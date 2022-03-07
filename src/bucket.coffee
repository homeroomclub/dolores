import * as S3 from "@aws-sdk/client-s3"
import { lift, partition } from "./helpers"


AWS =
  S3: lift S3

rescueNotFound = (error) ->
  if ! ( error?.$response?.statusCode in [ 403, 404 ] )
    throw error

hasBucket = (name) ->
  try
    await AWS.S3.headBucket Bucket: name
    true
  catch error
    rescueNotFound error
    false

getBucketARN = (name) ->
  "arn:aws:s3:::#{name}"

putBucket = (name) ->
  if !( await hasBucket name )
    await AWS.S3.createBucket Bucket: name

deleteBucket = (name) ->
  if await hasBucket name
    await AWS.S3.deleteBucket Bucket: name

getBucketLifecycle = (name) ->
  await AWS.S3.getBucketLifecycleConfiguration Bucket: name

putBucketLifecycle = (name, lifecycle) ->
  await AWS.S3.putBucketLifecycleConfiguration 
    Bucket: name
    LifecycleConfiguration: lifecycle

deleteBucketLifecycle = (name) ->
  await AWS.S3.deleteBucketLifecycleConfiguration Bucket: name


headObject = (name, key) ->
  try
    await AWS.S3.headObject Bucket: name, Key: key
  catch error
    rescueNotFound error
    null

hasObject = (name, key) ->
  if ( await headObject name, key )? then true else false

getObject = (name, key, encoding="utf8") ->
  try
    {Body} = await AWS.S3.getObject Bucket: name, Key: key
    if encoding == "binary"
      Body
    else
      new Promise (resolve, reject) ->
        Body.setEncoding encoding
        output = ""
        Body.on "data", (chunk) -> output += chunk
        Body.on "error", (error) -> reject error
        Body.on "end", -> resolve output

  catch e
    rescueNotFound error
    null

putObject = (parameters) ->
  AWS.S3.putObject parameters

deleteObject = (name, key) ->
  if await hasObject name, key
    await AWS.S3.deleteObject Bucket: name, Key: key


deleteObjects = (name, keys) ->
  await AWS.S3.deleteObjects
    Bucket: name
    Delete:
      Objects: ( Key: key for key in keys )
      Quiet: true


listObjects = (name, prefix, items=[], token) ->
  parameters = 
    Bucket: name
    MaxKeys: 1000
  parameters.ContinuationToken = token if token?
  parameters.Prefix = prefix if prefix?

  {
    IsTruncated
    Contents
    NextContinuationToken
  } = await AWS.S3.listObjectsV2 parameters
  
  if IsTruncated
    items = items.concat Contents
    await listObjects name, prefix, items, NextContinuationToken
  else
    items.concat Contents

deleteDirectory = (name, prefix) ->
  keys = []
  for object in ( await listObjects name, prefix )
    keys.push object.Key
  
  for batch from partition 1000, keys
    if batch.length > 0 # Is this neccessary?
      await deleteObjects name, batch

emptyBucket = (name) -> deleteDirectory name

export {
  getBucketARN
  hasBucket
  putBucket
  deleteBucket
  deleteDirectory
  emptyBucket

  getBucketLifecycle
  putBucketLifecycle
  deleteBucketLifecycle

  headObject
  hasObject
  getObject
  putObject
  deleteObject
  deleteObjects
  listObjects
}