sub init()
    m.videoPlayer = m.top.findNode("videoPlayer")
end sub

sub onDataChange()
    data = m.top.itemData
    if data <> invalid
        content = CreateObject("roSGNode", "ContentNode")
        if data.url <> invalid then content.url = data.url
        if data.title <> invalid then content.title = data.title
        if data.streamFormat <> invalid then content.streamformat = data.streamFormat else content.streamformat = "hls"
        
        if content.url <> invalid and content.url <> ""
            m.videoPlayer.content = content
            m.videoPlayer.control = "play"
            m.videoPlayer.setFocus(true)
        end if
    end if
end sub
