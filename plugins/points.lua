local error = error
local print = print
local setmetatable = setmetatable
local assert = assert
local type = type
local tonumber = tonumber

local sqlite3 = require("lsqlite3")
local socket = require("socket")

local core = require("src.core")
local commands = require("src.commands")
local lang = require("src.lang")
local config = require("config.plugins.points")

local points_cache = {}
setmetatable(points_cache, {__mode = 'v'})

local plugin = {}

local function cmd_gamble(user, args)
    local amt = tonumber(args[1])
    if not amt then
        core.send_to_user(user.name, "!gamble <amount>")
        return
    end
    local target = plugin.get(user.name)
    if target.points - amt < 0 then
        core.send_to_user(user.name, "You don't have enough to gamble that amount!")
    else
        local gambleAmt = math.random(100)
        if gambleAmt > 60 then
            amt = amt * 2
            target.points = target.points + amt
            core.send_to_user(user.name, lang.points.gamble:format(gambleAmt, lang.points.won, amt, lang.points.points))
            print(user.name .. " rolled a " .. gambleAmt .. " and won " .. amt)
        elseif gambleAmt < 60 then
            target.points = target.points - amt
            core.send_to_user(user.name, lang.points.gamble:format(gambleAmt, lang.points.lost, amt, lang.points.points))
            print(user.name .. " rolled a " .. gambleAmt .. " and lost " .. amt)
        end
    end
end

local function cmd_give(user, args)
    if #args ~= 2 then
        core.send_to_user(user.name, "!give <user> <amount>")
        return
    end

    local amt = tonumber(args[2])
    if not amt then
        core.send_to_user(user.name, "!give <user> <amount>")
        return
    end

    local target = plugin.get(args[1])

    target.points = target.points + amt
    if target.points < 0 then target.points = 0 end
    plugin.persist(target)

    print(user.name .. " gave " .. amt .. " points to " .. target.name)
    core.send_to_user(user.name, lang.points.add:format(amt, lang.points.points, target.name))
end

local function cmd_check(user, args)
    local target = plugin.get(user.name)
    core.send_to_user(user.name, lang.points.check:format(target.points, lang.points.points))
end

function plugin.init()
    local sql = [[
        create table if not exists points
        (
            id integer primary key autoincrement,
            username varchar(25) unique,
            points integer
        );
    ]]
    local result = core.db():exec(sql)
    if result ~= sqlite3.OK then
        error("Unable to initialize database for points (error code " .. result .. ")")
    end

    for count in core.db():urows("select count(*) from points") do
        print("Points initialized with " .. count .. " users")
    end

    commands.register("give", "give a user points", cmd_give, "points.give")
    commands.register("check", "check how many points you have", cmd_check, "points.check")
    commands.register("gamble", "test your luck by gambling a certain amount of points to try and double that amount or lose it", cmd_gamble, "points.gamble")
end

function plugin.get(name)
    assert(type(name) == "string")

    if points_cache[name] then
        return points_cache[name]
    end

    local stm = core.db():prepare("select * from points where username like ?")
    stm:bind(1, name)

    local user
    for v in stm:nrows() do
        user = {
            id = v.id,
            name = v.name,
            points = v.points
        }
        local currentTime = socket.gettime()
        local lastTimeGiven = currentTime
        for v in pairs(user) do
            if lastTimeGiven + 60 < currentTime then
                lastTimeGiven = currentTime
                user.points = user.points + 2
            end
        end
        break
    end

    if not user then
        user = {
            name = name,
            points = config.initial_points
        }
    end

    points_cache[name] = user
    return user
end

function plugin.persist(user)
    assert(type(user) == "table")

    if user.id then
        local stm = core.db():prepare("update points set username = ?, points = ? where id = ?")
        stm:bind(1, user.name)
        stm:bind(2, user.points)
        stm:bind(3, user.id)
        for _ in stm:urows() do end
    else
        local stm = core.db():prepare("insert into points (username, points) values (?, ?)")
        stm:bind(1, user.name)
        stm:bind(2, user.points)
        for _ in stm:urows() do end

        stm = core.db():prepare("select id from points where username = ?")
        stm:bind(1, user.name)
        for id in stm:urows() do
            user.id = id
        end
    end
end

return plugin
