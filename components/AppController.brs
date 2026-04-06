sub init()
    m.config = GetAppConfig()
    app = getAssocValue(m.config, "APP")
    m.screens = getAssocValue(app, "SCREENS")
    m.screenContainer = m.top.findNode("screenContainer")
    m.screenStack = []
    
    ' Launch the initial screen
    showHomeScreen()
end sub

sub showHomeScreen()
    homeScreen = CreateObject("roSGNode", getScreenName("HOME", "HomeScreen"))
    homeScreen.observeField("selectedContent", "onContentSelected")
    pushScreen(homeScreen)
end sub

sub onContentSelected(event as Object)
    contentItem = event.getData()
    playerScreen = CreateObject("roSGNode", getScreenName("PLAYER", "PlayerScreen"))
    playerScreen.contentItem = contentItem
    pushScreen(playerScreen)
end sub

' --- Navigation Engine ---

sub pushScreen(newScreen as Object)
    if newScreen = invalid return
    
    ' Hide current screen if any
    if m.screenStack.count() > 0
        current = m.screenStack.peek()
        current.visible = false
    end if
    
    m.screenStack.push(newScreen)
    m.screenContainer.appendChild(newScreen)
    newScreen.visible = true
    newScreen.setFocus(true)
end sub

sub popScreen()
    if m.screenStack.count() <= 1 return ' Don't pop the last screen (Home)
    
    topScreen = m.screenStack.pop()
    m.screenContainer.removeChild(topScreen)
    
    ' Show previous screen
    prev = m.screenStack.peek()
    prev.visible = true
    prev.setFocus(true)
end sub

' Interface Handlers
sub onPushScreen()
    pushScreen(m.top.pushScreen)
end sub

sub onPopScreen()
    popScreen()
end sub

sub onLaunchArgsChange()
    args = m.top.launchArgs
    ' Handle launch routing here (for example, auto-opening an item)
    if args <> invalid and args.targetId <> invalid
        ? "Launch targetId: "; args.targetId
    end if
end sub

' Remote Control Handling
function onKeyEvent(key as String, press as Boolean) as Boolean
    if press
        if key = "back"
            if m.screenStack.count() > 1
                popScreen()
                return true
            end if
        end if
    end if
    return false
end function

function getScreenName(key as String, fallback as String) as String
    if m.screens = invalid then return fallback
    return getStringValue(m.screens, key, fallback)
end function

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
