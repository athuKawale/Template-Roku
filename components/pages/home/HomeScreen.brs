sub init()
    m.constants = GetConstants()
    m.apiFields = m.constants.API.FIELDS
    m.statusLabel = m.top.findNode("statusLabel")
    m.statusLabel.text = m.constants.APP.LOADING_TEXT
    loadContent()
end sub

sub loadContent()
    if isApiConfigured() = false
        m.statusLabel.text = m.constants.APP.CONFIG_HINT
        return
    end if

    TaskOrchestrator_RunTask("ApiTask", { "request": { "type": "FETCH_CONTENT_LIST" } }, "onContentListResponse")
end sub

sub onContentListResponse(event as Object)
    response = event.getData()
    if response.success = true
        items = response.data
        if items.count() > 0
            item = normalizeContentItem(items[0])

            if item.playbackUrl <> ""
                m.statusLabel.text = m.constants.APP.PLAYING_TEXT_PREFIX + item.title + "..."
                m.top.selectedContent = item
            else if item.resolverUrl <> ""
                m.statusLabel.text = m.constants.APP.RESOLVING_TEXT_PREFIX + item.title + "..."
                resolvePlaybackUrl(item)
            else
                m.statusLabel.text = m.constants.APP.UNPLAYABLE_TEXT
            end if
        else
            m.statusLabel.text = m.constants.APP.EMPTY_TEXT
        end if
    else
        m.statusLabel.text = "Error: " + response.error
    end if
end sub

sub resolvePlaybackUrl(item as Object)
    m.currentItem = item
    TaskOrchestrator_RunTask("ApiTask", { "request": { "type": "RESOLVE_PLAYBACK_URL", "url": item.resolverUrl } }, "onPlaybackUrlResponse")
end sub

sub onPlaybackUrlResponse(event as Object)
    response = event.getData()
    if response.success = true
        m.currentItem.playbackUrl = response.url
        m.top.selectedContent = m.currentItem
    else
        m.statusLabel.text = "Error resolving playback URL: " + response.error
    end if
end sub

function isApiConfigured() as Boolean
    baseUrl = m.constants.API.BASE_URL
    if baseUrl = invalid or baseUrl = "" return false
    if Instr(1, baseUrl, "example.com") > 0 return false

    return true
end function

function normalizeContentItem(item as Object) as Object
    return {
        "title": getMappedField(item, m.apiFields.TITLE, "Untitled Item"),
        "playbackUrl": getMappedField(item, m.apiFields.PLAYBACK_URL, ""),
        "resolverUrl": getMappedField(item, m.apiFields.RESOLVER_URL, ""),
        "rawData": item
    }
end function

function getMappedField(item as Object, fieldName as String, defaultValue as Dynamic) as Dynamic
    aa = GetInterface(item, "ifAssociativeArray")
    if aa <> invalid and aa.DoesExist(fieldName)
        value = aa.Lookup(fieldName)
        if value <> invalid then return value
    end if

    return defaultValue
end function
