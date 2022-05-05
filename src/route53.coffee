import * as Route53 from "@aws-sdk/client-route-53"
import { lift } from "./helpers"
import { deployStack } from "./stack"

AWS =
  Route53: lift Route53

getTLD = (domain) -> (( domain.split "." )[-2..]).join "."

getHostedZone = (domain) ->
  { HostedZones } = await AWS.Route53.listHostedZones MaxItems: "100"
  for zone in HostedZones
    if domain == zone.Name[..-2]
      return
        _: zone
        id: zone.Id
  undefined

getHostedZoneID = (domain) -> ( await getHostedZone domain ).id

addSubdomain = (domain, target) ->
  deployStack ( "domain-" + domain.replaceAll ".", "-" ),
    AWSTemplateFormatVersion: "2010-09-09"
    Description: "Create subdomain [ #{domain} ]"
    Resources:
      Subdomain:
        Type: "AWS::Route53::RecordSetGroup"
        Properties:
          HostedZoneId: await getHostedZoneID getTLD domain
          RecordSets: [
            Name: domain
            Type: "A"
            AliasTarget:
              DNSName: target
              EvaluateTargetHealth: false
              HostedZoneId: "Z2FDTNDATAQYW2"
          ]

  # TODO I couldn't get this to work
  # but this would probably run much faster?
  # kept getting invalid input errors
  # AWS.Route53.changeResourceRecordSets
  #   HostedZoneId: await getHostedZoneID getTLD domain
  #   ChangeBatch:
  #     Changes: [
  #       Action: "UPSERT"
  #       ResourceRecordSet:
  #         Name: "#{ domain }."
  #         Type: "A"
  #         TTL: 300
  #         AliasTarget:
  #           DNSName: "#{ target }."
  #           EvaluateTargetHealth: false
  #           HostedZoneId: "Z2FDTNDATAQYW2"
  #     ]

export {
  getHostedZone
  getHostedZoneID
  addSubdomain
}

