import { Route53 } from "@aws-sdk/client-route-53"

AWS =
  Route53: new Route53 region: "us-east-1"

getHostedZone = (domain) ->
  { HostedZones } = await AWS.Route53.listHostedZones MaxItems: "100"
  for zone in HostedZones
    if domain == zone.Name
      return zone
  undefined

export {
  getHostedZone
}

