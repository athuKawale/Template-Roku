function GetConstants() as Object
    return {
        "APP": {
            "TITLE": "Template Roku",
            "LOADING_TEXT": "Loading content...",
            "EMPTY_TEXT": "No content items were returned.",
            "CONFIG_HINT": "Configure API.BASE_URL, query, path, and field mapping in source/constants.brs.",
            "RESOLVING_TEXT_PREFIX": "Resolving playback URL for ",
            "PLAYING_TEXT_PREFIX": "Starting playback for ",
            "UNPLAYABLE_TEXT": "The selected item has no playable URL."
        },
        "API": {
            "BASE_URL": "",
            "CONTENT_LIST_QUERY": "query ContentList { contentList { items { title playbackUrl resolverUrl } } }",
            "CONTENT_LIST_VARIABLES": {},
            "CONTENT_LIST_PATH": ["data", "contentList", "items"],
            "FIELDS": {
                "TITLE": "title",
                "PLAYBACK_URL": "playbackUrl",
                "RESOLVER_URL": "resolverUrl",
                "STREAM_RESPONSE_URL": "playbackUrl"
            }
        },
        "COLORS": {
            "PRIMARY": "#2D6CDF",
            "BACKGROUND": "#000000",
            "TEXT": "#FFFFFF"
        },
        "SCREEN": {
            "FHD_WIDTH": 1920,
            "FHD_HEIGHT": 1080
        }
    }
end function
