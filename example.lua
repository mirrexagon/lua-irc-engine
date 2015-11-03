--[[
	Example for Lua IRC Engine (https://github.com/legospacy/lua-irc-engine)
	Uses LuaSocket for network communication.
]]

local IRCe = require("irce")
print(IRCe._VERSION .. " running on " .. _VERSION)

local socket = require("socket.core")

---

local server = "irc.example.com"

local nick = "IRCe"
local username = "ircengine"
local realname = "IRC Engine"

local channel = "#example"

---

local irc = IRCe.new()

-- Path may change depending on your directory structure.
-- These should work for LuaRocks installations.
assert(irc:load_module(require("irce.modules.base")))
assert(irc:load_module(require("irce.modules.message")))
assert(irc:load_module(require("irce.modules.channel")))

---

local running = true

---

local client = socket.tcp()

irc:set_send_func(function(message)
    return client:send(message)
end)

client:settimeout(1)

---

irc:set_callback(IRCe.RAW, function(send, message)
	print(("%s %s"):format(send and ">>>" or "<<<", message))
end)

irc:set_callback("CTCP", function(sender, origin, command, params, pm)
	if command == "VERSION" then
		assert(irc:CTCP_REPLY(origin, "VERSION", "Lua IRC Engine - Test"))
	end
end)

irc:set_callback("001", function(...)
	assert(irc:JOIN(channel))
end)

irc:set_callback("PRIVMSG", function(sender, origin, message, pm)
	if message == "?quit" then
		assert(irc:QUIT("And away we go!"))
		running = false
	end
end)


irc:set_callback("NAMES", function(sender, channel, list, kind, message)
	print("---")
	if not list then
		print("No channel called " .. channel)
	else
		print(("Channel %s (%s):"):format(channel, kind))
		print("-")
		for _, nick in ipairs(list) do
			print(nick)
		end
	end
	print("---")
end)


irc:set_callback("USERMODE", function(sender, operation, mode)
	print(("User mode: %s%s"):format(operation, mode))
end)

irc:set_callback("CHANNELMODE", function(sender, operation, mode, param)
	print(("Channel mode: %s%s %s"):format(operation, mode, param))
end)

---

assert(client:connect(server, 6667))

assert(irc:NICK(nick))
assert(irc:USER(username, realname))


while running do
    irc:process(client:receive())
end

---

client:close()

---
