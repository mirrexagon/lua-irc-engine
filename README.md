Lua IRC
=======
A (soon-to-be) Lua IRC module that tries to be very extensible.

The construction `{TODO: [text]}` indicates something I still have to document or figure out how to implement.

I'm writing this README before the actual module so it can act as my plan.


Usage
=====

Creating an object
------------------
To create an IRC object, use `irc:new(args_table)`:
```lua
local IRC = require("irc")

local irc = IRC.new{
	nick = "Nick",
	username = "Username",
	realname = "My actual name",
	-- and so on.
}
```

The key-value pairs in the argument will be set in the resulting object.

From now on, this README assumes that `irc` is an IRC object created as above.


Receiving
---------
When a message is received, it is first processed by a __handler function__. This function can either respond to the message, it can parse the message and return information, or both. They are stored in `irc.handlers`. There is more information on handlers in the "Extending the module" section.

If the handler returns something, the appropriate callback is called, if it is set. You can set a callback with `irc:set_callback(command, func)`:

```lua
irc:set_callback("PRIVMSG", function(sender, origin, message, pm)
	print( "<%s> %s":format(sender, message) )
end)
```


Sending
-------
At the most basic level, sending raw messages is done by `irc:send_raw(message)`:
```lua
irc:send_raw("PRIVMSG #potato :I like potatoes.")
```

To remain usable in more situations, the module doesn't make use of a specfic socket system. Instead, you set a function for `irc.send_raw` to use with `irc:set_raw_sender(func)`:
```lua
-- Using LuaSocket:
local socket = require("socket.core")
local client = socket.tcp()
client:connect("irc.server.domain", 6667)

irc:set_raw_sender(function(message)
	client:send(message)
end)
```

`irc.send_raw` will properly terminate the message with `\r\n\r\n`, and so it is not necessary to do this in the function you provide.

---

On top of that, there are __sender functions__. They take some arguments, and construct a message from those arguments. Sender functions are stored in `irc.senders`.

They are meant to be used with `irc:send(command, ...)`, like this:
```lua
irc:send("PRIVMSG", "#potato", "I like potatoes.")
```

which executes the equivalent of:
```lua
irc:send_raw( irc.senders.PRIVMSG("#potato", "I like potatoes.") )
```

For consistency, there is a `RAW` sender. I prefer using `irc:send("RAW", ...)` as opposed to `irc:send_raw(...)` because it makes `irc.send` a consistent way to send things.
```lua
irc:send("RAW", "PRIVMSG #potatoes :I like potatoes.")
-- is equivalent to
irc:send_raw("PRIVMSG #potatoes :I like potatoes.")
```

The IRC object's metatable is set up so that you can use this syntax:
```lua
irc:PRIVMSG("#potato", "I like potatoes.")
-- {TODO: I'm unsure whether I want to keep this syntax or not.}
```


Extending the module
====================

Handler functions
-----------------
Each IRC command can have exactly one handler function.

They take the IRC object, the sender of the message and the command parameters as a table.

Here are some examples of how the message is broken up:
```lua
-- Example: ":nick!username@host.mask PRIVMSG #channel :This is a message!"

command = "PRIVMSG"

-- This happens internally. --
prefix = "nick!username@host.mask"
params = "#channel :This is a message!"
-- ======================== --

sender = {
	[1] = "nick",
	[2] = "username",
	[3] = "host.mask"
}

params = {
	[1] = "#channel",
	[2] = "This is a message!"
}
```
```lua
-- Example: ":irc.server.domain 372 LegoSpacy :This is the MOTD!"

command = "372"

-- ======== --
prefix = "irc.server.domain"
params = ":This is the MOTD!"
-- ======== --

sender = {
	[1] = "irc.server.domain"
}

params = {
	[1] = "LegoSpacy",
	[2] = "This is the MOTD!"
}
```
```lua
-- Example: "PING :irc.server.domain"

command = "PING"

-- ======== --
prefix = ""
params = ":irc.server.domain"
-- ======== --

sender = {}

params = {
	[1] = "irc.server.domain"
}
```

The handler can either send a reply, parse the parameters and return information, or both. The IRC object is exposed (as `self` in these examples) so that the handler can send replies and read things like `irc.version` (eg. in a CTCP handler).
``` lua
-- The PING handler just sends a reply (namely, a pong).
function handle_ping(self, sender, params)
	self:send("RAW", "PONG :" .. params[1])
end

-- The PRIVMSG handler just returns parsed information.
function handle_privmsg(self, sender, params)
	local target = params[1] -- Nick or channel message was directed to.
	local msg = params[2] -- The message.
	local pm = not target:find("[#&]") -- Whether it was directly to a user or not.
	local origin = pm and sender[1] or target -- Where the message came from.
	-- The origin is generally where bots should send replies.

	return sender[1], origin, msg, pm -- Return parsed information.
end

-- {TODO: Example of both?}
```

Handler functions can be set with `irc:set_handler(command, func)`:
```lua
irc:set_handler("PRIVMSG", handle_privmsg)
```
`irc.set_handler` returns `true` on success.

If you try to set a handler for a command when one is already set, `irc.send_handler` will return `false` and an error message:
```lua
print( irc:set_handler("PRIVMSG", handle_more_privmsg) )
	--> false	set_handler: Handler for "PRIVMSG" already set
```


Sender functions
----------------
As with handler functions, each IRC command can have exactly one sender function (although you can add ones that don't correspond to an IRC command).

Sender functions take the IRC object (again in the variable `self`) and whatever arguments they need, and return the raw message to be sent:
```lua
function raw(message)
	return message
end

function privmsg(self, target, message)
	return "PRIVMSG %s :%s":format(target, message)
end
```

Sender functions can be set with `irc:set_sender(command, func)`:
```lua
irc:set_sender("RAW", raw)
irc:set_sender("PRIVMSG", privmsg)
```

As with `irc.set_handler`, `irc.set_sender` returns `true` on success. On failure, it returns `false` and an error message.


Modules
-------
- {TODO: Come up with a good system for modules that can add handlers and senders.}
- {TODO: How to handle conflicts that modules might introduce?}
