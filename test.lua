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
assert(irc:load_module("msg"))
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

end)

---

client:connect(server, 6667)

irc:NICK(nick)
irc:USER(username, realname)

---

while true do
	 irc:process(client:receive())
end
