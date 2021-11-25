import { ACM } from "@aws-sdk/client-acm"

AWS =
  ACM: new ACM region: "us-east-1"
  
hasCertificate = (domain) -> (await getCertification domain)?

getCertificate = (domain) ->
  { CertificateSummaryList } = await AWS.ACM.listCertificates
    CertificateStatuses: [ "ISSUED" ]
  for { CertificateArn } in CertificateSummaryList
    { Certificate } = await AWS.ACM.describeCertificate { CertificateArn }
    if domain in Certificate.SubjectAlternativeNames
      return 
        _: Certificate
        arn: CertificateArn
  undefined  

getCertificateARN = (domain) -> ( await getCertificate domain ).arn

export {
  hasCertificate
  getCertificate
  getCertificateARN
}