sub init()
    m.statusLabel = m.top.findNode("statusLabel")
    loadChannels()
end sub

sub loadChannels()
    TaskOrchestrator_RunTask("ApiTask", { "request": { "type": "CHANNEL_LIST" } }, "onChannelListResponse")
end sub

sub onChannelListResponse(event as Object)
    response = event.getData()
    if response.success = true
        channels = response.data
        if channels.count() > 0
            m.statusLabel.text = "Fetching Stream URL for " + channels[0].channel_name + "..."
            fetchLiveUrl(channels[0])
        else
            m.statusLabel.text = "No channels available."
        end if
    else
        m.statusLabel.text = "Error: " + response.error
    end if
end sub

sub fetchLiveUrl(channel as Object)
    m.currentChannel = channel
    TaskOrchestrator_RunTask("ApiTask", { "request": { "type": "GET_LIVE_URL", "url": channel.streaming_url } }, "onLiveUrlResponse")
end sub

sub onLiveUrlResponse(event as Object)
    response = event.getData()
    if response.success = true
        m.currentChannel.streaming_url = response.url
        m.top.selectedChannel = m.currentChannel
    else
        m.statusLabel.text = "Error loading stream: " + response.error
    end if
end sub
