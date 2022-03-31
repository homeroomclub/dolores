import { getSecret } from "./secrets"
import * as Meta from "@dashkite/joy/metaclass"
import fetch from "node-fetch"
import Mime from "mime-types"

getContentType = (path) ->
  ( Mime.lookup path  ) ? "application/octet-stream"

class Resource
  @create: (_) ->
    Object.assign (new @), { _ }

  Meta.mixin @::, [
    Meta.getters
      collection: -> @_.collection
      _collection: -> encodeURIComponent @collection
      key: -> @_.key
      _key: -> encodeURIComponent @key
      url: -> "https://graphene.dashkite.io/files/#{@_collection}/#{@_key}"
      value: -> @_.value
      created: -> @_.created
      updated: -> @_.updated
      expires: -> @_.expires
      type: -> getContentType @key
  ]

  toJSON: -> { @collection, @key, @value, @created, @updated, @expires }
    

getResource = (collection, key) ->
  resource = Resource.create { collection, key }
  response = await fetch resource.url,
    headers:
      "x-api-key": await getSecret "dashkite-api-key"
  switch response.status
    when 200
      Resource.create await response.json()
    when 404
      null
    else
      throw new Error "graphene: get failed with status
        #{ response.status } for [ #{collection} ][ #{key} ]"
  
putResource = (collection, key, value) ->
  resource = Resource.create { collection, key, value }
  response = await fetch resource.url,
    method: "PUT"
    body: JSON.stringify resource
    headers:
      "x-api-key": await getSecret "dashkite-api-key"
  switch response.status
    when 200, 201
      Resource.create await response.json()
    else
      throw new Error "graphene: put failed with status
        #{ response.status } for [ #{collection} ][ #{key} ]"

deleteResource = (collection, key) ->
  resource = Resource.create { collection, key }
  response = await fetch resource.url,
    method: "DELETE"
    headers:
      "x-api-key": await getSecret "dashkite-api-key"
  switch response.status
    when 204
      resourceDeleted: true
    when 404
      resourceDeleted: false
    else
      throw new Error "graphene: delete failed with status
        #{ response.status } for [ #{collection} ][ #{key} ]"

export { Resource, getResource, putResource, deleteResource }