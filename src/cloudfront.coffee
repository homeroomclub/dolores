import * as CloudFront from "@aws-sdk/client-cloudfront"
import { lift, partition } from "./helpers"
import * as It from "@dashkite/joy/iterable"

AWS =
  CloudFront: lift CloudFront

normalize = ( distribution ) ->
  { Comment, Id, ARN, Status } = distribution
  name: Comment
  id: Id
  arn: ARN
  status: Status?.toLowerCase()
  _: distribution

list = ->
  Marker = undefined
  loop
    { $metadata, DistributionList } = await AWS.CloudFront.listDistributions { Marker }
    if $metadata.httpStatusCode == 200
      { NextMarker, Items } = DistributionList
      ( yield normalize item ) for item in Items
      if NextMarker? then Marker = NextMarker else break
    else
      throw new Error "cloudfront::list: unexpected status [ #{ $metadata.httpStatusCode } ]"
  # undefined

isAliasFor = (domain) -> ({ _ }) -> _.Aliases.Items?.includes domain
find = ( domain ) -> It.find ( isAliasFor domain ), list()

addCustomHeader = ({ domain, origin, name, value }) ->

  distribution = await find domain

  { 
    $metadata
    ETag
    DistributionConfig 
  } = await AWS.CloudFront.getDistributionConfig Id: distribution.id

  if $metadata.httpStatusCode == 200

    origin = DistributionConfig
      .Origins.Items.find ({ DomainName }) -> origin == DomainName

    if origin?

      headers = ( origin.CustomHeaders.Items ? [] )

      if ( header = headers.find ({ HeaderName }) -> HeaderName == name )?
        header.HeaderValue = value
      else
        headers.push
          HeaderName: name
          HeaderValue: value

      DistributionConfig.Origins.Items[0].CustomHeaders.Items = headers
      DistributionConfig.Origins.Items[0].CustomHeaders.Quantity = headers.length

      AWS.CloudFront.updateDistribution 
        Id: distribution.id
        IfMatch: ETag
        DistributionConfig: DistributionConfig

    else
      throw new Error "cloudfront.addCustomHeader: missing origin [ #{ origin } ]"

  else
    throw new Error "cloudfront.addCustomHeader: unexpected status [ #{ $metadata.httpStatusCode } ]"

export {
  list
  find
  addCustomHeader
}