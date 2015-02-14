Lua IRC Engine
==============
A Lua IRC module that tries to be minimal and extensible.

Lua IRC Engine is a basic IRC "translator". It provides basic message parsing and a way to add simple sending convenience functions and command interpreters/handlers, but leaves most of the actual processing of command content to the host application. For example, it does not keep a list of joined channels or even know what its nick is.

See irc-engine.lua for license information.


Example
=======
This is a quick example using LuaSocket.

```lua
local IRCe = require("irc-engine")
local socket = require("socket.core")

---

local server = "irc.example.com"

local nick = "IRC_Engine"
local username = "ircengine"
local realname = "IRC Engine"

local channel = "#example"

---

local irc = IRCe.new()

assert(irc:load_module("base"))
assert(irc:load_module("message"))
assert(irc:load_module("channel"))

---

local running = true

---

local client = socket.tcp()
assert(client:connect(server, 6667))

irc:set_send_func(function(message)
    return client:send(message)
end)

client:settimeout(1)

---

assert(irc:NICK(nick))
assert(irc:USER(username, realname))

---

irc:set_callback("RAW", function(send, message)
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

---

while running do
    irc:process(client:receive())
end

---

client:close()
```


Usage
=====
Creating an object
------------------
To create an IRC object, use `IRCe.new()`:
```lua
local IRCe = require("irc-engine")

local irc = IRC.new()
```

From now on, this README assumes that `irc` is an IRC Engine object created as above.

---

Note: Much of the functionality of this module (eg. replying to server PINGs, sending PRIVMSGs with `irc.send`) is in submodules, none of which are loaded when the object is created. To load the standard modules, use:
```lua
irc:load_module("base")
irc:load_module("message")
irc:load_module("channel")
```
These modules are covered in more detail later in this README.

Sending
-------
At the most basic level, sending raw messages is done by `irc:send_raw(message)`:
```lua
irc:send_raw("PRIVMSG #potato :I like potatoes.")
```

To allow greater flexibility, this module doesn't make use of a specfic socket system. Instead, you set a function for `irc.send_raw` to use with `irc:set_send_func(func)`:
```lua
-- Using LuaSocket:
local socket = require("socket.core")
local client = socket.tcp()
client:connect("irc.server.domain", 6667)

irc:set_send_func(function(message)
	return client:send(message)
end)
```

On success, this function should return `true` (or any value other than `nil` or `false`); to signal an error, it should return `nil` (or `false`) and an error message (these return values are actually returned untouched to the caller of `send_raw`).

In this example, the LuaSocket TCP socket's `send` function returns the number of bytes it sent on success (which evaluates as `true`), and `nil` and an error message on failure; as such, the `send_func` can just return what it got from this.

`irc.send_raw` will properly terminate the message with `\r\n`, and so it is not necessary to do this in the function you provide.

---

To send things more easily, use `irc:send(command, ...)`, like this:
```lua
-- PRIVMSG takes the arguments (target, message), so this call is
-- irc:send("PRIVMSG", target, message)
irc:send("PRIVMSG", "#potato", "I like potatoes.")
```

The IRC object's metatable is set up so that you can use this syntax:
```lua
irc:PRIVMSG("#potato", "I like potatoes.")
```

For consistency, you can use `RAW` to send raw messages using `irc.send`:
```lua
irc:send("RAW", "PRIVMSG #potatoes :I like potatoes.")
-- is equivalent to
irc:send_raw("PRIVMSG #potatoes :I like potatoes.")
```

---

These functions just return what the provided `send_func` returns; so, to catch an error, you can raise an error by wrapping them in `assert`:
```lua
assert(irc:PRIVMSG("#potato", "I like potatoes."))
```

A better way is to check the return values and deal with the error in a way appropriate for your program:
```lua
local ok, err = irc:PRIVMSG("#potato", "I like potatoes.")
if not ok then
	-- Handle error.
end
```


Receiving
---------
To process a message received from a server, use `irc:process(msg)`. `msg` is a raw IRC message received from the server, although if you pass `nil` or `false`, `irc.process` will just silently ignore it and do nothing. It is usually called in a main loop, like this:
```lua
-- Using LuaSocket:
-- "client" is the TCP object from the "sending" section above.
client:settimeout(1)

while true do
	irc:process(client:receive())
end
```

---

When a message that your program might want to process is received, the appropriate callback is called, if it is set. You can set a callback with `irc:set_callback(command, func)`:

```lua
irc:set_callback("PRIVMSG", function(sender, origin, msg, pm)
	print( ("<%s> %s"):format(sender[1], msg) )
end)
```

`irc.set_callback` returns `true` on success, and raises an error if there is already a callback set for `command`.

Callbacks cannot be overwritten. `irc:clear_callback(command)` is used to clear a callback.

---

Nearly all callbacks receive a sender table as their first argument. These should not be confused with sender functions, discussed in the next section, "Extending the module".

Sender tables are derived from the message prefix, and are structured like this:

```lua
-- From a user:
sender = {
	[1] = "Nick",
	[2] = "username",
	[3] = "host.name"
}

-- or from a server:
sender = {
	[1] = "irc.server.domain"
}

-- or no prefix:
sender = {}
```

---

Whether a callback is actually called depends on whether a handler exists for the command, and whether it returns anything.

A callback will be called if:

- a handler exists and it returns something, or;
- if a handler does not exist for the command, in which case the callback gets the sender and the command parameters as arguments.

If a handler exists but doesn't return anything, the callback isn't called.

There is more information about handlers in the next section, "Extending the module".

---

There is a special callback called `RAW` which is called whenever an IRC message is sent or received. This is useful for printing raw messages to a console or logging them. Its first argument is `true` when the message is being sent or `false` when the message is being received, and the second argument is the message.


Extending the module
====================
Sender functions
----------------
Each IRC command can have exactly one sender function (although you can add ones that don't correspond to an IRC command, for example `CTCP`). They are stored in `irc.senders`.

`irc.send` calls these to construct a message.

Sender functions take the IRC object (in this case, in the variable `self`) and whatever arguments they need, and return the raw message to be sent:
```lua
function raw(self, msg)
	return msg
end

function privmsg(self, target, msg)
	return ("PRIVMSG %s :%s"):format(target, msg)
end

-- irc:translate() is called by irc:send() to turn the arguments into a raw message.
-- It can be called like this to chain senders.
function ctcp(self, target, command, params)
	return self:translate("PRIVMSG", target, ("\001%s %s\001"):format(command, params))
end
```

Sender functions can be set with `irc:set_sender(command, func)`:
```lua
-- RAW is actually already defined in an IRC object. This is just for demonstration.
irc:set_sender("RAW", raw)
irc:set_sender("PRIVMSG", privmsg)
irc:set_sender("CTCP", ctcp)
```

`irc.set_sender` returns `true` on success. If you try to set a sender for a command when one is already set, `irc.send_sender` will raise an error.

You can remove senders with `irc:clear_sender(command)`.


Handler functions
-----------------
As with sender functions, each IRC command can have exactly one handler function.

When a message is received, it is first processed by a handler function. This function can either respond to the message, it can parse the message and return information, or both. They are stored in `irc.handlers`.

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
params = "LegoSpacy :This is the MOTD!"
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

The handler can either send a reply, parse the parameters and return information, or both. The IRC object is exposed (again as `self` in these examples) so that the handler can send replies, or call other handlers or callbacks.
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

	return sender, origin, msg, pm -- Return parsed information.
end
```

Handler functions can be set and cleared with `irc:set_handler(command, func)` and `irc:clear_handler(command)`, and this works much the same as with senders.


Modules and the standard modules
================================
Senders and handlers can be added with modules. This module comes with some standard modules to provide some basic functionality.

---

A module is a file that returns a table, structured like so:
```lua
return {
	senders = {
		<command> = <func>,
		<command> = <func>,
		...
	},
	handlers = {
		<command> = <func>,
		<command> = <func>,
		...
	}
}
```

For example:
```lua
return {
	senders = {
		PONG = function(self, param)
			return "PONG :" .. param
		end
	},
	handlers = {
		PING = function(self, sender, params)
			self:send("PONG", params[1])
		end
	}
}
```

A module does not need to include both senders and handlers, and so either the `senders` or the `handlers` table can be omitted.

---

To load a module, use `irc:load_module(module_name)`:
```lua
irc:load_module("message")
```

When called, `irc.load_module` runs the equivalent of `require(_PACKAGE .. ".modules." .. module_name)`, where `_PACKAGE` is the directory containing IRC Engine's `init.lua`.

- If the module doesn't return a table, `irc.load_module` returns false and an error message, else;
- If the module returns a table, `irc.load_module` goes through it and adds senders and handlers defined in the appropriate subtables.
- If a module tries to set a sender or handler that already has been set by another module, the new module will not be loaded, and `irc.load_module` returns false and an appropriate error message.

Modules can be unloaded with `irc:unload_module(module_name)`. This will remove every handler and sender that the module added.


Standard modules
----------------
The senders are documented like this:
```
<COMMAND> (<arguments to sender>)
	<Description>
```
and the handlers like this:
```
<COMMAND> (<arguments passed to callback, if any>)
	<Description>
```

Senders prefixed with an underscore do not produce complete messages, and their output is meant to be encapsulated in another command, eg. `_CTCP` returns a message to be sent in a `PRIVMSG` or a `NOTICE`.

---

### Base
#### Senders
```
PING (param)
	Sends a PING with the "param" as the only parameter.

PONG (param)
	Like PING, but with PONG.

NICK (nick)
	Sends NICK with "nick" as the only parameter.

USER (username, realname, mode)
	Sends USER like so: USER <username> <mode> :<realname>
	If "mode" is omitted, 8 is sent as the mode.

QUIT (quit_msg)
	Sends a QUIT with the specified quit message, or with no message if it is omitted.

```

#### Callbacks
```
PING (sender, params)
	Called when a PING is received.
	Responds with a PONG, and passes the sender and parameter to the callback.

NICK (sender, new_nick)
	Called when someone changes their nickname.

QUIT (sender, quit_msg)
	Called when someone quits.
```

### Message
#### Senders
```
NOTICE (target, message)
	Sends a NOTICE with "message" as the message

PRIVMSG (target, message)
	As with NOTICE, but as a PRIVMSG

_CTCP (command, params)
	Used by CTCP and CTCP_REPLY to create a CTCP message.

CTCP (target, command, params)
	Sends a CTCP command in a PRIVMSG.
	"params" can be a list of parameters, or a string to be sent in the
		parameter section of the CTCP command (internally, "params" as a table
		is turned into a string with table.concat).

CTCP_REPLY (target, command, params)
	As above, but sent in a NOTICE.

ACTION (target, action)
	Uses CTCP to send an ACTION command.
```

#### Callbacks
```
NOTICE (sender, origin, message, pm)
	Called when a NOTICE is received.
	"origin" is the channel the message was sent to, or the nick of the sender
		if it's a private message. "pm" will be true if the message came directly
		from a user (ie. a private message) as opposed to from a channel.

PRIVMSG (sender, origin, message, pm)
	As with NOTICE, but for PRIVMSG.
	If a CTCP message is detected, processing is passed on to the
		CTCP handler, and the PRIVMSG callback isn't called.

CTCP (sender, origin, command, params, pm)
	Called when a CTCP message is received in a PRIVMSG.
	"params" is a table of parameters.
	If the command is ACTION, CTCP passes processing on to the ACTION handler,
		and the CTCP callback isn't called.

CTCP_REPLY (sender, origin, command, params, pm)
	As above, but for CTCPs in a NOTICE.

ACTION (sender, origin, action, pm)
	Called when an ACTION is received (ie. "/me <action>")
	Callback parameters are similar to PRIVMSG and NOTICE.
	Note that there is actually no handler with this name. Regardless, the
		associated callback is called.
```

### Channel
#### Senders
```
JOIN (channel, key)
	Attempts to join a channel.
	If "key" is included, it is sent as the channel access key.

PART (channel, part_message)
	Parts from a channel.
	If "part_message" is included, it is sent as the part message.
```

#### Callbacks
```
JOIN (sender, channel)
	Called when someone joins a channel.

PART (sender, channel, part_message)
	Called when someone parts from a channel.
	If a part message was supplied, it is passed to the callback.

353 (channel, list, kind)
	This is channel user list reply code.
	The handler returns the channel name, the list of users and the
		kind of channel (@ (secret), * (private) or = (public/other)).

MODE (sender, operation, modes, target)
	Handles both channel and user modes.
	If it is a channel mode message:
		"sender" is who changed the mode
		"operation" is + or -
		"modes" is a list of the modes
		"target" is a list of who is receiving the modes
	If it is a user mode message:
		"sender" is nil
		"operation" is + or -
		"modes" is a list of the modes
		"target" is who is receiving the modes, probably you
```
