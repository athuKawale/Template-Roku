sub init()
    m.screenContainer = m.top.findNode("screenContainer")
    m.screenStack = []
    
    ' Launch the initial screen
    showHomeScreen()
end sub

sub showHomeScreen()
    homeScreen = CreateObject("roSGNode", "HomeScreen")
    homeScreen.observeFieldScoped("selectedItem", "onItemSelected")
    pushScreen(homeScreen)
end sub

sub onItemSelected(event as Object)
    item = event.getData()
    playerScreen = CreateObject("roSGNode", "PlayerScreen")
    playerScreen.itemData = item
    pushScreen(playerScreen)
end sub

' --- Navigation Engine ---

sub pushScreen(newScreen as Object)
    if newScreen = invalid then return
    
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
    if m.screenStack.count() <= 1 then return ' Don't pop the last screen (Home)
    
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
    ' TEMPLATE: Implement deep-link routing here (map args to a screen).
    if args <> invalid and args.contentId <> invalid
        ? "AppController: Deep linking to contentId: "; args.contentId
        ' Example: push PlayerScreen with itemData that matches contentId
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
