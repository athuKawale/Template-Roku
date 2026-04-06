' Generic network, extraction, and normalization helpers

function ApiManager_ParseResponse(responseString as Dynamic) as Dynamic
    if responseString = invalid then return invalid
    text = responseString.tostr()
    if text = "" then return invalid
    return ParseJson(text)
end function

function ApiManager_CreateUrlTransfer(url as String) as Object
    ut = CreateObject("roUrlTransfer")
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.SetUrl(url)
    return ut
end function

function ApiManager_ResultSuccess(data as Dynamic, source as String) as Object
    return {
        "success": true,
        "data": data,
        "source": source
    }
end function

function ApiManager_ResultError(code as String, message as String, retryable as Boolean, source as String, optional details as Dynamic) as Object
    err = {
        "code": code,
        "message": message,
        "retryable": retryable,
        "source": source
    }

    if details <> invalid
        err.details = details
    end if

    return {
        "success": false,
        "error": err
    }
end function

function ApiManager_MergeAssoc(base as Dynamic, overrideValues as Dynamic) as Object
    merged = {}

    baseAA = GetInterface(base, "ifAssociativeArray")
    if baseAA <> invalid
        for each key in base
            merged[key] = base[key]
        end for
    end if

    overrideAA = GetInterface(overrideValues, "ifAssociativeArray")
    if overrideAA <> invalid
        for each key in overrideValues
            merged[key] = overrideValues[key]
        end for
    end if

    return merged
end function

function ApiManager_InterpolateDynamic(value as Dynamic, context as Dynamic) as Dynamic
    if value = invalid then return invalid

    aa = GetInterface(value, "ifAssociativeArray")
    if aa <> invalid
        outAA = {}
        for each key in value
            outAA[key] = ApiManager_InterpolateDynamic(value[key], context)
        end for
        return outAA
    end if

    arr = GetInterface(value, "ifArray")
    if arr <> invalid
        outArr = []
        for each item in value
            outArr.push(ApiManager_InterpolateDynamic(item, context))
        end for
        return outArr
    end if

    valueType = LCase(type(value))
    if valueType = "string" or valueType = "rostring"
        return ApiManager_InterpolateString(value.tostr(), context)
    end if

    return value
end function

function ApiManager_InterpolateString(template as String, context as Dynamic) as String
    if template = "" then return template

    result = template
    aa = GetInterface(context, "ifAssociativeArray")
    if aa = invalid then return result

    for each key in context
        placeholder = "{{" + key + "}}"
        replacement = ""
        if context[key] <> invalid then replacement = context[key].tostr()
        result = result.Replace(placeholder, replacement)
    end for

    return result
end function

function ApiManager_CombineUrl(baseUrl as String, path as String) as String
    if baseUrl = invalid then baseUrl = ""
    if path = invalid then path = ""

    if path = "" then return baseUrl
    if baseUrl = "" then return path

    if Left(path, 4) = "http"
        return path
    end if

    endsWithSlash = Right(baseUrl, 1) = "/"
    startsWithSlash = Left(path, 1) = "/"

    if endsWithSlash and startsWithSlash
        return baseUrl + Mid(path, 2)
    else if (not endsWithSlash) and (not startsWithSlash)
        return baseUrl + "/" + path
    end if

    return baseUrl + path
end function

function ApiManager_GetByPath(payload as Dynamic, path as Dynamic) as Dynamic
    if payload = invalid then return invalid
    if path = invalid then return payload

    tokens = ApiManager_PathToTokens(path)
    if tokens = invalid then return invalid
    if tokens.count() = 0 then return payload

    current = payload
    for each token in tokens
        tokenType = LCase(type(token))
        if tokenType = "integer" or tokenType = "float" or tokenType = "double"
            arr = GetInterface(current, "ifArray")
            if arr = invalid then return invalid
            idx = Int(token)
            if idx < 0 or idx >= arr.count() then return invalid
            current = arr[idx]
        else
            aa = GetInterface(current, "ifAssociativeArray")
            if aa = invalid or aa.DoesExist(token.tostr()) = false
                return invalid
            end if
            current = aa.Lookup(token.tostr())
        end if
    end for

    return current
end function

function ApiManager_PathToTokens(path as Dynamic) as Object
    if path = invalid
        return []
    end if

    if GetInterface(path, "ifArray") <> invalid
        return path
    end if

    text = path.tostr()
    if text = ""
        return []
    end if

    tokens = []
    token = ""
    i = 1
    while i <= Len(text)
        ch = Mid(text, i, 1)
        if ch = "."
            if token <> ""
                tokens.push(token)
                token = ""
            end if
        else if ch = "["
            if token <> ""
                tokens.push(token)
                token = ""
            end if
            closePos = Instr(i + 1, text, "]")
            if closePos = 0 then return invalid
            indexText = Mid(text, i + 1, closePos - i - 1)
            if indexText = "" then return invalid
            tokens.push(Val(indexText))
            i = closePos
        else
            token = token + ch
        end if
        i = i + 1
    end while

    if token <> ""
        tokens.push(token)
    end if

    return tokens
end function

function ApiManager_ApplyAuth(headers as Dynamic, queryParams as Dynamic, authConfig as Dynamic, context as Dynamic) as Object
    appliedHeaders = ApiManager_MergeAssoc(headers, invalid)
    appliedQuery = ApiManager_MergeAssoc(queryParams, invalid)

    strategy = "none"
    if authConfig <> invalid and authConfig.STRATEGY <> invalid
        strategy = LCase(authConfig.STRATEGY.tostr())
    end if

    if strategy = "none"
        return {
            "headers": appliedHeaders,
            "queryParams": appliedQuery
        }
    end if

    if strategy = "apikey"
        keyName = ApiManager_ValueOr(authConfig.KEY_NAME, "api_key")
        keyLocation = LCase(ApiManager_ValueOr(authConfig.LOCATION, "query"))
        keyValueTemplate = ApiManager_ValueOr(authConfig.VALUE_TEMPLATE, "{{apiKey}}")
        keyValue = ApiManager_InterpolateString(keyValueTemplate, context)

        if keyLocation = "header"
            appliedHeaders[keyName] = keyValue
        else
            appliedQuery[keyName] = keyValue
        end if
    else if strategy = "bearer"
        headerName = ApiManager_ValueOr(authConfig.HEADER_NAME, "Authorization")
        prefix = ApiManager_ValueOr(authConfig.PREFIX, "Bearer ")
        token = ApiManager_ValueOr(authConfig.TOKEN, "")
        if token = ""
            token = ApiManager_ValueOr(ApiManager_GetByPath(context, "authToken"), "")
        end if
        appliedHeaders[headerName] = prefix + token
    else if strategy = "custom"
        if authConfig.HEADERS <> invalid
            appliedHeaders = ApiManager_MergeAssoc(appliedHeaders, ApiManager_InterpolateDynamic(authConfig.HEADERS, context))
        end if

        if authConfig.COOKIE <> invalid and authConfig.COOKIE <> ""
            appliedHeaders["Cookie"] = ApiManager_InterpolateString(authConfig.COOKIE.tostr(), context)
        else if authConfig.COOKIES <> invalid
            cookieAA = ApiManager_InterpolateDynamic(authConfig.COOKIES, context)
            cookieText = ""
            for each key in cookieAA
                if cookieText <> "" then cookieText = cookieText + "; "
                cookieText = cookieText + key + "=" + cookieAA[key].tostr()
            end for
            if cookieText <> ""
                appliedHeaders["Cookie"] = cookieText
            end if
        end if
    end if

    return {
        "headers": appliedHeaders,
        "queryParams": appliedQuery
    }
end function

function ApiManager_BuildRequest(apiConfig as Dynamic, requestConfig as Dynamic, context as Dynamic, defaults as Dynamic) as Object
    apiCfg = ApiManager_MergeAssoc(apiConfig, invalid)
    reqCfg = ApiManager_MergeAssoc(requestConfig, invalid)

    mode = LCase(ApiManager_ValueOr(reqCfg.MODE, ApiManager_ValueOr(apiCfg.MODE, "rest")))
    method = UCase(ApiManager_ValueOr(reqCfg.METHOD, ""))
    if method = ""
        if mode = "graphql"
            method = "POST"
        else
            method = "GET"
        end if
    end if

    baseUrl = ApiManager_ValueOr(reqCfg.BASE_URL, ApiManager_ValueOr(apiCfg.BASE_URL, ""))
    interpolatedPath = ApiManager_InterpolateString(ApiManager_ValueOr(reqCfg.PATH, ""), context)
    explicitUrl = ApiManager_InterpolateString(ApiManager_ValueOr(reqCfg.URL, ""), context)

    url = explicitUrl
    if url = ""
        url = ApiManager_CombineUrl(baseUrl, interpolatedPath)
    end if

    if url = ""
        return ApiManager_ResultError("REQUEST_BUILD_ERROR", "Unable to build request URL from config.", false, "request-builder")
    end if

    defaultHeaders = ApiManager_MergeAssoc(apiCfg.DEFAULT_HEADERS, invalid)
    requestHeaders = ApiManager_InterpolateDynamic(ApiManager_MergeAssoc(defaultHeaders, reqCfg.HEADERS), context)

    defaultQueryParams = ApiManager_MergeAssoc(apiCfg.DEFAULT_QUERY_PARAMS, invalid)
    requestQueryParams = ApiManager_InterpolateDynamic(ApiManager_MergeAssoc(defaultQueryParams, reqCfg.QUERY_PARAMS), context)

    requestBody = reqCfg.BODY
    if mode = "graphql"
        gql = reqCfg.GRAPHQL
        if requestBody = invalid
            requestBody = {
                "query": ApiManager_ValueOr(ApiManager_GetByPath(gql, "QUERY"), ""),
                "variables": ApiManager_GetByPath(gql, "VARIABLES")
            }
            operationName = ApiManager_GetByPath(gql, "OPERATION_NAME")
            if operationName <> invalid and operationName <> ""
                requestBody.operationName = operationName
            end if
        end if
    end if
    requestBody = ApiManager_InterpolateDynamic(requestBody, context)

    authMerged = ApiManager_MergeAssoc(apiCfg.AUTH, reqCfg.AUTH)
    authApplied = ApiManager_ApplyAuth(requestHeaders, requestQueryParams, authMerged, context)

    timeoutMs = ApiManager_NumberOrDefault(reqCfg.TIMEOUT_MS, 0)
    if timeoutMs <= 0
        timeoutMs = ApiManager_NumberOrDefault(apiCfg.TIMEOUT_MS, 0)
    end if
    if timeoutMs <= 0
        timeoutMs = ApiManager_NumberOrDefault(ApiManager_GetByPath(defaults, "TIMEOUT_MS"), 10000)
    end if

    retryPolicy = ApiManager_MergeAssoc(ApiManager_GetByPath(defaults, "RETRY_POLICY"), ApiManager_GetByPath(apiCfg, "RETRY_POLICY"))
    retryPolicy = ApiManager_MergeAssoc(retryPolicy, reqCfg.RETRY_POLICY)

    return ApiManager_ResultSuccess({
        "mode": mode,
        "method": method,
        "url": url,
        "headers": authApplied.headers,
        "queryParams": authApplied.queryParams,
        "body": requestBody,
        "timeoutMs": timeoutMs,
        "retryPolicy": retryPolicy
    }, "request-builder")
end function

function ApiManager_DetectStreamFormat(url as Dynamic, fallback as String) as String
    text = ""
    if url <> invalid then text = LCase(url.tostr())

    if Instr(1, text, ".m3u8") > 0 then return "hls"
    if Instr(1, text, ".mpd") > 0 then return "dash"
    if Instr(1, text, ".mp4") > 0 then return "mp4"
    if Instr(1, text, ".ism") > 0 then return "ism"

    if fallback <> invalid and fallback <> ""
        return fallback
    end if

    return "hls"
end function

function ApiManager_IsHttpSuccess(statusCode as Integer) as Boolean
    return statusCode >= 200 and statusCode < 300
end function

function ApiManager_ValueOr(value as Dynamic, fallback as String) as String
    if value = invalid then return fallback
    text = value.tostr()
    if text = "" then return fallback
    return text
end function

function ApiManager_NumberOrDefault(value as Dynamic, fallback as Integer) as Integer
    if value = invalid then return fallback
    return Int(value)
end function
