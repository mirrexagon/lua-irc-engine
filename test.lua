local socket = require("socket.core")
local IRC = require("irc-engine")

---

local irc = IRC.new()
local client = socket.tcp()

---

local server = "localhost"

local nick = "Mira"
local username = "mira"
local realname = "Mira Lua"

---

client:settimeout(1)
irc:set_send_func(function(message)
    client:send(message)
end)

---

assert(irc:load_module("base"))
assert(irc:load_module("message"))
assert(irc:load_module("channel"))

irc:set_callback("RAW", function(send, message)
	local prompt = send and ">>> " or "<<< "
	print(prompt .. message)
end)

---

irc:set_handler("001", function(self)
	self:JOIN("#test")
end)

irc:set_callback("PRIVMSG", function(sender, origin, msg, pm)
	print(("<%s> %s"):format(sender[1], msg))
end)

irc:set_callback("CTCP", function(sender, origin, command, params, pm)
	print(("CTCP <%s> %s -> %s"):format(sender[1], command, params[1]))
end)

irc:set_callback("ACTION", function(sender, origin, action, pm)
	print(("* %s %s"):format(sender[1], action))
end)

irc:set_callback("MODE", function(sender, operation, modes, params)
	print(sender and ("Channel mode by %s"):format(sender[1]) or "User mode")

	for i = 1, #modes do
		local param
		if type(params) == "table" then
			param = params[i]
		else
			param = params
		end
		print(operation .. modes[i] .. " => " .. param)
	end
end)

irc:set_callback("353", function(channel, list, kind)
	print("----")
	print(channel)
	print(kind)

	print("-")

	for _, user in ipairs(list) do
		print(user)
	end

	print("----")
end)

---

client:connect(server, 6667)

irc:NICK(nick)
irc:USER(username, realname)

---

while true do
	 irc:process(client:receive())
end
