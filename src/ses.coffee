import * as SES from "@aws-sdk/client-ses"
import { lift } from "./helpers"

AWS =
  SES: lift SES, region: "us-west-2"

templateExists = (name) -> (await getTemplate name)?

getTemplate = (name) ->
  try
    template = await AWS.SES.getTemplate TemplateName: name
    _: template
  catch error
    if /TemplateDoesNotExist/.test error.toString()
      undefined
    else
      throw error

publishSES = ({name, html, subject, text}) ->
  params = 
    Template:
      TemplateName: name
      HtmlPart: html
      SubjectPart: subject
      TextPart: text
  
  if await templateExists name
    await AWS.SES.updateTemplate params
  else
    await AWS.SES.createTemplate params

sendEmail = ({source, template, toAddresses, templateData}) ->
  jsonTemplateData = JSON.stringify templateData
  params = 
    Source: source
    Destination: ToAddresses: toAddresses
    Template: template
    TemplateData: jsonTemplateData

  await AWS.SES.sendTemplatedEmail params

export { publishSES, sendEmail }