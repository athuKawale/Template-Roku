sub init()
    m.config = GetAppConfig()
    m.text = GetAssocValue(m.config.APP, "TEXT")
    validation = ValidateAppConfig(m.config)

    m.statusLabel = m.top.findNode("statusLabel")
    m.rails = {}
    m.feedQueue = []
    m.feedErrors = []
    m.pendingPlaybackItem = invalid
    m.singleOperationExecuted = false

    setStatus(getText("INITIAL_STATUS"))

    if validation.valid = false
        setStatus(getText("VALIDATION_FAILED_PREFIX") + validation.message)
        return
    end if

    m.profile = m.config.PROFILE
    m.requestTypes = GetValueOrDefault(m.config.DEFAULTS, "REQUEST_TYPES", {})

    setStatus(getText("LOADING_FEEDS"))
    queueFeeds()
    loadNextFeed()
end sub

sub queueFeeds()
    feeds = GetValueOrDefault(m.profile, "FEEDS", invalid)
    if GetInterface(feeds, "ifArray") = invalid then return

    orderedFeeds = getFeedLoadOrder(feeds)
    for each feed in orderedFeeds
        m.feedQueue.push(feed)
    end for
end sub

sub loadNextFeed()
    if m.feedQueue.count() = 0
        if shouldRunSingleOperation()
            runSingleOperationMode()
            return
        end if
        onAllFeedsLoaded()
        return
    end if

    nextFeed = m.feedQueue[0]
    m.feedQueue.delete(0)

    feedKey = GetStringValue(nextFeed, "KEY", "")
    feedTitle = GetStringValue(nextFeed, "TITLE", feedKey)
    setStatus(getText("LOADING_FEED_PREFIX") + feedTitle + "...")

    request = {
        "type": getRequestType("LOAD_FEED", "LOAD_FEED"),
        "feedKey": feedKey
    }
    m.activeTask = TaskOrchestrator_RunTask("ApiTask", { "request": request }, "onFeedResponse")
end sub

sub onFeedResponse(event as Object)
    response = event.getData()
    if response = invalid
        m.feedErrors.push(getText("FEED_RESPONSE_INVALID"))
        loadNextFeed()
        return
    end if

    if response.success = true
        rail = response.data
        if rail <> invalid
            m.rails[rail.feedKey] = rail
        end if
        m.top.railsData = m.rails
    else
        m.feedErrors.push(getErrorDisplay(response, "FEED_LOAD_FAILED"))
    end if

    loadNextFeed()
end sub

sub runSingleOperationMode()
    m.singleOperationExecuted = true

    behavior = GetValueOrDefault(m.profile, "BEHAVIOR", {})
    operationKey = GetStringValue(behavior, "SINGLE_OPERATION", "")
    if operationKey = ""
        m.feedErrors.push(getText("NO_FEEDS"))
        onAllFeedsLoaded()
        return
    end if

    setStatus(getText("LOADING_FEED_PREFIX") + operationKey + "...")

    request = {
        "type": getRequestType("EXECUTE_OPERATION", "EXECUTE_OPERATION"),
        "operationKey": operationKey,
        "normalizeItems": true,
        "feedKey": "single_operation",
        "feedTitle": GetStringValue(behavior, "SINGLE_OPERATION_TITLE", "Single Operation"),
        "feedType": GetStringValue(behavior, "SINGLE_OPERATION_TYPE", "content"),
        "context": GetValueOrDefault(behavior, "SINGLE_OPERATION_CONTEXT", invalid)
    }
    m.activeTask = TaskOrchestrator_RunTask("ApiTask", { "request": request }, "onSingleOperationResponse")
end sub

sub onSingleOperationResponse(event as Object)
    response = event.getData()
    if response = invalid
        m.feedErrors.push(getText("FEED_RESPONSE_INVALID"))
        onAllFeedsLoaded()
        return
    end if

    if response.success = true
        rail = response.data
        if rail <> invalid
            feedKey = GetStringValue(rail, "feedKey", "single_operation")
            m.rails[feedKey] = {
                "feedKey": feedKey,
                "feedTitle": GetStringValue(rail, "feedTitle", "Single Operation"),
                "feedType": GetStringValue(rail, "feedType", "content"),
                "items": GetValueOrDefault(rail, "items", [])
            }
        end if
        m.top.railsData = m.rails
    else
        m.feedErrors.push(getErrorDisplay(response, "FEED_LOAD_FAILED"))
    end if

    onAllFeedsLoaded()
end sub

sub onAllFeedsLoaded()
    if m.rails.count() = 0
        if m.feedErrors.count() > 0
            setStatus(getText("ERROR_PREFIX") + m.feedErrors[0])
        else
            setStatus(getText("NO_FEEDS"))
        end if
        return
    end if

    behavior = GetValueOrDefault(m.profile, "BEHAVIOR", {})
    autoPlay = GetValueOrDefault(behavior, "AUTO_PLAY", {})
    autoPlayEnabled = GetBoolValue(autoPlay, "ENABLED", true)

    if autoPlayEnabled = false
        setStatus(getText("READY_NO_AUTOPLAY"))
        return
    end if

    candidate = selectAutoplayCandidate()
    if candidate = invalid
        setStatus(getText("NO_PLAYABLE"))
        return
    end if

    beginPlayback(candidate)
end sub

function selectAutoplayCandidate() as Dynamic
    behavior = GetValueOrDefault(m.profile, "BEHAVIOR", {})
    autoPlay = GetValueOrDefault(behavior, "AUTO_PLAY", {})
    priorities = GetValueOrDefault(autoPlay, "RAIL_PRIORITY", invalid)
    selectionMode = LCase(GetStringValue(autoPlay, "SELECTION_MODE", "firstPlayable"))

    if GetInterface(priorities, "ifArray") <> invalid and priorities.count() > 0
        for each key in priorities
            if selectionMode = "first"
                item = firstItemFromRail(key.tostr())
            else
                item = firstPlayableFromRail(key.tostr())
            end if
            if item <> invalid then return item
        end for
    end if

    for each railKey in m.rails
        if selectionMode = "first"
            item = firstItemFromRail(railKey)
        else
            item = firstPlayableFromRail(railKey)
        end if
        if item <> invalid then return item
    end for

    return invalid
end function

function firstItemFromRail(railKey as String) as Dynamic
    if m.rails.DoesExist(railKey) = false then return invalid
    rail = m.rails[railKey]
    items = GetValueOrDefault(rail, "items", invalid)
    if GetInterface(items, "ifArray") = invalid or items.count() = 0 then return invalid
    return items[0]
end function

function firstPlayableFromRail(railKey as String) as Dynamic
    if m.rails.DoesExist(railKey) = false then return invalid
    rail = m.rails[railKey]
    items = GetValueOrDefault(rail, "items", invalid)
    if GetInterface(items, "ifArray") = invalid then return invalid

    fallback = invalid
    for each item in items
        if fallback = invalid then fallback = item
        if canResolveOrPlay(item) then return item
    end for

    return fallback
end function

function canResolveOrPlay(item as Object) as Boolean
    playback = GetValueOrDefault(item, "playback", {})
    resolver = GetValueOrDefault(item, "resolver", {})

    if GetStringValue(playback, "url", "") <> "" then return true
    strategy = LCase(GetStringValue(resolver, "strategy", ""))
    if strategy = "direct" then return false
    if strategy = "byurl" and GetStringValue(resolver, "url", "") <> "" then return true
    if strategy = "byid" and GetStringValue(resolver, "id", "") <> "" then return true
    if strategy = "multistep" then return true

    if GetStringValue(resolver, "url", "") <> "" then return true
    if GetStringValue(resolver, "id", "") <> "" then return true
    return false
end function

sub beginPlayback(item as Object)
    title = GetStringValue(item, "title", "item")
    playback = GetValueOrDefault(item, "playback", {})

    if GetStringValue(playback, "url", "") <> ""
        setStatus(getText("PLAYING_PREFIX") + title + "...")
        m.top.selectedContent = item
        return
    end if

    setStatus(getText("RESOLVING_PREFIX") + title + "...")
    m.pendingPlaybackItem = item

    request = {
        "type": getRequestType("RESOLVE_CONTENT", "RESOLVE_CONTENT"),
        "content": item,
        "context": {
            "contentId": GetStringValue(item, "id", ""),
            "resolverUrl": GetStringValue(GetValueOrDefault(item, "resolver", {}), "url", "")
        }
    }
    m.activeTask = TaskOrchestrator_RunTask("ApiTask", { "request": request }, "onResolveResponse")
end sub

function getFeedLoadOrder(feeds as Object) as Object
    if isSingleOperationMode()
        return []
    end if

    behavior = GetValueOrDefault(m.profile, "BEHAVIOR", {})
    orderedKeys = GetValueOrDefault(behavior, "FEED_LOAD_ORDER", invalid)
    if GetInterface(orderedKeys, "ifArray") = invalid or orderedKeys.count() = 0
        return feeds
    end if

    ordered = []
    feedByKey = {}
    for each feed in feeds
        key = GetStringValue(feed, "KEY", "")
        if key <> ""
            feedByKey[key] = feed
        end if
    end for

    for each key in orderedKeys
        keyText = key.tostr()
        if feedByKey.DoesExist(keyText)
            ordered.push(feedByKey[keyText])
            feedByKey.Delete(keyText)
        end if
    end for

    for each leftoverKey in feedByKey
        ordered.push(feedByKey[leftoverKey])
    end for

    return ordered
end function

function isSingleOperationMode() as Boolean
    behavior = GetValueOrDefault(m.profile, "BEHAVIOR", {})
    mode = LCase(GetStringValue(behavior, "HOME_MODE", "feeds"))
    return mode = "single_operation"
end function

function shouldRunSingleOperation() as Boolean
    if m.singleOperationExecuted then return false
    if isSingleOperationMode() = false then return false

    behavior = GetValueOrDefault(m.profile, "BEHAVIOR", {})
    operationKey = GetStringValue(behavior, "SINGLE_OPERATION", "")
    return operationKey <> ""
end function

function getRequestType(key as String, fallback as String) as String
    if m.requestTypes = invalid then return fallback
    return GetStringValue(m.requestTypes, key, fallback)
end function

sub onResolveResponse(event as Object)
    response = event.getData()
    if response = invalid
        setStatus(getText("ERROR_PREFIX") + getText("RESOLVER_RESPONSE_INVALID"))
        return
    end if

    if response.success = false
        setStatus(getText("ERROR_PREFIX") + getErrorDisplay(response, "RESOLUTION_FAILED"))
        return
    end if

    resolvedContent = GetValueOrDefault(response.data, "content", invalid)
    if resolvedContent = invalid
        setStatus(getText("ERROR_PREFIX") + getText("RESOLVER_EMPTY_CONTENT"))
        return
    end if

    title = GetStringValue(resolvedContent, "title", "item")
    setStatus(getText("PLAYING_PREFIX") + title + "...")
    m.top.selectedContent = resolvedContent
end sub

sub setStatus(message as String)
    m.statusLabel.text = message
end sub

function getText(key as String) as String
    if m.text = invalid then return key
    value = GetValueOrDefault(m.text, key, invalid)
    if value = invalid then return key
    text = value.tostr()
    if text = "" then return key
    return text
end function

function getErrorDisplay(response as Object, fallbackTextKey as String) as String
    fallback = getText(fallbackTextKey)
    err = GetValueOrDefault(response, "error", invalid)
    if err = invalid then return fallback

    code = GetStringValue(err, "code", "")
    message = GetStringValue(err, "message", "")
    source = GetStringValue(err, "source", "")
    retryable = GetBoolValue(err, "retryable", false)

    if message = "" then message = fallback

    output = ""
    if code <> ""
        output = code + ": "
    end if
    output = output + message
    if source <> ""
        output = output + " (" + source + ")"
    end if
    if retryable
        output = output + " [retryable]"
    end if
    return output
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

function GetBoolValue(obj as Dynamic, key as String, fallback as Boolean) as Boolean
    value = GetAssocValue(obj, key)
    if value = invalid then return fallback
    if type(value) = "roBoolean" or type(value) = "Boolean"
        return value
    end if
    txt = LCase(value.tostr())
    if txt = "true" then return true
    if txt = "false" then return false
    return fallback
end function
