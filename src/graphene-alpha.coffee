import { getSecret } from "./secrets"
import * as Meta from "@dashkite/joy/metaclass"
import * as Fn from "@dashkite/joy/function"
import * as Time from "@dashkite/joy/time"
import fetch from "node-fetch"
import discover from "panda-sky-client"
import Mime from "mime-types"

cache =
  url: "https://graphene-alpha.dashkite.io"
  apiKey: null
  client: null

h = 
  resource: Fn.curry Fn.rtee (resource, context) ->
    context.resource = resource

  method: Fn.curry Fn.rtee (method, context) ->
    context.method = method 

  parameters: Fn.curry Fn.rtee (parameters, context) ->
    context.parameters = parameters

  content: Fn.curry Fn.rtee (content, context) ->
    context.content = content

  headers: Fn.curry Fn.rtee (headers, context) ->
    context.headers ?= {}
    Object.assign context.headers, headers

createRequest = (fx) ->
  issue: ->
    apiKey = await do -> 
      cache.apiKey ?= await getSecret "dashkite-api-key"

    client = await do ->
      cache.client ?= await discover cache.url, 
        fetch: fetch
        headers: "x-api-key": apiKey

    context = do Fn.pipe [
      -> {}
      fx...
      h.headers "x-api-key": apiKey
    ]

    { resource, parameters, method, content:body, headers } = context

    response = await client[ resource ](parameters)[method]({ body, headers })

    if response.status != 204
      json = await response.json()
  
    status: response.status
    json: json


getContentType = (path) ->
  ( Mime.lookup path  ) ? "application/octet-stream"

class Item
  @create: (_) ->
    Object.assign (new @), { _ }

  Meta.mixin @::, [
    Meta.getters
      database: -> @_.database
      collection: -> @_.collection
      key: -> @_.key
      created: -> @_.created
      updated: -> @_.updated
      expires: -> @_.expires
      content: -> @_.content
      type: -> getContentType @key
  ]

  toJSON: -> { @database, @collection, @key, @content, @created, @updated, @expires }
    

getItem = ({ database, collection, key }) ->
  request = createRequest [
    h.resource "item"
    h.method "get"
    h.parameters { database, collection, key }
  ]
  try
    response = await request.issue()
    Item.create response.json
  catch error
    if error.status == 404
      null
    else if error.status?
      throw new Error "graphene: get failed with status
        #{ error.status } for [ #{database} ][ #{collection} ][ #{key} ]"
    else
      throw error
  
putItem = ({ database, collection, key, content }) ->
  item = Item.create { database, collection, key, content }
  request = createRequest [
    h.resource "item"
    h.method "put"
    h.parameters item
    h.content item
  ]
  try
    response = await request.issue()
    Item.create response.json
  catch error
    if error.status?
      throw new Error "graphene: put failed with status
        #{ error.status } for [ #{database} ][ #{collection} ][ #{key} ]"
    else
      throw error

deleteItem = ({ database, collection, key }) ->
  request = createRequest [
    h.resource "item"
    h.method "delete"
    h.parameters { database, collection, key }
  ]
  try
    response = await request.issue()
    itemDeleted: true
  catch error
    if error.status == 404
      itemDeleted: false
    else if error.status?
      throw new Error "graphene: delete failed with status
        #{ error.status } for [ #{database} ][ #{collection} ][ #{key} ]"
    else
      throw error

scan = ({ database, collection, filter, token }) ->
  _ = if filter? then JSON.stringify filter

  request = createRequest [
    h.resource "items"
    h.method "get"
    h.parameters { database, collection, filter: _, token }
  ]
  try
    response = await request.issue()
    list: ( ( Item.create _ ) for _ in response.json.list )
    token: response.json.token
  catch error
    if error.status?
      throw new Error "graphene: scan failed with status
        #{ error.status } for [ #{database} ][ #{collection} ]"
    else
      throw error


createDatabase = ({ name }) ->
  request = createRequest [
    h.resource "databases"
    h.method "post"
    h.parameters { name }
  ]
  try
    response = await request.issue()
    response.json
  catch error
    if error.status?
      throw new Error "graphene: database creation failed with status
        #{ error.status }"
    else
      throw error

getDatabase = ({ address }) ->
  request = createRequest [
    h.resource "database"
    h.method "get"
    h.parameters { address }
  ]
  try
    response = await request.issue()
    response.json
  catch error
    if error.status == 404
      null
    else if error.status?
      throw new Error "graphene: database get failed with status
        #{ error.status } for [ #{address} ]"
    else
      throw error

deleteDatabase = ({ address }) ->
  request = createRequest [
    h.resource "database"
    h.method "delete"
    h.parameters { address }
  ]
  try
    await request.issue()
    databaseDeleted: true
  catch error
    if error.status == 404
      databaseDeleted: false
    else if error.status?
      throw new Error "graphene: database get failed with status
        #{ error.status } for [ #{address} ]"
    else
      throw error

upsertCollection = ({ database, byname, name, views }) ->
  request = createRequest [
    h.resource "collection"
    h.method "post"
    h.parameters { database, byname }
    h.content { database, byname, name, views }
  ]
  try
    response = await request.issue()
    response.json
  catch error
    if error.status?
      throw new Error "graphene: collection post failed with status
        #{ error.status } for [ #{database} ][ #{collection} ]"
    else
      throw error
  
getCollection = ({ database, byname }) ->
  request = createRequest [
    h.resource "collection"
    h.method "get"
    h.parameters { database, byname }
  ]
  try
    response = await request.issue()
    response.json
  catch error
    if error.status == 404
      null
    else if error.status?
      throw new Error "graphene: collection get failed with status
        #{ error.status } for [ #{database} ][ #{byname} ]"
    else
      throw error

deleteCollection = ({ database, byname }) ->
  request = createRequest [
    h.resource "collection"
    h.method "delete"
    h.parameters { database, byname }
  ]
  try
    await request.issue()
    collectionDeleted: true
  catch error
    if error.status == 404
      collectionDeleted: false
    else if error.status?
      throw new Error "graphene: database get failed with status
        #{ error.status } for [ #{address} ]"
    else
      throw error

waitCollection = ({ database, byname }) ->
  collection = await getCollection { database, byname }
  wait = 5000 # 5 seconds
  timeout = wait * 12 # 1 minute
  count = 0
  while collection?.status != "ready"
    if (( count++ * wait ) >= timeout )
      throw new Error "graphene: create collection 
        [ #{database} ][ #{byname} ] not ready
        after #{count} retries"
    await Time.sleep wait
    if !(collection = await getCollection { database, byname })?
      throw new Error "graphene: create collection 
        [ #{database} ][ #{byname} ]
        failed for an unknown reason"
  collection

publishCollection = ({ database, byname, name, views }) ->
  await upsertCollection { database, byname, name, views }
  await waitCollection { database, byname }


    

export { 
  Item
  getItem, putItem, deleteItem, scan
  createDatabase, getDatabase, deleteDatabase
  upsertCollection, getCollection, deleteCollection, waitCollection, publishCollection
}