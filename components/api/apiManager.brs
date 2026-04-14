' TEMPLATE: Low-level parsing and network utilities.
' Customize headers, certificates, or response parsing here if your API needs it.
function ApiManager_ParseResponse(responseString as Dynamic) as Object
    if responseString = invalid or responseString = "" then return invalid
    return ParseJson(responseString.tostr())
end function

function ApiManager_CreateUrlTransfer(url as String) as Object
    ut = CreateObject("roUrlTransfer")
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.InitClientCertificates()
    ut.RetainBodyOnError(true)
    ut.SetUrl(url)
    return ut
end function
