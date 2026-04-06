sub init()
    m.videoPlayer = m.top.findNode("videoPlayer")
end sub

sub onDataChange()
    data = m.top.contentItem
    if data <> invalid
        content = CreateObject("roSGNode", "ContentNode")
        content.url = data.playbackUrl
        content.title = data.title
        content.streamformat = "hls"
        
        m.videoPlayer.content = content
        m.videoPlayer.control = "play"
        m.videoPlayer.setFocus(true)
    end if
end sub
