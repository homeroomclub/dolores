import * as S3 from "@aws-sdk/client-s3"
import * as Type from "@dashkite/joy/type"
import { lift, partition } from "./helpers"


AWS =
  S3: lift S3

rescueNotFound = (error) ->
  code = error?.$response?.statusCode ? error.$metadata.httpStatusCode
  if ! ( code in [ 403, 404 ] )
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
  await AWS.S3.deleteBucketLifecycle Bucket: name


headObject = (name, key) ->
  try
    await AWS.S3.headObject Bucket: name, Key: key
  catch error
    rescueNotFound error
    null

hasObject = (name, key) ->
  if ( await headObject name, key )? then true else false

getObject = (name, key) ->
  try
    { Key, ETag, Body } = await AWS.S3.getObject Bucket: name, Key: key
    key: key
    hash: ETag.replace /"/g, ""
    content: await do ->
      if Type.isString Body
        Body
      else
        result = []
        for await data from Body
          result = [ result..., data... ]
        Uint8Array.from result
  catch error
    console.error error
    rescueNotFound error
    null

putObject = (name, key, body) ->
  AWS.S3.putObject
    Bucket: name
    Key: key
    Body: body

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

  if Contents?
    items = [ items..., Contents... ]
  if IsTruncated
    await listObjects name, prefix, items, NextContinuationToken
  else
    items

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