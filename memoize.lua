local function cache_get(cache, params)
    for i = 1, #params do
        cache = cache.children and cache.children[params[i]]
        if not cache then return nil end
    end
    return cache.results
end

local function cache_put(cache, params, results)
    local param
    for i = 1, #params do
        param = params[i]
        cache.children = cache.children or {}
        cache.children[param] = cache.children[param] or {}
        cache = cache.children[param]
    end
    cache.results = results
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
