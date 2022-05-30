import { ACM } from "@aws-sdk/client-acm"

AWS =
  ACM: new ACM region: "us-east-1"
  
hasCertificate = (name) -> (await getCertification domain)?

getCertificate = (name) ->
  { CertificateSummaryList } = await AWS.ACM.listCertificates
    CertificateStatuses: [ "ISSUED" ]
  for { CertificateArn } in CertificateSummaryList
    { Tags } = await AWS.ACM.listTagsForCertificate { CertificateArn }
    for Tag in Tags
      if Tag.Key == "Name" && Tag.Value == name
        return 
          arn: CertificateArn
  undefined  

getCertificateARN = (domain) -> ( await getCertificate domain ).arn

export {
  hasCertificate
  getCertificate
  getCertificateARN
}