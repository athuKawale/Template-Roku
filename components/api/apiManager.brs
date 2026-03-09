' This file contains low-level parsing and network utilities
function ApiManager_ParseResponse(responseString as Dynamic) as Object
    if responseString = invalid or responseString = "" return invalid
    return ParseJson(responseString.tostr())
end function

function ApiManager_CreateUrlTransfer(url as String) as Object
    ut = CreateObject("roUrlTransfer")
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.SetUrl(url)
    return ut
end function
