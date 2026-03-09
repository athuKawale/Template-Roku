sub init()
    m.appController = m.top.findNode("appController")
    m.appController.setFocus(true)
end sub

sub onLaunchArgsChange()
    m.appController.launchArgs = m.top.launchArgs
end sub
