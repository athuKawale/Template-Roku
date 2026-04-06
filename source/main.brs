sub Main(args as object)
    startup = RunStartupChecks(args)
    if startup.success = false
        ? startup.message
        return
    end if

    showAppSGScreen(args)
end sub

sub showAppSGScreen(args as object)
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    scene = screen.CreateScene("MainScene")
    scene.launchArgs = args
    screen.show()

    while(true)
        msg = wait(0, m.port)
        if type(msg) = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub

function RunStartupChecks(args as Dynamic) as Object
    config = GetAppConfig()
    text = Main_GetStartupText(config)

    validation = ValidateAppConfig(config)
    if validation.valid = false
        return {
            "success": false,
            "message": Main_GetText(text, "STARTUP_CONFIG_FAILED_PREFIX", "Startup configuration failed: ") + validation.message
        }
    end if

    return { "success": true }
end function

function Main_GetStartupText(config as Object) as Dynamic
    app = Main_GetAssocValue(config, "APP")
    return Main_GetAssocValue(app, "TEXT")
end function

function Main_GetText(textMap as Dynamic, key as String, fallback as String) as String
    value = Main_GetAssocValue(textMap, key)
    if value = invalid then return fallback
    txt = value.tostr()
    if txt = "" then return fallback
    return txt
end function

function Main_GetAssocValue(obj as Dynamic, key as String) as Dynamic
    aa = GetInterface(obj, "ifAssociativeArray")
    if aa = invalid then return invalid
    if aa.DoesExist(key) = false then return invalid
    return aa.Lookup(key)
end function

function Main_GetStringValue(obj as Dynamic, key as String, fallback as String) as String
    value = Main_GetAssocValue(obj, key)
    if value = invalid then return fallback
    text = value.tostr()
    if text = "" then return fallback
    return text
end function
