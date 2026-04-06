' Offline smoke tests for sample profiles.
' These tests do not hit the network; they validate config + mock payload flow:
' feed extraction -> normalization -> resolver extraction -> playback format inference.

function RunTemplateSmokeTests() as Object
    constants = GetConstants()
    profiles = constants.PROFILES
    results = {}

    for each profileName in profiles
        profile = profiles[profileName]
        results[profileName] = RunProfileSmokeTest(profileName, profile)
    end for

    return results
end function

function RunProfileSmokeTest(profileName as String, profile as Object) as Object
    errors = []

    homeMode = LCase(getStringByPath(profile, "BEHAVIOR.HOME_MODE", "feeds"))
    feed = invalid
    if homeMode = "single_operation"
        singleOperation = getStringByPath(profile, "BEHAVIOR.SINGLE_OPERATION", "")
        if singleOperation = ""
            errors.push("Single-operation mode requires BEHAVIOR.SINGLE_OPERATION.")
            return {
                "success": false,
                "errors": errors
            }
        end if

        feed = {
            "KEY": "single_operation",
            "TITLE": getStringByPath(profile, "BEHAVIOR.SINGLE_OPERATION_TITLE", "Single Operation"),
            "TYPE": getStringByPath(profile, "BEHAVIOR.SINGLE_OPERATION_TYPE", "content"),
            "OPERATION": singleOperation
        }
    else
        feed = GetFirstFeed(profile)
        if feed = invalid
            errors.push("No feeds configured.")
            return {
                "success": false,
                "errors": errors
            }
        end if
    end if

    feedOpKey = getStringValue(feed, "OPERATION", "")
    feedOp = getOperation(profile, feedOpKey)
    if feedOp = invalid
        errors.push("Feed operation missing: " + feedOpKey)
        return {
            "success": false,
            "errors": errors
        }
    end if

    feedMock = getByPath(profile, "SMOKE.FEED_MOCKS." + feedOpKey)
    if feedMock = invalid
        errors.push("Feed mock missing for operation: " + feedOpKey)
        return {
            "success": false,
            "errors": errors
        }
    end if

    itemsPath = getStringByPath(feedOp, "EXTRACT.ITEMS_PATH", "")
    items = smokeGetByPath(feedMock, itemsPath)
    if items = invalid
        errors.push("Items extraction failed at path: " + itemsPath)
        return {
            "success": false,
            "errors": errors
        }
    end if

    if GetInterface(items, "ifArray") = invalid
        items = [items]
    end if
    if items.count() = 0
        errors.push("Items extraction returned an empty array.")
        return {
            "success": false,
            "errors": errors
        }
    end if

    normalized = normalizeSmokeItem(items[0], profile, feed)
    if getStringValue(normalized, "id", "") = ""
        errors.push("Normalized content missing id.")
    end if
    if getStringValue(normalized, "title", "") = ""
        errors.push("Normalized content missing title.")
    end if

    resolved = resolveSmokeContent(profile, normalized)
    if resolved.success = false
        errors.push(resolved.message)
        return {
            "success": false,
            "errors": errors
        }
    end if

    playbackUrl = getStringByPath(resolved.content, "playback.url", "")
    if playbackUrl = ""
        errors.push("Resolved content missing playback URL.")
    end if

    playbackFormat = getStringByPath(resolved.content, "playback.format", "")
    if playbackFormat = ""
        errors.push("Resolved content missing playback format.")
    end if

    playerCheck = simulatePlayerStart(profile, resolved.content)
    if playerCheck.success = false
        errors.push(playerCheck.message)
    end if

    return {
        "success": errors.count() = 0,
        "errors": errors,
        "summary": {
            "profile": profileName,
            "feed": getStringValue(feed, "KEY", ""),
            "contentId": getStringValue(resolved.content, "id", ""),
            "playbackUrl": playbackUrl,
            "playbackFormat": playbackFormat,
            "playerStartValidated": playerCheck.success
        }
    }
end function

function simulatePlayerStart(profile as Object, content as Object) as Object
    playbackUrl = getStringByPath(content, "playback.url", "")
    if playbackUrl = ""
        return { "success": false, "message": "Player simulation failed: playback URL missing." }
    end if

    behavior = getByPath(profile, "BEHAVIOR")
    defaultFormat = getStringValue(behavior, "DEFAULT_STREAM_FORMAT", "hls")
    configuredFormat = getStringByPath(content, "playback.format", "")
    streamFormat = detectFormat(playbackUrl, pickNonEmpty(configuredFormat, defaultFormat))

    if streamFormat = ""
        return { "success": false, "message": "Player simulation failed: stream format missing." }
    end if

    if streamFormat <> "hls" and streamFormat <> "dash" and streamFormat <> "mp4" and streamFormat <> "ism"
        return { "success": false, "message": "Player simulation failed: unsupported stream format '" + streamFormat + "'." }
    end if

    simulatedNode = {
        "url": playbackUrl,
        "title": getStringValue(content, "title", "Untitled"),
        "streamformat": streamFormat
    }

    drmType = getStringByPath(content, "drm.drmType", "")
    licenseUrl = getStringByPath(content, "drm.licenseUrl", "")
    drmHeaders = getByPath(content, "drm.headers")
    if drmType <> "" or licenseUrl <> ""
        simulatedNode.drmParams = {
            "keySystem": drmType,
            "licenseServerURL": licenseUrl,
            "headers": drmHeaders
        }
    end if

    if simulatedNode.url = "" or simulatedNode.streamformat = ""
        return { "success": false, "message": "Player simulation failed: incomplete node payload." }
    end if

    return {
        "success": true,
        "node": simulatedNode
    }
end function

function resolveSmokeContent(profile as Object, content as Object) as Object
    playbackUrl = getStringByPath(content, "playback.url", "")
    if playbackUrl <> ""
        content.playback.format = detectFormat(playbackUrl, getStringByPath(content, "playback.format", "hls"))
        return {
            "success": true,
            "content": content
        }
    end if

    strategy = LCase(getStringByPath(content, "resolver.strategy", ""))
    resolverOps = getByPath(profile, "RESOLVER.OPERATIONS")

    if strategy = "byid"
        opKey = getStringValue(resolverOps, "BY_ID", "")
        return applyResolverMock(profile, opKey, content, true)
    else if strategy = "byurl"
        opKey = getStringValue(resolverOps, "BY_URL", "")
        return applyResolverMock(profile, opKey, content, true)
    else if strategy = "multistep"
        pipeline = getByPath(content, "resolver.pipeline")
        if GetInterface(pipeline, "ifArray") = invalid
            pipeline = getByPath(profile, "RESOLVER.PIPELINES.DEFAULT")
        end if
        if GetInterface(pipeline, "ifArray") = invalid or pipeline.count() = 0
            return { "success": false, "message": "Resolver pipeline missing for multistep strategy." }
        end if

        working = content
        totalSteps = pipeline.count()
        stepIndex = 0
        for each step in pipeline
            opKey = getStringValue(step, "OPERATION", "")
            requirePlayback = false
            if stepIndex = (totalSteps - 1)
                requirePlayback = true
            end if
            stepResult = applyResolverMock(profile, opKey, working, requirePlayback)
            if stepResult.success = false then return stepResult
            working = stepResult.content
            stepIndex = stepIndex + 1
        end for

        return { "success": true, "content": working }
    end if

    return { "success": false, "message": "Unsupported smoke resolver strategy: " + strategy }
end function

function applyResolverMock(profile as Object, operationKey as String, content as Object, optional requirePlayback as Dynamic) as Object
    if operationKey = ""
        return { "success": false, "message": "Resolver operation key missing." }
    end if

    operation = getOperation(profile, operationKey)
    if operation = invalid
        return { "success": false, "message": "Resolver operation missing: " + operationKey }
    end if

    resolverMock = getByPath(profile, "SMOKE.RESOLVER_MOCKS." + operationKey)
    if resolverMock = invalid
        return { "success": false, "message": "Resolver mock missing for operation: " + operationKey }
    end if

    extract = getByPath(operation, "EXTRACT")
    updated = content

    playbackUrlPath = getStringValue(extract, "PLAYBACK_URL_PATH", "")
    playbackFormatPath = getStringValue(extract, "PLAYBACK_FORMAT_PATH", "")
    resolverUrlPath = getStringValue(extract, "RESOLVER_URL_PATH", "")
    resolverIdPath = getStringValue(extract, "RESOLVER_ID_PATH", "")

    playbackUrl = ""
    if playbackUrlPath <> "" then playbackUrl = getStringByPath(resolverMock, playbackUrlPath, "")
    if playbackUrl <> ""
        updated.playback.url = playbackUrl
    end if

    formatValue = ""
    if playbackFormatPath <> "" then formatValue = getStringByPath(resolverMock, playbackFormatPath, "")
    updated.playback.format = detectFormat(getStringByPath(updated, "playback.url", ""), formatValue)

    if resolverUrlPath <> ""
        extractedResolverUrl = getStringByPath(resolverMock, resolverUrlPath, "")
        if extractedResolverUrl <> "" then updated.resolver.url = extractedResolverUrl
    end if

    if resolverIdPath <> ""
        extractedResolverId = getStringByPath(resolverMock, resolverIdPath, "")
        if extractedResolverId <> "" then updated.resolver.id = extractedResolverId
    end if

    enforcePlayback = true
    if requirePlayback <> invalid
        if type(requirePlayback) = "Boolean" or type(requirePlayback) = "roBoolean"
            enforcePlayback = requirePlayback
        else
            enforcePlayback = LCase(requirePlayback.tostr()) = "true"
        end if
    end if

    if enforcePlayback and getStringByPath(updated, "playback.url", "") = ""
        return { "success": false, "message": "Resolver operation '" + operationKey + "' did not produce playback URL." }
    end if

    return {
        "success": true,
        "content": updated
    }
end function

function normalizeSmokeItem(rawItem as Object, profile as Object, feed as Object) as Object
    mapping = getByPath(profile, "NORMALIZATION")
    behavior = getByPath(profile, "BEHAVIOR")

    item = {
        "id": getStringByPath(rawItem, getStringValue(mapping, "ID_PATH", "id"), ""),
        "title": getStringByPath(rawItem, getStringValue(mapping, "TITLE_PATH", "title"), "Untitled"),
        "thumb": getStringByPath(rawItem, getStringValue(mapping, "THUMB_PATH", "thumb"), ""),
        "type": getStringByPath(rawItem, getStringValue(mapping, "TYPE_PATH", "type"), getStringValue(feed, "TYPE", "content")),
        "playback": {
            "url": getStringByPath(rawItem, getStringValue(mapping, "PLAYBACK_URL_PATH", "playback.url"), ""),
            "format": getStringByPath(rawItem, getStringValue(mapping, "PLAYBACK_FORMAT_PATH", "playback.format"), getStringValue(behavior, "DEFAULT_STREAM_FORMAT", "hls"))
        },
        "resolver": {
            "strategy": getStringByPath(rawItem, getStringValue(mapping, "RESOLVER_STRATEGY_PATH", "resolver.strategy"), ""),
            "url": getStringByPath(rawItem, getStringValue(mapping, "RESOLVER_URL_PATH", "resolver.url"), ""),
            "id": getStringByPath(rawItem, getStringValue(mapping, "RESOLVER_ID_PATH", "resolver.id"), "")
        },
        "drm": {
            "drmType": getStringByPath(rawItem, getStringValue(mapping, "DRM_TYPE_PATH", "drm.type"), ""),
            "licenseUrl": getStringByPath(rawItem, getStringValue(mapping, "DRM_LICENSE_URL_PATH", "drm.licenseUrl"), ""),
            "headers": getByPath(rawItem, getStringValue(mapping, "DRM_HEADERS_PATH", "drm.headers"))
        }
    }

    if item.resolver.strategy = ""
        if item.playback.url <> ""
            item.resolver.strategy = "direct"
        else if item.resolver.url <> ""
            item.resolver.strategy = "byUrl"
        else if item.resolver.id <> ""
            item.resolver.strategy = "byId"
        else
            item.resolver.strategy = LCase(getStringValue(behavior, "RESOLVER_DEFAULT_STRATEGY", "direct"))
        end if
    end if

    if item.playback.url <> ""
        item.playback.format = detectFormat(item.playback.url, item.playback.format)
    end if

    pipelinePath = getStringValue(mapping, "RESOLVER_PIPELINE_PATH", "")
    if pipelinePath <> ""
        pipeline = getByPath(rawItem, pipelinePath)
        if GetInterface(pipeline, "ifArray") <> invalid and pipeline.count() > 0
            item.resolver.pipeline = pipeline
        end if
    end if

    return item
end function

function detectFormat(url as String, fallback as String) as String
    lower = LCase(url)
    if Instr(1, lower, ".m3u8") > 0 then return "hls"
    if Instr(1, lower, ".mpd") > 0 then return "dash"
    if Instr(1, lower, ".mp4") > 0 then return "mp4"
    if fallback <> "" then return fallback
    return "hls"
end function

function pickNonEmpty(firstValue as String, fallback as String) as String
    if firstValue <> "" then return firstValue
    return fallback
end function

function smokeGetByPath(payload as Dynamic, path as String) as Dynamic
    if path = "" then return payload
    return getByPath(payload, path)
end function

function getOperation(profile as Object, operationKey as String) as Dynamic
    operations = getByPath(profile, "OPERATIONS")
    if operations = invalid then return invalid
    if operations.DoesExist(operationKey) = false then return invalid
    return operations.Lookup(operationKey)
end function

function GetFirstFeed(profile as Object) as Dynamic
    feeds = getByPath(profile, "FEEDS")
    if GetInterface(feeds, "ifArray") = invalid or feeds.count() = 0
        return invalid
    end if
    return feeds[0]
end function

function getByPath(payload as Dynamic, path as String) as Dynamic
    if payload = invalid then return invalid
    if path = invalid or path = "" then return payload

    tokens = []
    currentToken = ""
    i = 1
    while i <= Len(path)
        ch = Mid(path, i, 1)
        if ch = "."
            if currentToken <> ""
                tokens.push(currentToken)
                currentToken = ""
            end if
        else if ch = "["
            if currentToken <> ""
                tokens.push(currentToken)
                currentToken = ""
            end if
            closePos = Instr(i + 1, path, "]")
            if closePos = 0 then return invalid
            idxText = Mid(path, i + 1, closePos - i - 1)
            tokens.push(Int(Val(idxText)))
            i = closePos
        else
            currentToken = currentToken + ch
        end if
        i = i + 1
    end while
    if currentToken <> "" then tokens.push(currentToken)

    current = payload
    for each token in tokens
        tokenType = LCase(type(token))
        if tokenType = "integer" or tokenType = "float" or tokenType = "double"
            arr = GetInterface(current, "ifArray")
            if arr = invalid or token < 0 or token >= arr.count() then return invalid
            current = arr[token]
        else
            aa = GetInterface(current, "ifAssociativeArray")
            if aa = invalid or aa.DoesExist(token.tostr()) = false then return invalid
            current = aa.Lookup(token.tostr())
        end if
    end for

    return current
end function

function getStringByPath(payload as Dynamic, path as String, fallback as String) as String
    value = getByPath(payload, path)
    if value = invalid then return fallback
    txt = value.tostr()
    if txt = "" then return fallback
    return txt
end function

function getStringValue(obj as Dynamic, key as String, fallback as String) as String
    aa = GetInterface(obj, "ifAssociativeArray")
    if aa = invalid or aa.DoesExist(key) = false then return fallback
    value = aa.Lookup(key)
    if value = invalid then return fallback
    txt = value.tostr()
    if txt = "" then return fallback
    return txt
end function
