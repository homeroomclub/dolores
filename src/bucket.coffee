import * as S3 from "@aws-sdk/client-s3"
import { lift, partition } from "./helpers"
import { generic } from "@dashkite/joy/generic"
import { isString, isObject } from "@dashkite/joy/type"


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

getObject = ( name, key ) ->
  try
    object = await AWS.S3.getObject Bucket: name, Key: key
  catch error
    rescueNotFound error
    null

isS3Object = (value) -> ( isObject value ) && value.Body?

streamObject = generic name: "streamObject"

generic streamObject, isS3Object, isString, ( { Body }, encoding ) ->
  if encoding == "binary"
    Body
  else
    new Promise (resolve, reject) ->
      Body.setEncoding encoding
      output = ""
      Body.on "data", (chunk) -> output += chunk
      Body.on "error", (error) -> reject error
      Body.on "end", -> resolve output

generic streamObject, isS3Object, ( object ) ->
  streamObject object, "utf8"

generic streamObject, isString, isString, isString, ( name, key, encoding ) ->
  streamObject ( await getObject name, key ), encoding

generic streamObject, isString, isString, ( name, key ) ->
  streamObject await getObject name, key

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
  streamObject
  putObject
  deleteObject
  deleteObjects
  listObjects
}