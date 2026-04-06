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

function ApiManager_GetNestedValue(payload as Object, path as Dynamic) as Dynamic
    if payload = invalid return invalid

    segments = invalid
    if type(path) = "roArray"
        segments = path
    else if type(path) = "String" or type(path) = "roString"
        segments = path.Split(".")
    end if

    if segments = invalid return invalid

    current = payload
    for each segment in segments
        aa = GetInterface(current, "ifAssociativeArray")
        if aa = invalid or aa.DoesExist(segment) = false
            return invalid
        end if

        current = aa.Lookup(segment)
    end for

    return current
end function

function ApiManager_GetMappedValue(payload as Object, fieldName as String) as Dynamic
    if payload = invalid or fieldName = invalid or fieldName = "" return invalid

    if Instr(1, fieldName, ".") > 0
        return ApiManager_GetNestedValue(payload, fieldName)
    end if

    aa = GetInterface(payload, "ifAssociativeArray")
    if aa = invalid or aa.DoesExist(fieldName) = false
        return invalid
    end if

    return aa.Lookup(fieldName)
end function
