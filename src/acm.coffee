import { ACM } from "@aws-sdk/client-acm"

AWS =
  ACM: new ACM region: "us-east-1"
  
hasCertificate = (domain) -> (await getCertification domain)?

getCertificate = (domain) ->
  { CertificateSummaryList } = await AWS.ACM.listCertificates
    CertificateStatuses: [ "ISSUED" ]
  for summary in CertificateSummaryList
    if domain == summary.DomainName
      return summary
  undefined  

exports {
  hasCertificate
  getCertificate
}