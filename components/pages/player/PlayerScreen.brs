sub init()
    m.videoPlayer = m.top.findNode("videoPlayer")
end sub

sub onDataChange()
    data = m.top.channelData
    if data <> invalid
        content = CreateObject("roSGNode", "ContentNode")
        content.url = data.streaming_url
        content.title = data.channel_name
        content.streamformat = "hls"
        
        m.videoPlayer.content = content
        m.videoPlayer.control = "play"
        m.videoPlayer.setFocus(true)
    end if
end sub
