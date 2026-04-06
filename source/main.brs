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

    if Main_ShouldRunSmokeTests(args, config) = false
        return { "success": true }
    end if

    ? Main_GetText(text, "SMOKE_STARTED", "Running startup smoke checks...")
    smoke = Main_RunSmokeChecks(args, config)
    if smoke.success
        ? Main_GetText(text, "SMOKE_PASSED", "Startup smoke checks passed.")
        return { "success": true }
    end if

    failureMessage = Main_GetText(text, "SMOKE_FAILED_PREFIX", "Startup smoke checks failed: ") + smoke.message
    doneRule = Main_GetStringValue(Main_GetAssocValue(config, "APP"), "DONE_RULE", "")
    if doneRule <> ""
        failureMessage = failureMessage + " | Done rule: " + doneRule
    end if
    ? failureMessage

    if Main_ShouldFailOnSmokeError(args, config)
        return {
            "success": false,
            "message": failureMessage
        }
    end if

    return { "success": true }
end function

function Main_RunSmokeChecks(args as Dynamic, config as Object) as Object
    runAllProfiles = Main_ShouldRunAllProfiles(args, config)
    if runAllProfiles
        summary = Main_SummarizeSmokeResults(RunTemplateSmokeTests())
        return summary
    end if

    profileName = Main_GetStringValue(config, "ACTIVE_PROFILE", "")
    profile = Main_GetAssocValue(config, "PROFILE")
    profileResult = RunProfileSmokeTest(profileName, profile)
    singleResult = {}
    singleResult[profileName] = profileResult
    return Main_SummarizeSmokeResults(singleResult)
end function

function Main_ShouldRunSmokeTests(args as Dynamic, config as Object) as Boolean
    argValue = Main_GetAssocValue(args, "runSmokeTests")
    if argValue <> invalid then return Main_ToBoolean(argValue, false)

    startup = Main_GetAssocValue(Main_GetAssocValue(config, "DEFAULTS"), "STARTUP")
    return Main_ToBoolean(Main_GetAssocValue(startup, "RUN_SMOKE_TESTS"), false)
end function

function Main_ShouldRunAllProfiles(args as Dynamic, config as Object) as Boolean
    argValue = Main_GetAssocValue(args, "runAllProfileSmokeTests")
    if argValue <> invalid then return Main_ToBoolean(argValue, true)

    startup = Main_GetAssocValue(Main_GetAssocValue(config, "DEFAULTS"), "STARTUP")
    return Main_ToBoolean(Main_GetAssocValue(startup, "RUN_ALL_PROFILES"), true)
end function

function Main_ShouldFailOnSmokeError(args as Dynamic, config as Object) as Boolean
    argValue = Main_GetAssocValue(args, "failOnSmokeError")
    if argValue <> invalid then return Main_ToBoolean(argValue, true)

    startup = Main_GetAssocValue(Main_GetAssocValue(config, "DEFAULTS"), "STARTUP")
    return Main_ToBoolean(Main_GetAssocValue(startup, "FAIL_ON_SMOKE_ERROR"), true)
end function

function Main_SummarizeSmokeResults(results as Dynamic) as Object
    failures = []
    allPassed = true

    resultsAA = GetInterface(results, "ifAssociativeArray")
    if resultsAA = invalid
        return {
            "success": false,
            "message": "Smoke checks returned invalid results."
        }
    end if

    for each profileName in results
        result = results[profileName]
        if Main_ToBoolean(Main_GetAssocValue(result, "success"), false) = false
            allPassed = false
            errors = Main_GetAssocValue(result, "errors")
            message = ""
            if GetInterface(errors, "ifArray") <> invalid and errors.count() > 0
                message = Main_JoinStrings(errors)
            end if
            if message = "" then message = "Unknown smoke failure."
            failures.push(profileName + ": " + message)
        end if
    end for

    return {
        "success": allPassed,
        "message": Main_JoinStrings(failures)
    }
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

function Main_ToBoolean(value as Dynamic, fallback as Boolean) as Boolean
    if value = invalid then return fallback
    valueType = type(value)
    if valueType = "Boolean" or valueType = "roBoolean"
        return value
    end if

    text = LCase(value.tostr())
    if text = "true" or text = "1" or text = "yes" then return true
    if text = "false" or text = "0" or text = "no" then return false
    return fallback
end function

function Main_JoinStrings(values as Dynamic) as String
    if GetInterface(values, "ifArray") = invalid or values.count() = 0
        return ""
    end if

    output = ""
    for each value in values
        if output <> "" then output = output + " | "
        output = output + value.tostr()
    end for
    return output
end function
