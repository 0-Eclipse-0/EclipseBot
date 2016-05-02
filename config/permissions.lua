local roles = {
    limited = {
        permissions = {
            "role.limited",
            "points.check"
        },
        throttle = 10,
        command_throttle = 20
    },
    user = {
        permissions = {
            "role.user",
            "util.ping",
            "util.whoami",
            "custom_commands.use",
            "raffle.enter",
            "poll.vote",
            "points.check",
            "points.gamble",
            "util.help"
        },
        throttle = 1,
        command_throttle = 3
    },
    trusted = {
        inherits = {"user"},
        permissions = {
            "role.trusted",
            "filter.bypass",
            "custom_commands.list"
        },
        throttle = -1,
        command_throttle = -1
    },
    mod = {
        inherits = {"trusted"},
        permissions = {
            "role.mod",
            "filter.allow"
        },
        autosetmod = true,
        throttle = -1,
        command_throttle = -1
    },
    admin = {
        inherits = {"mod"},
        permissions = {
            "role.admin",
            "util.help",
            "util.set_role",
            "util.stop",
            "raffle.start",
            "raffle.end",
            "raffle.cancel",
            "poll.start",
            "poll.end",
            "custom_commands.add",
            "custom_commands.delete",
            "timed_messages.add",
            "timed_messages.delete",
            "timed_messages.list",
            "filter.block",
            "filter.unblock",
            "twitch.mod",
            "points.give"
        },
        autosetmod = true,
        throttle = -1,
        command_throttle = -1
    }
}

return roles
