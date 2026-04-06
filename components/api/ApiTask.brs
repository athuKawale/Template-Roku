sub init()
    m.top.functionName = "runRequest"
end sub

sub runRequest()
    request = m.top.request
    if request = invalid
        m.top.response = ErrorResult("INVALID_REQUEST", false, "api-task")
        return
    end if

    config = GetAppConfig()
    m.config = config
    m.requestTypes = GetValueOrDefault(config.DEFAULTS, "REQUEST_TYPES", {})
    validation = ValidateAppConfig(config)
    if validation.valid = false
        m.top.response = ErrorResult("CONFIG_VALIDATION_FAILED", false, "config-validation", { "errors": validation.errors, "message": validation.message })
        return
    end if

    profile = config.PROFILE
    requestType = UCase(GetStringValue(request, "type", ""))

    if requestType = UCase(GetConfiguredRequestType("LOAD_FEED", "LOAD_FEED"))
        m.top.response = LoadFeed(profile, config.DEFAULTS, request)
    else if requestType = UCase(GetConfiguredRequestType("RESOLVE_CONTENT", "RESOLVE_CONTENT"))
        m.top.response = ResolveContent(profile, config.DEFAULTS, request)
    else if requestType = UCase(GetConfiguredRequestType("EXECUTE_OPERATION", "EXECUTE_OPERATION"))
        m.top.response = ExecuteOperationRequest(profile, config.DEFAULTS, request)
    else
        m.top.response = ErrorResult("UNKNOWN_REQUEST_TYPE", false, "api-task", { "requestType": requestType })
    end if
end sub

function LoadFeed(profile as Object, defaults as Object, request as Object) as Object
    feedKey = GetStringValue(request, "feedKey", "")
    feed = FindFeed(profile, feedKey)
    if feed = invalid
        return ErrorResult("FEED_NOT_FOUND", false, "feed-loader", { "feedKey": feedKey })
    end if

    operationKey = GetStringValue(feed, "OPERATION", "")
    operation = FindOperation(profile, operationKey)
    if operation = invalid
        return ErrorResult("OPERATION_NOT_FOUND", false, "feed-loader", { "operationKey": operationKey, "feedKey": feedKey })
    end if

    context = ApiManager_MergeAssoc(GetAssocValue(request, "context"), {
        "feedKey": feed.KEY,
        "feedType": GetStringValue(feed, "TYPE", "content")
    })

    opResult = ExecuteOperation(profile, defaults, operationKey, operation, context, "feed-loader")
    if opResult.success = false then return opResult

    itemsPath = GetStringValue(GetAssocValue(operation, "EXTRACT"), "ITEMS_PATH", "")
    items = ApiManager_GetByPath(opResult.data.body, itemsPath)
    if items = invalid
        return ErrorResult("FEED_ITEMS_MISSING", false, "feed-loader", { "itemsPath": itemsPath, "feedKey": feedKey })
    end if

    if GetInterface(items, "ifArray") = invalid
        items = [items]
    end if

    normalizedItems = []
    for each rawItem in items
        normalizedItems.push(NormalizeContentItem(rawItem, profile, feed))
    end for

    return ApiManager_ResultSuccess({
        "feedKey": feed.KEY,
        "feedTitle": GetStringValue(feed, "TITLE", feed.KEY),
        "feedType": GetStringValue(feed, "TYPE", "content"),
        "items": normalizedItems
    }, "feed-loader")
end function

function ResolveContent(profile as Object, defaults as Object, request as Object) as Object
    content = GetAssocValue(request, "content")
    if content = invalid
        return ErrorResult("CONTENT_MISSING", false, "resolver")
    end if

    context = BuildResolverContext(content, GetAssocValue(request, "context"))
    resolver = GetAssocValue(content, "resolver")
    playback = GetAssocValue(content, "playback")

    existingPlaybackUrl = GetStringValue(playback, "url", "")
    if existingPlaybackUrl <> ""
        behavior = GetAssocValue(profile, "BEHAVIOR")
        defaultFormat = GetStringValue(behavior, "DEFAULT_STREAM_FORMAT", "hls")
        content.playback.format = ApiManager_DetectStreamFormat(existingPlaybackUrl, GetStringValue(playback, "format", defaultFormat))
        return ApiManager_ResultSuccess({ "content": content }, "resolver")
    end if

    behavior = GetAssocValue(profile, "BEHAVIOR")
    defaultStrategy = LCase(GetStringValue(behavior, "RESOLVER_DEFAULT_STRATEGY", "direct"))
    strategy = LCase(GetStringValue(resolver, "strategy", defaultStrategy))
    if strategy = "" then strategy = defaultStrategy

    resolverConfig = GetAssocValue(profile, "RESOLVER")
    resolverOps = GetAssocValue(resolverConfig, "OPERATIONS")

    if strategy = "direct"
        return ErrorResult("PLAYBACK_URL_MISSING", false, "resolver", { "strategy": strategy })
    else if strategy = "byurl"
        opKey = GetStringValue(resolverOps, "BY_URL", "")
        return ResolveWithOperation(profile, defaults, opKey, content, context)
    else if strategy = "byid"
        opKey = GetStringValue(resolverOps, "BY_ID", "")
        return ResolveWithOperation(profile, defaults, opKey, content, context)
    else if strategy = "multistep"
        pipeline = GetValueOrDefault(resolver, "pipeline", invalid)
        if GetInterface(pipeline, "ifArray") = invalid
            pipelines = GetAssocValue(resolverConfig, "PIPELINES")
            pipeline = GetValueOrDefault(pipelines, "DEFAULT", invalid)
        end if

        if GetInterface(pipeline, "ifArray") = invalid or pipeline.count() = 0
            return ErrorResult("PIPELINE_MISSING", false, "resolver")
        end if

        workingContent = content
        workingContext = context
        totalSteps = pipeline.count()
        stepIndex = 0
        for each step in pipeline
            stepKey = GetStringValue(step, "OPERATION", "")
            if stepKey = ""
                return ErrorResult("PIPELINE_STEP_INVALID", false, "resolver")
            end if

            requirePlayback = false
            if stepIndex = (totalSteps - 1)
                requirePlayback = true
            end if
            stepResult = ResolveWithOperation(profile, defaults, stepKey, workingContent, workingContext, requirePlayback)
            if stepResult.success = false then return stepResult
            workingContent = stepResult.data.content
            workingContext = BuildResolverContext(workingContent, workingContext)
            stepIndex = stepIndex + 1
        end for

        return ApiManager_ResultSuccess({ "content": workingContent }, "resolver")
    end if

    return ErrorResult("RESOLVER_STRATEGY_UNSUPPORTED", false, "resolver", { "strategy": strategy })
end function

function ResolveWithOperation(profile as Object, defaults as Object, operationKey as String, content as Object, context as Object, optional requirePlayback as Dynamic) as Object
    if operationKey = ""
        return ErrorResult("RESOLVER_OPERATION_MISSING", false, "resolver")
    end if

    operation = FindOperation(profile, operationKey)
    if operation = invalid
        return ErrorResult("RESOLVER_OPERATION_NOT_FOUND", false, "resolver", { "operationKey": operationKey })
    end if

    operationResult = ExecuteOperation(profile, defaults, operationKey, operation, context, "resolver")
    if operationResult.success = false then return operationResult

    resolvedContent = ApplyResolverExtract(content, operation, operationResult.data.body, profile)
    enforcePlayback = true
    if requirePlayback <> invalid
        if type(requirePlayback) = "Boolean" or type(requirePlayback) = "roBoolean"
            enforcePlayback = requirePlayback
        else
            enforcePlayback = LCase(requirePlayback.tostr()) = "true"
        end if
    end if

    if enforcePlayback
        playbackUrl = GetStringValue(GetAssocValue(resolvedContent, "playback"), "url", "")
        if playbackUrl = ""
            return ErrorResult("PLAYBACK_RESOLUTION_FAILED", true, "resolver", { "operationKey": operationKey })
        end if
    end if

    return ApiManager_ResultSuccess({ "content": resolvedContent }, "resolver")
end function

function ExecuteOperationRequest(profile as Object, defaults as Object, request as Object) as Object
    operationKey = GetStringValue(request, "operationKey", "")
    operation = FindOperation(profile, operationKey)
    if operation = invalid
        return ErrorResult("OPERATION_NOT_FOUND", false, "operation-exec", { "operationKey": operationKey })
    end if

    context = GetAssocValue(request, "context")
    return ExecuteOperation(profile, defaults, operationKey, operation, context, "operation-exec")
end function

function ExecuteOperation(profile as Object, defaults as Object, operationKey as String, operation as Object, context as Object, source as String) as Object
    requestConfig = GetAssocValue(operation, "REQUEST")
    if requestConfig = invalid
        return ErrorResult("REQUEST_CONFIG_MISSING", false, source, { "operationKey": operationKey })
    end if

    apiConfig = GetAssocValue(profile, "API")
    buildResult = ApiManager_BuildRequest(apiConfig, requestConfig, context, defaults)
    if buildResult.success = false then return buildResult

    resolvedRequest = buildResult.data
    retryPolicy = GetAssocValue(resolvedRequest, "retryPolicy")
    maxAttempts = Int(GetNumberValue(retryPolicy, "MAX_ATTEMPTS", 1))
    if maxAttempts < 1 then maxAttempts = 1

    attempt = 1
    lastError = invalid
    while attempt <= maxAttempts
        result = ExecuteSingleHttpRequest(resolvedRequest, source)
        if result.success
            extract = GetAssocValue(operation, "EXTRACT")
            dataPath = GetStringValue(extract, "DATA_PATH", "")
            if dataPath <> ""
                result.data.extracted = ApiManager_GetByPath(result.data.body, dataPath)
            else
                result.data.extracted = result.data.body
            end if
            return result
        end if

        lastError = result
        retryable = IsRetryableError(result)
        if retryable = false or attempt >= maxAttempts
            return result
        end if

        delayMs = GetBackoffDelayMs(retryPolicy, attempt)
        if delayMs > 0
            SleepMs(delayMs)
        end if

        attempt = attempt + 1
    end while

    if lastError <> invalid then return lastError
    return ErrorResult("REQUEST_FAILED", true, source, { "operationKey": operationKey })
end function

function ExecuteSingleHttpRequest(resolvedRequest as Object, source as String) as Object
    url = GetStringValue(resolvedRequest, "url", "")
    if url = ""
        return ErrorResult("URL_MISSING", false, source)
    end if

    method = UCase(GetStringValue(resolvedRequest, "method", "GET"))
    timeoutMs = Int(GetNumberValue(resolvedRequest, "timeoutMs", 10000))
    if timeoutMs <= 0 then timeoutMs = 10000

    ut = ApiManager_CreateUrlTransfer(url)
    port = CreateObject("roMessagePort")
    ut.SetPort(port)

    headers = GetAssocValue(resolvedRequest, "headers")
    if headers <> invalid
        for each key in headers
            ut.AddHeader(key, headers[key].tostr())
        end for
    end if

    queryParams = GetAssocValue(resolvedRequest, "queryParams")
    if queryParams <> invalid
        for each key in queryParams
            ut.AddQueryParameter(key, queryParams[key].tostr())
        end for
    end if

    started = false
    if method = "GET"
        started = ut.AsyncGetToString()
    else
        ut.SetRequest(method)
        body = GetValueOrDefault(resolvedRequest, "body", invalid)
        bodyString = ""
        if body <> invalid
            bodyType = LCase(type(body))
            if bodyType = "string" or bodyType = "rostring"
                bodyString = body.tostr()
            else
                bodyString = FormatJson(body)
            end if
        end if
        started = ut.AsyncPostFromString(bodyString)
    end if

    if started = false
        return ErrorResult("REQUEST_START_FAILED", true, source)
    end if

    msg = wait(timeoutMs, port)
    if type(msg) <> "roUrlEvent"
        return ErrorResult("REQUEST_TIMEOUT", true, source, { "timeoutMs": timeoutMs })
    end if

    statusCode = msg.GetResponseCode()
    responseBodyString = msg.GetString()
    parsedBody = ApiManager_ParseResponse(responseBodyString)
    if parsedBody = invalid
        parsedBody = { "rawBody": responseBodyString }
    end if

    if ApiManager_IsHttpSuccess(statusCode) = false
        return ErrorResult("HTTP_ERROR", statusCode >= 500, source, {
            "statusCode": statusCode,
            "body": parsedBody
        })
    end if

    return ApiManager_ResultSuccess({
        "statusCode": statusCode,
        "body": parsedBody,
        "rawBody": responseBodyString
    }, source)
end function

function ErrorResult(code as String, retryable as Boolean, source as String, optional details as Dynamic) as Object
    message = GetApiErrorMessage(code)
    return ApiManager_ResultError(code, message, retryable, source, details)
end function

function GetApiErrorMessage(code as String) as String
    app = GetAssocValue(m.config, "APP")
    errMap = GetAssocValue(app, "API_ERRORS")
    if errMap <> invalid and errMap.DoesExist(code)
        value = errMap.Lookup(code)
        if value <> invalid and value.tostr() <> ""
            return value.tostr()
        end if
    end if
    return code
end function

function GetConfiguredRequestType(key as String, fallback as String) as String
    if m.requestTypes = invalid then return fallback
    return GetStringValue(m.requestTypes, key, fallback)
end function

function NormalizeContentItem(rawItem as Object, profile as Object, feed as Object) as Object
    normalization = ApiManager_MergeAssoc(GetAssocValue(profile, "NORMALIZATION"), GetAssocValue(feed, "NORMALIZATION"))
    behavior = GetAssocValue(profile, "BEHAVIOR")

    contentId = GetStringByPath(rawItem, GetStringValue(normalization, "ID_PATH", ""), "")
    title = GetStringByPath(rawItem, GetStringValue(normalization, "TITLE_PATH", ""), "")
    if title = "" then title = "Untitled"
    thumb = GetStringByPath(rawItem, GetStringValue(normalization, "THUMB_PATH", ""), "")
    contentType = GetStringByPath(rawItem, GetStringValue(normalization, "TYPE_PATH", ""), GetStringValue(feed, "TYPE", "content"))

    playbackUrl = GetStringByPath(rawItem, GetStringValue(normalization, "PLAYBACK_URL_PATH", ""), "")
    playbackFormat = GetStringByPath(rawItem, GetStringValue(normalization, "PLAYBACK_FORMAT_PATH", ""), "")
    if playbackFormat = ""
        playbackFormat = GetStringValue(behavior, "DEFAULT_STREAM_FORMAT", "hls")
    end if

    resolverStrategy = LCase(GetStringByPath(rawItem, GetStringValue(normalization, "RESOLVER_STRATEGY_PATH", ""), ""))
    resolverUrl = GetStringByPath(rawItem, GetStringValue(normalization, "RESOLVER_URL_PATH", ""), "")
    resolverId = GetStringByPath(rawItem, GetStringValue(normalization, "RESOLVER_ID_PATH", ""), "")
    resolverPipeline = ApiManager_GetByPath(rawItem, GetStringValue(normalization, "RESOLVER_PIPELINE_PATH", ""))

    if resolverStrategy = ""
        if playbackUrl <> ""
            resolverStrategy = "direct"
        else if resolverUrl <> ""
            resolverStrategy = "byUrl"
        else if resolverId <> ""
            resolverStrategy = "byId"
        else
            resolverStrategy = LCase(GetStringValue(behavior, "RESOLVER_DEFAULT_STRATEGY", "direct"))
        end if
    end if

    drmType = GetStringByPath(rawItem, GetStringValue(normalization, "DRM_TYPE_PATH", ""), "")
    licenseUrl = GetStringByPath(rawItem, GetStringValue(normalization, "DRM_LICENSE_URL_PATH", ""), "")
    drmHeaders = ApiManager_GetByPath(rawItem, GetStringValue(normalization, "DRM_HEADERS_PATH", ""))
    if GetInterface(drmHeaders, "ifAssociativeArray") = invalid
        drmHeaders = {}
    end if

    normalized = {
        "id": contentId,
        "title": title,
        "thumb": thumb,
        "type": contentType,
        "playback": {
            "url": playbackUrl,
            "format": ApiManager_DetectStreamFormat(playbackUrl, playbackFormat)
        },
        "resolver": {
            "strategy": resolverStrategy,
            "url": resolverUrl,
            "id": resolverId
        },
        "drm": {
            "drmType": drmType,
            "licenseUrl": licenseUrl,
            "headers": drmHeaders
        },
        "meta": {
            "feedKey": GetStringValue(feed, "KEY", ""),
            "raw": rawItem
        }
    }

    if GetInterface(resolverPipeline, "ifArray") <> invalid and resolverPipeline.count() > 0
        normalized.resolver.pipeline = resolverPipeline
    end if

    return normalized
end function

function ApplyResolverExtract(content as Object, operation as Object, payload as Object, profile as Object) as Object
    updated = content
    extract = GetAssocValue(operation, "EXTRACT")
    if extract = invalid then return updated

    behavior = GetAssocValue(profile, "BEHAVIOR")
    defaultFormat = GetStringValue(behavior, "DEFAULT_STREAM_FORMAT", "hls")

    playback = ApiManager_MergeAssoc(GetAssocValue(updated, "playback"), {})
    resolver = ApiManager_MergeAssoc(GetAssocValue(updated, "resolver"), {})
    drm = ApiManager_MergeAssoc(GetAssocValue(updated, "drm"), {})

    playbackUrl = GetStringByPath(payload, GetStringValue(extract, "PLAYBACK_URL_PATH", ""), "")
    if playbackUrl <> ""
        playback.url = playbackUrl
    end if

    extractedFormat = GetStringByPath(payload, GetStringValue(extract, "PLAYBACK_FORMAT_PATH", ""), "")
    playback.format = ApiManager_DetectStreamFormat(GetStringValue(playback, "url", ""), ApiManager_ValueOr(extractedFormat, defaultFormat))

    resolverUrl = GetStringByPath(payload, GetStringValue(extract, "RESOLVER_URL_PATH", ""), "")
    if resolverUrl <> "" then resolver.url = resolverUrl

    resolverId = GetStringByPath(payload, GetStringValue(extract, "RESOLVER_ID_PATH", ""), "")
    if resolverId <> "" then resolver.id = resolverId

    drmType = GetStringByPath(payload, GetStringValue(extract, "DRM_TYPE_PATH", ""), "")
    if drmType <> "" then drm.drmType = drmType

    drmLicenseUrl = GetStringByPath(payload, GetStringValue(extract, "DRM_LICENSE_URL_PATH", ""), "")
    if drmLicenseUrl <> "" then drm.licenseUrl = drmLicenseUrl

    drmHeaders = ApiManager_GetByPath(payload, GetStringValue(extract, "DRM_HEADERS_PATH", ""))
    if GetInterface(drmHeaders, "ifAssociativeArray") <> invalid
        drm.headers = drmHeaders
    end if

    updated.playback = playback
    updated.resolver = resolver
    updated.drm = drm
    return updated
end function

function BuildResolverContext(content as Object, extraContext as Dynamic) as Object
    base = ApiManager_MergeAssoc(extraContext, {})
    base["contentId"] = GetStringValue(content, "id", "")
    base["title"] = GetStringValue(content, "title", "")
    base["resolverUrl"] = GetStringValue(GetAssocValue(content, "resolver"), "url", "")
    base["resolverId"] = GetStringValue(GetAssocValue(content, "resolver"), "id", "")
    base["playbackUrl"] = GetStringValue(GetAssocValue(content, "playback"), "url", "")
    return base
end function

function FindFeed(profile as Object, feedKey as String) as Dynamic
    feeds = GetValueOrDefault(profile, "FEEDS", invalid)
    if GetInterface(feeds, "ifArray") = invalid then return invalid

    for each feed in feeds
        if GetStringValue(feed, "KEY", "") = feedKey
            return feed
        end if
    end for

    return invalid
end function

function FindOperation(profile as Object, operationKey as String) as Dynamic
    if operationKey = "" then return invalid
    operations = GetAssocValue(profile, "OPERATIONS")
    if operations = invalid then return invalid

    if operations.DoesExist(operationKey)
        return operations.Lookup(operationKey)
    end if

    return invalid
end function

function GetAssocValue(obj as Dynamic, key as String) as Dynamic
    aa = GetInterface(obj, "ifAssociativeArray")
    if aa = invalid then return invalid
    if aa.DoesExist(key) = false then return invalid
    return aa.Lookup(key)
end function

function GetValueOrDefault(obj as Dynamic, key as String, fallback as Dynamic) as Dynamic
    value = GetAssocValue(obj, key)
    if value = invalid then return fallback
    return value
end function

function GetStringValue(obj as Dynamic, key as String, fallback as String) as String
    value = GetAssocValue(obj, key)
    if value = invalid then return fallback
    text = value.tostr()
    if text = "" then return fallback
    return text
end function

function GetNumberValue(obj as Dynamic, key as String, fallback as Integer) as Integer
    value = GetAssocValue(obj, key)
    if value = invalid then return fallback
    return Int(value)
end function

function GetStringByPath(payload as Dynamic, path as String, fallback as String) as String
    if path = invalid or path = "" then return fallback
    value = ApiManager_GetByPath(payload, path)
    if value = invalid then return fallback
    text = value.tostr()
    if text = "" then return fallback
    return text
end function

function IsRetryableError(result as Dynamic) as Boolean
    if result = invalid or result.success = true then return false
    err = GetAssocValue(result, "error")
    if err = invalid then return false
    retryable = GetValueOrDefault(err, "retryable", false)
    if retryable = true then return true
    return false
end function

function GetBackoffDelayMs(policy as Dynamic, attempt as Integer) as Integer
    maxAttemptIndex = attempt
    delay = 0

    delays = GetValueOrDefault(policy, "BACKOFF_MS", invalid)
    if GetInterface(delays, "ifArray") <> invalid and delays.count() >= maxAttemptIndex
        delay = Int(delays[maxAttemptIndex - 1])
        if delay < 0 then delay = 0
        return delay
    end if

    baseDelay = Int(GetValueOrDefault(policy, "BASE_DELAY_MS", 0))
    multiplier = Int(GetValueOrDefault(policy, "MULTIPLIER", 2))
    if multiplier < 1 then multiplier = 1
    if baseDelay <= 0 then return 0

    exponent = maxAttemptIndex - 1
    return baseDelay * (multiplier ^ exponent)
end function

sub SleepMs(ms as Integer)
    if ms <= 0 then return
    port = CreateObject("roMessagePort")
    wait(ms, port)
end sub
