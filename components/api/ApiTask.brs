sub init()
    m.top.functionName = "runRequest"
end sub

sub runRequest()
    request = m.top.request
    if request = invalid return

    constants = GetConstants()
    ut = ApiManager_CreateUrlTransfer("")
    
    if request.type = "CHANNEL_LIST"
        ut.SetUrl(constants.API.BASE_URL)
        ut.AddHeader("Content-Type", "application/json")
        
        port = CreateObject("roMessagePort")
        ut.SetPort(port)
        
        payload = {
            query: constants.API.CHANNEL_LIST_QUERY,
            variables: constants.API.CHANNEL_LIST_VARIABLES
        }
        
        if ut.AsyncPostFromString(FormatJson(payload))
            msg = wait(10000, port)
            if type(msg) = "roUrlEvent"
                if msg.getResponseCode() = 200
                    json = ApiManager_ParseResponse(msg.GetString())
                    if json <> invalid and json.data <> invalid and json.data.ctvChannelList <> invalid
                        m.top.response = { "success": true, "data": json.data.ctvChannelList.data }
                    else
                        m.top.response = { "success": false, "error": "Invalid JSON structure" }
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

    else if request.type = "GET_LIVE_URL"
        port = CreateObject("roMessagePort")
        ut.SetPort(port)
        ut.SetUrl(request.url)
        
        if ut.AsyncGetToString()
            msg = wait(10000, port)
            if type(msg) = "roUrlEvent"
                if msg.getResponseCode() = 200
                    json = ApiManager_ParseResponse(msg.GetString())
                    if json <> invalid and json.hls <> invalid
                        m.top.response = { "success": true, "url": json.hls }
                    else
                        m.top.response = { "success": false, "error": "Invalid Live URL JSON" }
                    end if
                else
                    m.top.response = { "success": false, "error": "Live URL Error: " + msg.getResponseCode().tostr() }
                end if
            else
                m.top.response = { "success": false, "error": "Live URL Timeout" }
            end if
        else
            m.top.response = { "success": false, "error": "Failed to start Live URL request" }
        end if
    end if
end sub
