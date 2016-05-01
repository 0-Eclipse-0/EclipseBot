require("src.stringutils")
local lang = require("src.lang")

local config = {
    rules = {
        {
            message = lang.filter.url,
            match = string.has_url
        },

        {
            message = lang.filter.caps,
            match = function(str) return #str > 4 and string.caps_percent(str) > 0.8 end
        },
        
        {
            message = lang.filter.symbols,
            match = function(str) return #str > 4 and string.symbols_percent(str) > 0.8 end
        }
    }
}

return config
