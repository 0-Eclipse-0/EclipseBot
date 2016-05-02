local require = require
local print = print
local error = error
local assert = assert
local insert = table.insert
local ipairs = ipairs
local type = type
local pcall = pcall

local irce = require("irce")
local socket = require("socket")
local sqlite3 = require("lsqlite3")

local info = require("src.info")
local config = require("config.config")
local plugins = require("config.plugins")
local users = require("src.users")
local commands = require("src.commands")
local lang = require("src.lang")

local core = {}

local client
local irc
local running = false
local db

local send_queue = {first = 0, last = -1 }
local last_send = 0

local premsg_hooks = {}
local msg_hooks = {}
local loop_hooks = {}
local stop_hooks = {}

local loaded_plugins = {}

function core.init()
    if running then
        error("Cannot re-initialize EBot when already running")
    end

    math.randomseed(os.time())

    info.print_preamble()

    print("Loading database...")
    local d,c,e = sqlite3.open("database.sqlite3")
    if not d then
        error(c .. ": " .. e)
    end
    db = d

    irc = irce.new()
    assert(irc:load_module(require("irce.modules.base")))
    assert(irc:load_module(require("irce.modules.message")))
    assert(irc:load_module(require("irce.modules.channel")))
    assert(irc:load_module(require("src.twitch_irc")))

    running = true
    client = socket.tcp()
    client:settimeout(1)

    irc:set_send_func(function(self, message)
        return client:send(message)
    end)

    function core.send(message)
        local last = send_queue.last + 1
        send_queue.last = last
        send_queue[last] = message
    end

    if config.debug_protocol then
        irc:set_callback("RAW", function(send, message)
            print(("%s %s"):format(send and ">>>" or "<<<", message))
        end)
    end

    irc:set_callback("001", function(...)
        assert(irc:JOIN(config.channel))
    end)

    irc:set_callback("JOIN", function(self, sender)
        if config.show_join_leave then
            print(sender[1] .. " joined")
            core.send(sender[1] .. " has joined your channel MrDestructoid . Mod him to experience his full potential! Just remember not to be PJSalt y while he is mod or you may feel his wrath!")
        end

        local user = users.get(sender[1])
        local role = users.get_role(user.role)
        if role.autosetmod then
            core.send(".mod " .. user.name)
        end
    end)

    if config.show_join_leave then
        irc:set_callback("PART", function(sender)
            print(sender[1] .. " left")
            core.send(sender[1], " left")
        end)
    end

    irc:set_callback("PRIVMSG", function(self, sender, origin, msg, pm)
        if config.show_messages then
            print(sender[1] .. ": " .. msg)
        end

        for _,hook in ipairs(premsg_hooks) do
            local status, result = pcall(hook, sender, origin, msg, pm)
            if not status then
                print(result)
                return
            end

            if not result then return end
        end

        for _,hook in ipairs(msg_hooks) do
            local status, result = pcall(hook, sender, origin, msg, pm)
            if not status then
                print(result)
                return
            end
        end
    end)

    print("Connecting to server " .. config.server .. ":" .. config.port)
    assert(client:connect(config.server, config.port))

    print("Connection successful, logging in as " .. config.username)
    assert(irc:PASS(config.token))
    assert(irc:NICK(config.username))

    users.init(core)
    commands.init(core)

    for _,name in ipairs(plugins) do
        print("Loading plugin " .. name)
        local plugin = require("plugins." .. name)
        loaded_plugins[name] = plugin
    end

    for name,plugin in pairs(loaded_plugins) do
        print("Initializing plugin " .. name)
        plugin.init()
    end

    while running do
        local status, err = pcall(core.loop)
        if not status then
            print(err)
        end
    end

    print "EBot is stopping!"

    print "Running stop hooks..."

    for _,hook in ipairs(stop_hooks) do
        local status, err = pcall(hook)
        if not status then print(err) end
    end

    print "Disconnecting..."
    client:close()

    print "Closing database..."
    db:close()

    print "Goodbye!"
end

function core.stop()
    print("Stopping EBot")
    running = false
end

function core.send_to_user(user, message)
    core.send(lang.global.to_user:format(user, message))
end

function core.timeout(user, n)
    n = n or 1
    core.send(".timeout " .. user .. " " .. n)
end

function core.db()
    return db
end

function core.client()
    return irc
end

function core.socket()
    return client
end

function core.getplugin(name)
    return loaded_plugins[name]
end

function core.hook_premessage(f)
    assert(type(f) == "function", "premessage hook must be a function")
    insert(premsg_hooks, f)
end

function core.hook_message(f)
    assert(type(f) == "function", "message hook must be a function")
    insert(msg_hooks, f)
end

function core.hook_loop(f)
    assert(type(f) == "function", "loop hook must be a function")
    insert(loop_hooks, f)
end

function core.hook_stop(f)
    assert(type(f) == "function", "stop hook must be a function")
    insert(stop_hooks, f)
end

function core.loop()
    irc:process(client:receive())
    if last_send < socket.gettime() and send_queue.first <= send_queue.last then
        local last = send_queue.last
        local message = send_queue[last]
        send_queue[last] = nil
        send_queue.last = last - 1
        irc:send("PRIVMSG", config.channel, message)
        last_send = socket.gettime()
    end

    for _,hook in ipairs(loop_hooks) do
        local status, result = pcall(hook)
        if not status then
            print(result)
            return
        end
    end
end

return core
