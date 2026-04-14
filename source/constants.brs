function GetConstants() as Object
    return {
        "API": {
            ' TEMPLATE: Replace BASE_URL with your project's actual API base.
            "BASE_URL": "https://your-api-base-url.com/",
            "TIMEOUT_MS": 10000
            ' TEMPLATE: Add endpoint constants here based on your API docs.
            ' REST example: "HOME": "?section=home"
            ' GraphQL: keep query strings here if your API is GraphQL-based
        },
        "COLORS": {
            ' TEMPLATE: Replace with your brand colors (hex or Roku RGBA strings).
            ' If unsure, leave as-is and update later during UI styling.
            "PRIMARY": "#FF0000",
            "BACKGROUND": "#000000",
            "TEXT": "#FFFFFF"
        },
        "SCREEN": {
            "FHD_WIDTH": 1920,
            "FHD_HEIGHT": 1080
        }
    }
end function
