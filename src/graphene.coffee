import { getSecret } from "./secrets"
import fetch from "node-fetch"
import Mime from "mime-types"

getContentType = (path) ->
  ( Mime.lookup path  ) ? "application/octet-stream"

getResource = (collection, key) ->
  _collection = encodeURIComponent collection
  _key = encodeURIComponent key
  response = await fetch "https://graphene.dashkite.io/files/#{_collection}/#{_key}",
    headers:
      "x-api-key": await getSecret "dashkite-api-key"
  switch response.status
    when 200
      type: getContentType key
      content: ( await response.json() ).value
    when 404
      null
    else
      throw new Error "graphene: get failed with status
        #{ response.status } for [ #{collection} ][ #{key} ]"
  
putResource = (collection, key, value) ->
  _collection = encodeURIComponent collection
  _key = encodeURIComponent key
  response = await fetch "https://graphene.dashkite.io/files/#{_collection}/#{_key}",
    method: "PUT"
    body: JSON.stringify { collection, key, value }
    headers:
      "x-api-key": await getSecret "dashkite-api-key"
  switch response.status
    when 200, 201
      { collection, key, value }
    else
      throw new Error "graphene: put failed with status
        #{ response.status } for [ #{collection} ][ #{key} ]"

export { getResource, putResource }