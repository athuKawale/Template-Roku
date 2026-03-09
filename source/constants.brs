function GetConstants() as Object
    return {
        "API": {
            "BASE_URL": "https://prd-ctv-gql.nw18.com/",
            "CHANNEL_LIST_QUERY": "query CtvChannelList($apiRequest: CtvChannelListinput) { ctvChannelList(apiRequest: $apiRequest) { data { language channel_name streaming_url } } }",
            "CHANNEL_LIST_VARIABLES": "{""apiRequest"": {""langName"": ""en-in""}}"
        },
        "COLORS": {
            "PRIMARY": "#EB1D24",
            "BACKGROUND": "#000000",
            "TEXT": "#FFFFFF"
        },
        "SCREEN": {
            "FHD_WIDTH": 1920,
            "FHD_HEIGHT": 1080
        }
    }
end function
