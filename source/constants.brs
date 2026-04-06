function GetConstants() as Object
    return {
        "ACTIVE_PROFILE": "graphql_sample",
        "APP": {
            "TITLE": "Template Roku",
            "DONE_RULE": "A new app should require only profile config and assets updates; no template code edits.",
            "SCREENS": {
                "HOME": "HomeScreen",
                "PLAYER": "PlayerScreen"
            },
            "API_ERRORS": {
                "INVALID_REQUEST": "Request payload is required.",
                "CONFIG_VALIDATION_FAILED": "Configuration validation failed.",
                "UNKNOWN_REQUEST_TYPE": "Unsupported request type.",
                "FEED_NOT_FOUND": "Configured feed was not found.",
                "OPERATION_NOT_FOUND": "Configured operation was not found.",
                "FEED_ITEMS_MISSING": "Configured items path was not found in response.",
                "CONTENT_MISSING": "Content payload is required for resolver.",
                "PLAYBACK_URL_MISSING": "Playback URL is missing for direct resolver strategy.",
                "PIPELINE_MISSING": "Resolver pipeline is missing.",
                "PIPELINE_STEP_INVALID": "Resolver pipeline step is invalid.",
                "RESOLVER_STRATEGY_UNSUPPORTED": "Resolver strategy is unsupported.",
                "RESOLVER_OPERATION_MISSING": "Resolver operation key is missing.",
                "RESOLVER_OPERATION_NOT_FOUND": "Resolver operation was not found.",
                "PLAYBACK_RESOLUTION_FAILED": "Resolver did not produce playback URL.",
                "REQUEST_CONFIG_MISSING": "Operation request config is missing.",
                "REQUEST_FAILED": "Request failed after retries.",
                "URL_MISSING": "Resolved request URL is empty.",
                "REQUEST_START_FAILED": "Failed to start HTTP request.",
                "REQUEST_TIMEOUT": "HTTP request timed out.",
                "HTTP_ERROR": "HTTP request failed.",
                "HTTP_METHOD_UNSUPPORTED": "HTTP method is not supported."
            },
            "TEXT": {
                "INITIAL_STATUS": "Loading...",
                "LOADING_FEEDS": "Loading configured feeds...",
                "LOADING_FEED_PREFIX": "Loading feed: ",
                "RESOLVING_PREFIX": "Resolving playback for ",
                "PLAYING_PREFIX": "Starting playback for ",
                "NO_FEEDS": "No feeds are configured for this profile.",
                "NO_CONTENT": "No content returned from configured feeds.",
                "NO_PLAYABLE": "No playable content was found.",
                "READY_NO_AUTOPLAY": "Feeds loaded. Autoplay is disabled.",
                "VALIDATION_FAILED_PREFIX": "Configuration error: ",
                "ERROR_PREFIX": "Error: ",
                "FEED_RESPONSE_INVALID": "Feed response was invalid.",
                "FEED_LOAD_FAILED": "Feed load failed.",
                "RESOLVER_RESPONSE_INVALID": "Resolver response was invalid.",
                "RESOLUTION_FAILED": "Playback resolution failed.",
                "RESOLVER_EMPTY_CONTENT": "Resolver returned empty content.",
                "UNKNOWN_ERROR": "Unexpected error occurred.",
                "STARTUP_CONFIG_FAILED_PREFIX": "Startup configuration failed: "
            }
        },
        "DEFAULTS": {
            "TIMEOUT_MS": 10000,
            "RETRY_POLICY": {
                "MAX_ATTEMPTS": 2,
                "BASE_DELAY_MS": 250,
                "MULTIPLIER": 2
            },
            "REQUEST_TYPES": {
                "LOAD_FEED": "LOAD_FEED",
                "RESOLVE_CONTENT": "RESOLVE_CONTENT",
                "EXECUTE_OPERATION": "EXECUTE_OPERATION"
            }
        },
        "PROFILES": GetConfigProfiles()
    }
end function

function GetAppConfig() as Object
    constants = GetConstants()
    profileName = constants.ACTIVE_PROFILE
    profile = invalid

    profiles = GetInterface(constants.PROFILES, "ifAssociativeArray")
    if profiles <> invalid and profiles.DoesExist(profileName)
        profile = profiles.Lookup(profileName)
    end if

    if profile = invalid
        for each key in constants.PROFILES
            profileName = key
            profile = constants.PROFILES[key]
            exit for
        end for
    end if

    return {
        "APP": constants.APP,
        "DEFAULTS": constants.DEFAULTS,
        "ACTIVE_PROFILE": profileName,
        "PROFILE": profile
    }
end function

function ValidateAppConfig(config as Object) as Object
    errors = []

    if config = invalid
        errors.push("Config object is invalid.")
        return {
            "valid": false,
            "errors": errors,
            "message": JoinValidationErrors(errors)
        }
    end if

    profile = config.PROFILE
    if profile = invalid or GetInterface(profile, "ifAssociativeArray") = invalid
        errors.push("Active profile is missing.")
        return {
            "valid": false,
            "errors": errors,
            "message": JoinValidationErrors(errors)
        }
    end if

    if profile.API = invalid or GetInterface(profile.API, "ifAssociativeArray") = invalid
        errors.push("Profile.API is required.")
    else
        mode = LCase(GetStringOrDefault(profile.API.MODE, ""))
        if mode <> "graphql" and mode <> "rest" and mode <> "mixed"
            errors.push("Profile.API.MODE must be graphql, rest, or mixed.")
        end if

        auth = profile.API.AUTH
        if auth <> invalid
            strategy = LCase(GetStringOrDefault(auth.STRATEGY, "none"))
            if strategy <> "none" and strategy <> "apikey" and strategy <> "bearer" and strategy <> "custom"
                errors.push("Profile.API.AUTH.STRATEGY must be none, apiKey, bearer, or custom.")
            end if

            if strategy = "apikey"
                if GetStringOrDefault(auth.KEY_NAME, "") = ""
                    errors.push("Profile.API.AUTH.KEY_NAME is required for apiKey strategy.")
                end if
                location = LCase(GetStringOrDefault(auth.LOCATION, "query"))
                if location <> "query" and location <> "header"
                    errors.push("Profile.API.AUTH.LOCATION must be query or header for apiKey strategy.")
                end if
            else if strategy = "bearer"
                token = GetStringOrDefault(auth.TOKEN, "")
                valueTemplate = GetStringOrDefault(auth.VALUE_TEMPLATE, "")
                if token = "" and valueTemplate = ""
                    errors.push("Profile.API.AUTH requires TOKEN or VALUE_TEMPLATE for bearer strategy.")
                end if
            end if
        end if
    end if

    operations = profile.OPERATIONS
    operationsAA = GetInterface(operations, "ifAssociativeArray")
    if operationsAA = invalid
        errors.push("Profile.OPERATIONS is required.")
    end if

    homeMode = "feeds"
    behaviorForMode = profile.BEHAVIOR
    if behaviorForMode <> invalid and GetInterface(behaviorForMode, "ifAssociativeArray") <> invalid
        homeMode = LCase(GetStringOrDefault(behaviorForMode.HOME_MODE, "feeds"))
    end if

    feedOperationKeys = {}
    feedKeys = {}
    feedsAA = GetInterface(profile.FEEDS, "ifArray")
    feedCount = 0
    if feedsAA <> invalid then feedCount = profile.FEEDS.count()
    requiresFeeds = homeMode <> "single_operation"
    if requiresFeeds and feedCount = 0
        errors.push("Profile.FEEDS must include at least one feed.")
    else if feedsAA <> invalid
        for each feed in profile.FEEDS
            feedAA = GetInterface(feed, "ifAssociativeArray")
            if feedAA = invalid
                errors.push("Each Profile.FEEDS entry must be an associative array.")
            else
                feedKey = GetStringOrDefault(feed.KEY, "")
                if feedKey = ""
                    errors.push("Each feed requires a non-empty KEY.")
                else
                    if feedKeys.DoesExist(feedKey)
                        errors.push("Feed KEY '" + feedKey + "' is duplicated.")
                    else
                        feedKeys[feedKey] = true
                    end if
                end if

                operationKey = GetStringOrDefault(feed.OPERATION, "")
                if operationKey = ""
                    errors.push("Feed '" + GetStringOrDefault(feed.KEY, "<unknown>") + "' is missing OPERATION.")
                else
                    feedOperationKeys[operationKey] = true
                    if operationsAA = invalid or operationsAA.DoesExist(operationKey) = false
                        errors.push("Feed '" + GetStringOrDefault(feed.KEY, "<unknown>") + "' references missing operation '" + operationKey + "'.")
                    end if
                end if
            end if
        end for
    else if profile.FEEDS <> invalid and requiresFeeds = false
        errors.push("Profile.FEEDS must be an array when provided.")
    end if

    normalization = profile.NORMALIZATION
    normalizationAA = GetInterface(normalization, "ifAssociativeArray")
    if normalizationAA = invalid
        errors.push("Profile.NORMALIZATION is required.")
    else
        requiredMappings = [
            "ID_PATH",
            "TITLE_PATH",
            "THUMB_PATH",
            "TYPE_PATH",
            "PLAYBACK_URL_PATH",
            "PLAYBACK_FORMAT_PATH",
            "RESOLVER_STRATEGY_PATH",
            "RESOLVER_URL_PATH",
            "RESOLVER_ID_PATH",
            "RESOLVER_PIPELINE_PATH",
            "DRM_TYPE_PATH",
            "DRM_LICENSE_URL_PATH",
            "DRM_HEADERS_PATH"
        ]
        for each mappingKey in requiredMappings
            if normalizationAA.DoesExist(mappingKey) = false
                errors.push("Profile.NORMALIZATION." + mappingKey + " is required.")
            end if
        end for
    end if

    resolverOperationKeys = {}
    resolver = profile.RESOLVER
    resolverAA = GetInterface(resolver, "ifAssociativeArray")
    if resolverAA = invalid
        errors.push("Profile.RESOLVER is required.")
    else
        resolverOps = resolver.OPERATIONS
        resolverOpsAA = GetInterface(resolverOps, "ifAssociativeArray")
        if resolverOpsAA = invalid
            errors.push("Profile.RESOLVER.OPERATIONS is required.")
        else
            for each opType in resolverOps
                opKey = GetStringOrDefault(resolverOps[opType], "")
                if opKey <> ""
                    resolverOperationKeys[opKey] = true
                    if operationsAA = invalid or operationsAA.DoesExist(opKey) = false
                        errors.push("Profile.RESOLVER.OPERATIONS." + opType + " references missing operation '" + opKey + "'.")
                    end if
                end if
            end for
        end if

        pipelines = resolver.PIPELINES
        pipelinesAA = GetInterface(pipelines, "ifAssociativeArray")
        if pipelinesAA <> invalid
            for each pipelineKey in pipelines
                steps = pipelines[pipelineKey]
                if GetInterface(steps, "ifArray") = invalid or steps.count() = 0
                    errors.push("Profile.RESOLVER.PIPELINES." + pipelineKey + " must be a non-empty array.")
                else
                    for each step in steps
                        stepAA = GetInterface(step, "ifAssociativeArray")
                        if stepAA = invalid
                            errors.push("Profile.RESOLVER.PIPELINES." + pipelineKey + " contains an invalid step.")
                        else
                            stepOp = GetStringOrDefault(step.OPERATION, "")
                            if stepOp = ""
                                errors.push("Profile.RESOLVER.PIPELINES." + pipelineKey + " contains a step without OPERATION.")
                            else
                                resolverOperationKeys[stepOp] = true
                                if operationsAA = invalid or operationsAA.DoesExist(stepOp) = false
                                    errors.push("Profile.RESOLVER.PIPELINES." + pipelineKey + " references missing operation '" + stepOp + "'.")
                                end if
                            end if
                        end if
                    end for
                end if
            end for
        end if
    end if

    behavior = profile.BEHAVIOR
    behaviorAA = GetInterface(behavior, "ifAssociativeArray")
    if behaviorAA = invalid
        errors.push("Profile.BEHAVIOR is required.")
    else
        homeMode = LCase(GetStringOrDefault(behavior.HOME_MODE, "feeds"))
        if homeMode <> "feeds" and homeMode <> "single_operation"
            errors.push("Profile.BEHAVIOR.HOME_MODE must be feeds or single_operation.")
        end if

        autoPlay = behavior.AUTO_PLAY
        if GetInterface(autoPlay, "ifAssociativeArray") = invalid
            errors.push("Profile.BEHAVIOR.AUTO_PLAY is required.")
        else
            mode = LCase(GetStringOrDefault(autoPlay.SELECTION_MODE, "firstPlayable"))
            if mode <> "first" and mode <> "firstplayable"
                errors.push("Profile.BEHAVIOR.AUTO_PLAY.SELECTION_MODE must be first or firstPlayable.")
            end if
        end if

        if homeMode = "feeds"
            feedLoadOrder = behavior.FEED_LOAD_ORDER
            if GetInterface(feedLoadOrder, "ifArray") = invalid or feedLoadOrder.count() = 0
                errors.push("Profile.BEHAVIOR.FEED_LOAD_ORDER must be a non-empty array.")
            else
                for each loadKey in feedLoadOrder
                    keyText = loadKey.tostr()
                    if keyText = ""
                        errors.push("Profile.BEHAVIOR.FEED_LOAD_ORDER includes an empty key.")
                    else if feedKeys.DoesExist(keyText) = false
                        errors.push("Profile.BEHAVIOR.FEED_LOAD_ORDER references missing feed key '" + keyText + "'.")
                    end if
                end for
            end if
        else if homeMode = "single_operation"
            singleOperation = GetStringOrDefault(behavior.SINGLE_OPERATION, "")
            if singleOperation = ""
                errors.push("Profile.BEHAVIOR.SINGLE_OPERATION is required when HOME_MODE is single_operation.")
            else if operationsAA = invalid or operationsAA.DoesExist(singleOperation) = false
                errors.push("Profile.BEHAVIOR.SINGLE_OPERATION references missing operation '" + singleOperation + "'.")
            end if
        end if
    end if

    if operationsAA <> invalid
        profileModeForOps = "rest"
        if profile.API <> invalid and GetInterface(profile.API, "ifAssociativeArray") <> invalid
            profileModeForOps = GetStringOrDefault(profile.API.MODE, "rest")
        end if

        profileBaseUrl = ""
        if profile.API <> invalid and GetInterface(profile.API, "ifAssociativeArray") <> invalid
            profileBaseUrl = GetStringOrDefault(profile.API.BASE_URL, "")
        end if

        for each operationKey in operations
            operation = operations[operationKey]
            operationAA = GetInterface(operation, "ifAssociativeArray")
            if operationAA = invalid
                errors.push("Profile.OPERATIONS." + operationKey + " must be an associative array.")
            else
                request = operation.REQUEST
                requestAA = GetInterface(request, "ifAssociativeArray")
                if requestAA = invalid
                    errors.push("Profile.OPERATIONS." + operationKey + ".REQUEST is required.")
                else
                    requestMode = LCase(GetStringOrDefault(request.MODE, profileModeForOps))
                    if requestMode <> "graphql" and requestMode <> "rest"
                        errors.push("Profile.OPERATIONS." + operationKey + ".REQUEST.MODE must be graphql or rest.")
                    end if

                    method = UCase(GetStringOrDefault(request.METHOD, ""))
                    if method <> "" and IsSupportedHttpMethod(method) = false
                        errors.push("Profile.OPERATIONS." + operationKey + ".REQUEST.METHOD must be GET, POST, PUT, PATCH, or DELETE.")
                    end if

                    hasExplicitUrl = requestAA.DoesExist("URL") and GetStringOrDefault(request.URL, "") <> ""
                    hasPath = requestAA.DoesExist("PATH") and GetStringOrDefault(request.PATH, "") <> ""
                    hasBaseUrl = requestAA.DoesExist("BASE_URL") and GetStringOrDefault(request.BASE_URL, "") <> ""
                    hasProfileBase = profileBaseUrl <> ""
                    if hasExplicitUrl = false and hasPath = false and hasBaseUrl = false and hasProfileBase = false
                        errors.push("Profile.OPERATIONS." + operationKey + ".REQUEST must include URL or PATH with BASE_URL.")
                    end if

                    if requestMode = "graphql"
                        body = request.BODY
                        gql = request.GRAPHQL
                        if body = invalid
                            if gql = invalid or GetInterface(gql, "ifAssociativeArray") = invalid or GetStringOrDefault(gql.QUERY, "") = ""
                                errors.push("Profile.OPERATIONS." + operationKey + ".REQUEST.GRAPHQL.QUERY is required when BODY is omitted.")
                            end if
                        end if
                    end if
                end if
            end if

            if operationAA <> invalid
                if feedOperationKeys.DoesExist(operationKey)
                    extract = operation.EXTRACT
                    if extract <> invalid and GetInterface(extract, "ifAssociativeArray") = invalid
                        errors.push("Feed operation '" + operationKey + "' EXTRACT must be an associative array when provided.")
                    end if
                end if

                if resolverOperationKeys.DoesExist(operationKey)
                    extract = operation.EXTRACT
                    extractAA = GetInterface(extract, "ifAssociativeArray")
                    if extractAA = invalid
                        errors.push("Resolver operation '" + operationKey + "' must define EXTRACT mappings.")
                    else
                        hasResolverOutput = false
                        resolverExtractKeys = [
                            "PLAYBACK_URL_PATH",
                            "PLAYBACK_FORMAT_PATH",
                            "RESOLVER_URL_PATH",
                            "RESOLVER_ID_PATH",
                            "DRM_TYPE_PATH",
                            "DRM_LICENSE_URL_PATH",
                            "DRM_HEADERS_PATH"
                        ]
                        for each extractKey in resolverExtractKeys
                            if extractAA.DoesExist(extractKey)
                                if extract[extractKey] <> invalid and extract[extractKey].tostr() <> ""
                                    hasResolverOutput = true
                                end if
                            end if
                        end for
                        if hasResolverOutput = false
                            errors.push("Resolver operation '" + operationKey + "' EXTRACT must define at least one output path.")
                        end if
                    end if
                end if
            end if
        end for
    end if

    return {
        "valid": errors.count() = 0,
        "errors": errors,
        "message": JoinValidationErrors(errors)
    }
end function

function GetConfigProfiles() as Object
    return {
        "graphql_sample": {
            "API": {
                "MODE": "graphql",
                "BASE_URL": "https://example.com/graphql",
                "DEFAULT_HEADERS": {
                    "Content-Type": "application/json"
                },
                "AUTH": {
                    "STRATEGY": "none"
                },
                "TIMEOUT_MS": 9000,
                "RETRY_POLICY": {
                    "MAX_ATTEMPTS": 2,
                    "BASE_DELAY_MS": 250,
                    "MULTIPLIER": 2
                }
            },
            "BEHAVIOR": {
                "AUTO_PLAY": {
                    "ENABLED": true,
                    "RAIL_PRIORITY": ["live", "featured"],
                    "SELECTION_MODE": "firstPlayable"
                },
                "FEED_LOAD_ORDER": ["live", "featured"],
                "DEFAULT_STREAM_FORMAT": "hls",
                "RESOLVER_DEFAULT_STRATEGY": "direct"
            },
            "NORMALIZATION": {
                "ID_PATH": "id",
                "TITLE_PATH": "title",
                "THUMB_PATH": "images[0].url",
                "TYPE_PATH": "type",
                "PLAYBACK_URL_PATH": "playback.url",
                "PLAYBACK_FORMAT_PATH": "playback.format",
                "RESOLVER_STRATEGY_PATH": "resolver.strategy",
                "RESOLVER_URL_PATH": "resolver.url",
                "RESOLVER_ID_PATH": "resolver.id",
                "RESOLVER_PIPELINE_PATH": "resolver.pipeline",
                "DRM_TYPE_PATH": "drm.type",
                "DRM_LICENSE_URL_PATH": "drm.licenseUrl",
                "DRM_HEADERS_PATH": "drm.headers"
            },
            "FEEDS": [
                {
                    "KEY": "live",
                    "TITLE": "Live",
                    "TYPE": "live",
                    "OPERATION": "feed_live"
                },
                {
                    "KEY": "featured",
                    "TITLE": "Featured",
                    "TYPE": "featured",
                    "OPERATION": "feed_featured"
                }
            ],
            "RESOLVER": {
                "OPERATIONS": {
                    "BY_URL": "resolve_by_url",
                    "BY_ID": "resolve_by_id"
                },
                "PIPELINES": {
                    "DEFAULT": [
                        { "OPERATION": "resolve_lookup_by_id" },
                        { "OPERATION": "resolve_by_url" }
                    ]
                }
            },
            "OPERATIONS": {
                "feed_live": {
                    "REQUEST": {
                        "MODE": "graphql",
                        "METHOD": "POST",
                        "PATH": "",
                        "GRAPHQL": {
                            "QUERY": "query Feed($rail: String!) { feed(rail: $rail) { items { id title type images { url } playback { url format } resolver { strategy url id } drm { type licenseUrl headers } } } }",
                            "VARIABLES": {
                                "rail": "live"
                            }
                        }
                    },
                    "EXTRACT": {
                        "ITEMS_PATH": "data.feed.items"
                    }
                },
                "feed_featured": {
                    "REQUEST": {
                        "MODE": "graphql",
                        "METHOD": "POST",
                        "PATH": "",
                        "GRAPHQL": {
                            "QUERY": "query Feed($rail: String!) { feed(rail: $rail) { items { id title type images { url } playback { url format } resolver { strategy url id } drm { type licenseUrl headers } } } }",
                            "VARIABLES": {
                                "rail": "featured"
                            }
                        }
                    },
                    "EXTRACT": {
                        "ITEMS_PATH": "data.feed.items"
                    }
                },
                "resolve_by_url": {
                    "REQUEST": {
                        "MODE": "rest",
                        "METHOD": "GET",
                        "URL": "{{resolverUrl}}"
                    },
                    "EXTRACT": {
                        "PLAYBACK_URL_PATH": "data.playback.url",
                        "PLAYBACK_FORMAT_PATH": "data.playback.format",
                        "DRM_TYPE_PATH": "data.drm.type",
                        "DRM_LICENSE_URL_PATH": "data.drm.licenseUrl",
                        "DRM_HEADERS_PATH": "data.drm.headers"
                    }
                },
                "resolve_by_id": {
                    "REQUEST": {
                        "MODE": "rest",
                        "METHOD": "GET",
                        "PATH": "/resolve/{{contentId}}"
                    },
                    "EXTRACT": {
                        "PLAYBACK_URL_PATH": "data.playback.url",
                        "PLAYBACK_FORMAT_PATH": "data.playback.format",
                        "DRM_TYPE_PATH": "data.drm.type",
                        "DRM_LICENSE_URL_PATH": "data.drm.licenseUrl",
                        "DRM_HEADERS_PATH": "data.drm.headers"
                    }
                },
                "resolve_lookup_by_id": {
                    "REQUEST": {
                        "MODE": "rest",
                        "METHOD": "GET",
                        "PATH": "/lookup/{{contentId}}"
                    },
                    "EXTRACT": {
                        "RESOLVER_URL_PATH": "data[0].contentUrl"
                    }
                }
            }
        },
        "rest_sample": {
            "API": {
                "MODE": "rest",
                "BASE_URL": "https://example.com/api",
                "DEFAULT_HEADERS": {
                    "Accept": "application/json"
                },
                "AUTH": {
                    "STRATEGY": "apiKey",
                    "KEY_NAME": "api_key",
                    "VALUE_TEMPLATE": "{{apiKey}}",
                    "LOCATION": "query"
                },
                "TIMEOUT_MS": 9000,
                "RETRY_POLICY": {
                    "MAX_ATTEMPTS": 3,
                    "BASE_DELAY_MS": 200,
                    "MULTIPLIER": 2
                }
            },
            "BEHAVIOR": {
                "AUTO_PLAY": {
                    "ENABLED": true,
                    "RAIL_PRIORITY": ["live", "catchup"],
                    "SELECTION_MODE": "firstPlayable"
                },
                "FEED_LOAD_ORDER": ["live", "catchup"],
                "DEFAULT_STREAM_FORMAT": "hls",
                "RESOLVER_DEFAULT_STRATEGY": "byUrl"
            },
            "NORMALIZATION": {
                "ID_PATH": "id",
                "TITLE_PATH": "title",
                "THUMB_PATH": "thumbnail",
                "TYPE_PATH": "kind",
                "PLAYBACK_URL_PATH": "playback.url",
                "PLAYBACK_FORMAT_PATH": "playback.format",
                "RESOLVER_URL_PATH": "resolver.url",
                "RESOLVER_ID_PATH": "resolver.id",
                "RESOLVER_STRATEGY_PATH": "resolver.strategy",
                "RESOLVER_PIPELINE_PATH": "resolver.pipeline",
                "DRM_TYPE_PATH": "drm.type",
                "DRM_LICENSE_URL_PATH": "drm.licenseUrl",
                "DRM_HEADERS_PATH": "drm.headers"
            },
            "FEEDS": [
                {
                    "KEY": "live",
                    "TITLE": "Live",
                    "TYPE": "live",
                    "OPERATION": "feed_live_rest"
                },
                {
                    "KEY": "catchup",
                    "TITLE": "Catch Up",
                    "TYPE": "catchup",
                    "OPERATION": "feed_catchup_rest"
                }
            ],
            "RESOLVER": {
                "OPERATIONS": {
                    "BY_URL": "resolve_rest_by_url",
                    "BY_ID": "resolve_rest_by_id"
                },
                "PIPELINES": {
                    "DEFAULT": [
                        { "OPERATION": "resolve_rest_by_id" }
                    ]
                }
            },
            "OPERATIONS": {
                "feed_live_rest": {
                    "REQUEST": {
                        "MODE": "rest",
                        "METHOD": "GET",
                        "PATH": "/live",
                        "QUERY_PARAMS": {
                            "limit": "25"
                        }
                    },
                    "EXTRACT": {
                        "ITEMS_PATH": "data.items"
                    }
                },
                "feed_catchup_rest": {
                    "REQUEST": {
                        "MODE": "rest",
                        "METHOD": "GET",
                        "PATH": "/catchup",
                        "QUERY_PARAMS": {
                            "page": "1"
                        }
                    },
                    "EXTRACT": {
                        "ITEMS_PATH": "data.items"
                    }
                },
                "resolve_rest_by_url": {
                    "REQUEST": {
                        "MODE": "rest",
                        "METHOD": "GET",
                        "URL": "{{resolverUrl}}"
                    },
                    "EXTRACT": {
                        "PLAYBACK_URL_PATH": "data.playback.url",
                        "PLAYBACK_FORMAT_PATH": "data.playback.format"
                    }
                },
                "resolve_rest_by_id": {
                    "REQUEST": {
                        "MODE": "rest",
                        "METHOD": "GET",
                        "PATH": "/playback/{{contentId}}"
                    },
                    "EXTRACT": {
                        "PLAYBACK_URL_PATH": "data.url",
                        "PLAYBACK_FORMAT_PATH": "data.format"
                    }
                }
            }
        },
        "mixed_sample": {
            "API": {
                "MODE": "mixed",
                "BASE_URL": "https://example.com",
                "DEFAULT_HEADERS": {
                    "Content-Type": "application/json",
                    "Accept": "application/json"
                },
                "AUTH": {
                    "STRATEGY": "bearer",
                    "TOKEN": "replace-with-access-token"
                },
                "TIMEOUT_MS": 10000,
                "RETRY_POLICY": {
                    "MAX_ATTEMPTS": 3,
                    "BASE_DELAY_MS": 250,
                    "MULTIPLIER": 2
                }
            },
            "BEHAVIOR": {
                "AUTO_PLAY": {
                    "ENABLED": true,
                    "RAIL_PRIORITY": ["live", "vod"],
                    "SELECTION_MODE": "firstPlayable"
                },
                "FEED_LOAD_ORDER": ["live", "vod"],
                "DEFAULT_STREAM_FORMAT": "hls",
                "RESOLVER_DEFAULT_STRATEGY": "multiStep"
            },
            "NORMALIZATION": {
                "ID_PATH": "id",
                "TITLE_PATH": "title",
                "THUMB_PATH": "thumb.url",
                "TYPE_PATH": "type",
                "PLAYBACK_URL_PATH": "playback.url",
                "PLAYBACK_FORMAT_PATH": "playback.format",
                "RESOLVER_URL_PATH": "resolver.url",
                "RESOLVER_ID_PATH": "resolver.contentId",
                "RESOLVER_STRATEGY_PATH": "resolver.strategy",
                "RESOLVER_PIPELINE_PATH": "resolver.pipeline",
                "DRM_TYPE_PATH": "drm.type",
                "DRM_LICENSE_URL_PATH": "drm.licenseUrl",
                "DRM_HEADERS_PATH": "drm.headers"
            },
            "FEEDS": [
                {
                    "KEY": "live",
                    "TITLE": "Live",
                    "TYPE": "live",
                    "OPERATION": "feed_live_graphql"
                },
                {
                    "KEY": "vod",
                    "TITLE": "VOD",
                    "TYPE": "vod",
                    "OPERATION": "feed_vod_rest"
                }
            ],
            "RESOLVER": {
                "OPERATIONS": {
                    "BY_URL": "resolve_mixed_by_url",
                    "BY_ID": "resolve_mixed_lookup"
                },
                "PIPELINES": {
                    "DEFAULT": [
                        { "OPERATION": "resolve_mixed_lookup" },
                        { "OPERATION": "resolve_mixed_by_url" }
                    ]
                }
            },
            "OPERATIONS": {
                "feed_live_graphql": {
                    "REQUEST": {
                        "MODE": "graphql",
                        "METHOD": "POST",
                        "URL": "https://example.com/graphql",
                        "GRAPHQL": {
                            "QUERY": "query LiveRail { liveRail { items { id title type thumb { url } resolver { strategy contentId } } } }",
                            "VARIABLES": {}
                        }
                    },
                    "EXTRACT": {
                        "ITEMS_PATH": "data.liveRail.items"
                    }
                },
                "feed_vod_rest": {
                    "REQUEST": {
                        "MODE": "rest",
                        "METHOD": "GET",
                        "URL": "https://example.com/api/vod"
                    },
                    "EXTRACT": {
                        "ITEMS_PATH": "data.items"
                    }
                },
                "resolve_mixed_lookup": {
                    "REQUEST": {
                        "MODE": "rest",
                        "METHOD": "GET",
                        "URL": "https://example.com/api/lookup/{{contentId}}"
                    },
                    "EXTRACT": {
                        "RESOLVER_URL_PATH": "data[0].contentUrl"
                    }
                },
                "resolve_mixed_by_url": {
                    "REQUEST": {
                        "MODE": "rest",
                        "METHOD": "GET",
                        "URL": "{{resolverUrl}}"
                    },
                    "EXTRACT": {
                        "PLAYBACK_URL_PATH": "data.playback.url",
                        "PLAYBACK_FORMAT_PATH": "data.playback.format",
                        "DRM_TYPE_PATH": "data.playback.drm.type",
                        "DRM_LICENSE_URL_PATH": "data.playback.drm.licenseUrl",
                        "DRM_HEADERS_PATH": "data.playback.drm.headers"
                    }
                }
            }
        },
        "root_array_sample": {
            "API": {
                "MODE": "rest",
                "BASE_URL": "https://example.com/api",
                "DEFAULT_HEADERS": {
                    "Accept": "application/json"
                },
                "AUTH": {
                    "STRATEGY": "none"
                },
                "TIMEOUT_MS": 9000,
                "RETRY_POLICY": {
                    "MAX_ATTEMPTS": 2,
                    "BASE_DELAY_MS": 200,
                    "MULTIPLIER": 2
                }
            },
            "BEHAVIOR": {
                "HOME_MODE": "feeds",
                "AUTO_PLAY": {
                    "ENABLED": true,
                    "RAIL_PRIORITY": ["featured"],
                    "SELECTION_MODE": "firstPlayable"
                },
                "FEED_LOAD_ORDER": ["featured"],
                "DEFAULT_STREAM_FORMAT": "hls",
                "RESOLVER_DEFAULT_STRATEGY": "multiStep"
            },
            "NORMALIZATION": {
                "ID_PATH": "id",
                "TITLE_PATH": "title",
                "THUMB_PATH": "thumb",
                "TYPE_PATH": "type",
                "PLAYBACK_URL_PATH": "playback.url",
                "PLAYBACK_FORMAT_PATH": "playback.format",
                "RESOLVER_URL_PATH": "resolver.url",
                "RESOLVER_ID_PATH": "resolver.id",
                "RESOLVER_STRATEGY_PATH": "resolver.strategy",
                "RESOLVER_PIPELINE_PATH": "resolver.pipeline",
                "DRM_TYPE_PATH": "drm.type",
                "DRM_LICENSE_URL_PATH": "drm.licenseUrl",
                "DRM_HEADERS_PATH": "drm.headers"
            },
            "FEEDS": [
                {
                    "KEY": "featured",
                    "TITLE": "Featured",
                    "TYPE": "featured",
                    "OPERATION": "feed_root_array"
                }
            ],
            "RESOLVER": {
                "OPERATIONS": {
                    "BY_URL": "resolve_root_by_url",
                    "BY_ID": "resolve_root_lookup_by_id"
                },
                "PIPELINES": {
                    "DEFAULT": [
                        { "OPERATION": "resolve_root_lookup_by_id" },
                        { "OPERATION": "resolve_root_by_url" }
                    ]
                }
            },
            "OPERATIONS": {
                "feed_root_array": {
                    "REQUEST": {
                        "MODE": "rest",
                        "METHOD": "GET",
                        "PATH": "/featured"
                    },
                    "EXTRACT": {}
                },
                "resolve_root_lookup_by_id": {
                    "REQUEST": {
                        "MODE": "rest",
                        "METHOD": "GET",
                        "PATH": "/lookup/{{contentId}}"
                    },
                    "EXTRACT": {
                        "RESOLVER_URL_PATH": "data[0].contentUrl"
                    }
                },
                "resolve_root_by_url": {
                    "REQUEST": {
                        "MODE": "rest",
                        "METHOD": "GET",
                        "URL": "{{resolverUrl}}"
                    },
                    "EXTRACT": {
                        "PLAYBACK_URL_PATH": "data.playback.url",
                        "PLAYBACK_FORMAT_PATH": "data.playback.format"
                    }
                }
            }
        },
        "feedless_single_operation_sample": {
            "API": {
                "MODE": "rest",
                "BASE_URL": "https://example.com/api",
                "DEFAULT_HEADERS": {
                    "Accept": "application/json"
                },
                "AUTH": {
                    "STRATEGY": "none"
                },
                "TIMEOUT_MS": 9000,
                "RETRY_POLICY": {
                    "MAX_ATTEMPTS": 2,
                    "BASE_DELAY_MS": 200,
                    "MULTIPLIER": 2
                }
            },
            "BEHAVIOR": {
                "HOME_MODE": "single_operation",
                "SINGLE_OPERATION": "single_featured_operation",
                "SINGLE_OPERATION_TITLE": "Featured",
                "SINGLE_OPERATION_TYPE": "featured",
                "AUTO_PLAY": {
                    "ENABLED": true,
                    "RAIL_PRIORITY": ["single_operation"],
                    "SELECTION_MODE": "firstPlayable"
                },
                "DEFAULT_STREAM_FORMAT": "hls",
                "RESOLVER_DEFAULT_STRATEGY": "direct"
            },
            "NORMALIZATION": {
                "ID_PATH": "id",
                "TITLE_PATH": "title",
                "THUMB_PATH": "thumb",
                "TYPE_PATH": "type",
                "PLAYBACK_URL_PATH": "playback.url",
                "PLAYBACK_FORMAT_PATH": "playback.format",
                "RESOLVER_URL_PATH": "resolver.url",
                "RESOLVER_ID_PATH": "resolver.id",
                "RESOLVER_STRATEGY_PATH": "resolver.strategy",
                "RESOLVER_PIPELINE_PATH": "resolver.pipeline",
                "DRM_TYPE_PATH": "drm.type",
                "DRM_LICENSE_URL_PATH": "drm.licenseUrl",
                "DRM_HEADERS_PATH": "drm.headers"
            },
            "RESOLVER": {
                "OPERATIONS": {
                    "BY_URL": "single_resolve_by_url",
                    "BY_ID": "single_resolve_by_id"
                },
                "PIPELINES": {
                    "DEFAULT": [
                        { "OPERATION": "single_resolve_by_id" }
                    ]
                }
            },
            "OPERATIONS": {
                "single_featured_operation": {
                    "REQUEST": {
                        "MODE": "rest",
                        "METHOD": "GET",
                        "PATH": "/single-featured"
                    },
                    "EXTRACT": {}
                },
                "single_resolve_by_url": {
                    "REQUEST": {
                        "MODE": "rest",
                        "METHOD": "GET",
                        "URL": "{{resolverUrl}}"
                    },
                    "EXTRACT": {
                        "PLAYBACK_URL_PATH": "data.playback.url",
                        "PLAYBACK_FORMAT_PATH": "data.playback.format"
                    }
                },
                "single_resolve_by_id": {
                    "REQUEST": {
                        "MODE": "rest",
                        "METHOD": "GET",
                        "PATH": "/single-playback/{{contentId}}"
                    },
                    "EXTRACT": {
                        "PLAYBACK_URL_PATH": "data.url",
                        "PLAYBACK_FORMAT_PATH": "data.format"
                    }
                }
            }
        }
    }
end function

function ProfileHasOperation(profile as Object, operationKey as String) as Boolean
    if profile = invalid or profile.OPERATIONS = invalid return false
    ops = GetInterface(profile.OPERATIONS, "ifAssociativeArray")
    if ops = invalid return false
    return ops.DoesExist(operationKey)
end function

function JoinValidationErrors(errors as Object) as String
    if errors = invalid or GetInterface(errors, "ifArray") = invalid or errors.count() = 0
        return ""
    end if

    message = ""
    for each err in errors
        if message <> "" then message = message + " | "
        message = message + err.tostr()
    end for
    return message
end function

function GetStringOrDefault(value as Dynamic, fallback as String) as String
    if value = invalid then return fallback
    txt = value.tostr()
    if txt = "" then return fallback
    return txt
end function

function IsSupportedHttpMethod(method as String) as Boolean
    upper = UCase(method)
    if upper = "GET" then return true
    if upper = "POST" then return true
    if upper = "PUT" then return true
    if upper = "PATCH" then return true
    if upper = "DELETE" then return true
    return false
end function
