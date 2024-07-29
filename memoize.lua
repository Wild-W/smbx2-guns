local function cache_get(cache, params)
    local node = cache
    for i = 1, #params do
        node = node.children and node.children[params[i]]
        if not node then return nil end
    end
    return node.results
end

local function cache_put(cache, params, results)
    local node = cache
    local param
    for i = 1, #params do
        param = params[i]
        node.children = node.children or {}
        node.children[param] = node.children[param] or {}
        node = node.children[param]
    end
    node.results = results
end

local function memoize(f)
    local cache = {}

    return function(...)
        local params = { ... }

        local results = cache_get(cache, params)
        if not results then
            results = { f(...) }
            cache_put(cache, params, results)
        end

        return unpack(results)
    end
end

return memoize
