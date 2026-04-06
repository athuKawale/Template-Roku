sub init()
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.config = GetAppConfig()
end sub

sub onDataChange()
    data = m.top.contentItem
    if data = invalid return

    playback = getAssocValue(data, "playback")
    playbackUrl = getStringValue(playback, "url", "")
    if playbackUrl = "" return

    defaultFormat = "hls"
    profile = getAssocValue(m.config, "PROFILE")
    behavior = getAssocValue(profile, "BEHAVIOR")
    if behavior <> invalid
        defaultFormat = getStringValue(behavior, "DEFAULT_STREAM_FORMAT", "hls")
    end if

    configuredFormat = getStringValue(playback, "format", "")
    streamFormat = ApiManager_DetectStreamFormat(playbackUrl, ApiManager_ValueOr(configuredFormat, defaultFormat))

    content = CreateObject("roSGNode", "ContentNode")
    content.url = playbackUrl
    content.title = getStringValue(data, "title", "Untitled")
    content.streamformat = streamFormat

    drm = getAssocValue(data, "drm")
    if drm <> invalid
        drmType = getStringValue(drm, "drmType", "")
        licenseUrl = getStringValue(drm, "licenseUrl", "")
        drmHeaders = getAssocValue(drm, "headers")

        if drmType <> "" or licenseUrl <> ""
            drmParams = {}
            if drmType <> "" then drmParams.keySystem = drmType
            if licenseUrl <> "" then drmParams.licenseServerURL = licenseUrl
            if drmHeaders <> invalid then drmParams.headers = drmHeaders
            m.videoPlayer.drmParams = drmParams
        end if
    end if

    m.videoPlayer.content = content
    m.videoPlayer.control = "play"
    m.videoPlayer.setFocus(true)
end sub

function getAssocValue(obj as Dynamic, key as String) as Dynamic
    aa = GetInterface(obj, "ifAssociativeArray")
    if aa = invalid then return invalid
    if aa.DoesExist(key) = false then return invalid
    return aa.Lookup(key)
end function

function getStringValue(obj as Dynamic, key as String, fallback as String) as String
    value = getAssocValue(obj, key)
    if value = invalid then return fallback
    txt = value.tostr()
    if txt = "" then return fallback
    return txt
end function
