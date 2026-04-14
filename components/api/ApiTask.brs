sub init()
    m.top.functionName = "runRequest"
end sub

sub runRequest()
    request = m.top.request
    if request = invalid then return

    constants = GetConstants()
    ut = ApiManager_CreateUrlTransfer("")
    ut.InitClientCertificates()
    ut.RetainBodyOnError(true)

    port = CreateObject("roMessagePort")
    ut.SetPort(port)

    ' TEMPLATE: Choose the protocol based on your API docs.
    '
    ' REST (GET with query params):
    '   url = constants.API.BASE_URL + "?section=" + request.section
    '   if request.params <> invalid
    '       for each key in request.params
    '           url = url + "&" + key + "=" + request.params[key]
    '       end for
    '   end if
    '   ut.SetUrl(url)
    '   ut.AddHeader("Accept", "application/json")
    '   success = ut.AsyncGetToString()
    '
    ' GraphQL (POST with query body):
    '   ut.SetUrl(constants.API.BASE_URL)
    '   ut.AddHeader("Content-Type", "application/json")
    '   payload = { query: request.query, variables: request.variables }
    '   success = ut.AsyncPostFromString(FormatJson(payload))
    '
    ' Default: REST GET pattern (replace if your API uses GraphQL)
    url = request.url
    if url = invalid or url = "" then url = constants.API.BASE_URL
    ut.SetUrl(url)
    ut.AddHeader("Accept", "application/json")

    if ut.AsyncGetToString()
        msg = wait(constants.API.TIMEOUT_MS, port)
        if type(msg) = "roUrlEvent"
            statusCode = msg.getResponseCode()
            if statusCode >= 200 and statusCode < 300
                json = ApiManager_ParseResponse(msg.GetString())
                if json <> invalid
                    m.top.response = { "success": true, "data": json }
                else
                    m.top.response = { "success": false, "error": "Invalid JSON structure" }
                end if
            else
                m.top.response = { "success": false, "error": "API Error: " + statusCode.tostr() }
            end if
        else
            m.top.response = { "success": false, "error": "API Timeout" }
        end if
    else
        m.top.response = { "success": false, "error": "Failed to start API request" }
    end if
end sub
