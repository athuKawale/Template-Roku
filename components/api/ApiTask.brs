sub init()
    m.top.functionName = "runRequest"
end sub

sub runRequest()
    request = m.top.request
    if request = invalid return

    constants = GetConstants()
    ut = ApiManager_CreateUrlTransfer("")
    
    if request.type = "FETCH_CONTENT_LIST"
        if constants.API.BASE_URL = invalid or constants.API.BASE_URL = ""
            m.top.response = { "success": false, "error": "API base URL is not configured." }
            return
        end if

        ut.SetUrl(constants.API.BASE_URL)
        ut.AddHeader("Content-Type", "application/json")
        
        port = CreateObject("roMessagePort")
        ut.SetPort(port)
        
        payload = {
            query: constants.API.CONTENT_LIST_QUERY,
            variables: constants.API.CONTENT_LIST_VARIABLES
        }
        
        if ut.AsyncPostFromString(FormatJson(payload))
            msg = wait(10000, port)
            if type(msg) = "roUrlEvent"
                if msg.getResponseCode() = 200
                    json = ApiManager_ParseResponse(msg.GetString())
                    data = ApiManager_GetNestedValue(json, constants.API.CONTENT_LIST_PATH)
                    if data <> invalid and GetInterface(data, "ifArray") <> invalid
                        m.top.response = { "success": true, "data": data }
                    else
                        m.top.response = { "success": false, "error": "Invalid content list response structure" }
                    end if
                else
                    m.top.response = { "success": false, "error": "API Error: " + msg.getResponseCode().tostr() }
                end if
            else
                m.top.response = { "success": false, "error": "API Timeout" }
            end if
        else
            m.top.response = { "success": false, "error": "Failed to start API request" }
        end if

    else if request.type = "RESOLVE_PLAYBACK_URL"
        if request.url = invalid or request.url = ""
            m.top.response = { "success": false, "error": "Missing playback resolver URL." }
            return
        end if

        port = CreateObject("roMessagePort")
        ut.SetPort(port)
        ut.SetUrl(request.url)
        
        if ut.AsyncGetToString()
            msg = wait(10000, port)
            if type(msg) = "roUrlEvent"
                if msg.getResponseCode() = 200
                    json = ApiManager_ParseResponse(msg.GetString())
                    resolvedUrl = ApiManager_GetMappedValue(json, constants.API.FIELDS.STREAM_RESPONSE_URL)
                    if resolvedUrl <> invalid and resolvedUrl <> ""
                        m.top.response = { "success": true, "url": resolvedUrl }
                    else
                        m.top.response = { "success": false, "error": "Invalid playback URL response" }
                    end if
                else
                    m.top.response = { "success": false, "error": "Playback URL Error: " + msg.getResponseCode().tostr() }
                end if
            else
                m.top.response = { "success": false, "error": "Playback URL Timeout" }
            end if
        else
            m.top.response = { "success": false, "error": "Failed to start playback URL request" }
        end if
    end if
end sub
