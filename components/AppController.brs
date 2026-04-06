sub init()
    m.screenContainer = m.top.findNode("screenContainer")
    m.screenStack = []
    
    ' Launch the initial screen
    showHomeScreen()
end sub

sub showHomeScreen()
    homeScreen = CreateObject("roSGNode", "HomeScreen")
    homeScreen.observeField("selectedContent", "onContentSelected")
    pushScreen(homeScreen)
end sub

sub onContentSelected(event as Object)
    contentItem = event.getData()
    playerScreen = CreateObject("roSGNode", "PlayerScreen")
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
    ? "AppController: Received Launch Args: "; args
    ' Handle launch routing here (for example, auto-opening an item)
    if args <> invalid and args.targetId <> invalid
        ? "AppController: Launch targetId: "; args.targetId
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
