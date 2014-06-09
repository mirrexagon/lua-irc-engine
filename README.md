Lua IRC
=======
A (soon-to-be) Lua IRC module that tries to be very extensible.

The construction "{TODO: [text]}" indicates something I still have to document or figure out how to implement.

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

To remain usable in more situations, the module doesn't make use of a specfic socket system. Instead, you set a function for `irc.send_raw` to use with `irc:set_raw_func()`:
```lua
-- Using LuaSocket:
local socket = require("socket.core")
local client = socket.tcp()
client:connect("irc.server.domain", 6667)

irc:set_raw(function(message)
	client:send(message)
end)
```

`irc.send_raw` will properly terminate the message with `\r\n\r\n`, and so it is not necessary to do this in the function you provide.

---

On top of that, there are __sender functions__. They take some arguments and send a message constructed from those arguments. They work something like this:
```lua
irc:privmsg("#potato", "I like potatoes")
```

Sender functions aren't actually stored on the top level of the object (eg. `irc.privmsg`). They are actually stored in `irc.senders`. They take the arguments and return a string to be sent as a raw message.

They are meant to be used with `irc:send(command, ...)`, like this:
```lua
irc:send("PRIVMSG", "#potato", "I like potatoes.")
```

which executes the equivalent of:
```lua
irc:send_raw( irc.senders.PRIVMSG("#potato", "I like potatoes.") )
```

The IRC object's metatable is set up so that you can use this syntax:
```lua
irc:privmsg("#potato", "I like potatoes.") -- {TODO: I'm unsure whether I want to keep this syntax or not.}
```


Extending the module
====================

Handler functions
-----------------

Each IRC command can have exactly one handler function.

They take the sender and the command parameters as a table:
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

The handler can either send a reply, parse the parameters and return them, or both:
``` lua
-- The PING handler just sends a reply (namely, a pong).
function handle_ping(sender, params)
	-- {TODO: How to distinguish sending from returning parsed information? send_raw function?}
end

-- The PRIVMSG handler just returns parsed information.
function handle_privmsg(sender, params)
	local target = params[1] -- Nick or channel message was directed to.
	local msg = params[2] -- The message.
	local pm = not target:find("[#&]") -- Whether it was directly to a user or not.
	local origin = pm and sender[1] or target -- Where the message came from/where to send a reply to.

	return sender[1], origin, msg, pm -- Return parsed information.
end

-- {TODO: Example of both?}
```

Handler functions can be set with `irc:set_handler(command, func)`:
```lua
irc:set_handler("PRIVMSG", handle_privmsg)
```


Sender functions
----------------
As with handler functions, each IRC command can have exactly one sender function (although you can add ones that don't correspond to an IRC command).

Sender functions take whatever arguments they need and return the raw message to be sent:
```lua
function privmsg(target, message)
	return "PRIVMSG %s :%s":format(target, message)
end
```

Sender functions can be set with `irc:set_sender(command, func)`:
```lua
irc:set_sender("PRIVMSG", privmsg)
```


Modules
-------
{TODO: Come up with a good system for modules that can add handlers and senders.}
{TODO: How to handle conflicts that modules might introduce?}
