local print = print

local info = {}

function info.version()
    return "1.0.0"
end

function info.print_preamble()
    print("EBot version " .. info.version())
    print("The bot to end all other bots!")
end

return info
