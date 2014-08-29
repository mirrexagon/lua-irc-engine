Lua IRC Engine
==============
A Lua IRC module that tries to be minimal and extensible.

Lua IRC Engine is a basic IRC "translator". It provides basic message parsing and a way to add sending convienience functions and command handlers, but leaves the actual processing of commands to the host application. For example, it does not keep a list of joined channels or even know what its nick is.

See the bottom of this README for license information.


Usage
=====
Creating an object
------------------
To create an IRC object, use `IRC.new()`:
```lua
local IRC = require("irc-engine")

local irc = IRC.new()
```

From now on, this README assumes that `irc` is an IRC Engine object created as above.


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
	client:send(message)
end)
```

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

When a message that your program might want to process is received and successfully parsed, the appropriate callback is called, if it is set. You can set a callback with `irc:set_callback(command, func)`:

```lua
irc:set_callback("PRIVMSG", function(sender, origin, msg, pm)
	print( ("<%s> %s"):format(sender, msg) )
end)
```

`irc.set_callback` returns `true` on success, or `false` and an error message otherwise.

Callbacks cannot be overwritten. `irc:clear_callback(command)` is used to clear a callback.

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
	return message
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

`irc.set_sender` returns `true` on success.

If you try to set a sender for a command when one is already set, `irc.send_sender` will return false and an error message.

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
Senders and handlers can be added with modules. This module comes with some standard modules to provide some standard IRC functions.

To load a module, use `irc:load_module(module_name)`.

For example, when running `irc:load_module("msg")`:

- `irc.load_module` will look in a directory (by default, `modules`) for `msg.lua`.
- If it finds `msg.lua`, it loads it. If the file doesn't return a table, `irc.load_module` returns false and an error message.
- If `msg.lua` returns a table, `irc.load_module` goes through it and adds senders and handlers defined in the appropriate subtables.

If a module tries to set a sender or handler that already has been set by another module, the new module will not be loaded and `irc.load_module` will return false and an appropriate error message.

A module can be unloaded with `irc:unload_module(module_name)`. This will remove every handler and sender that the module added.

By default, the loader will look for the module in a directory called `modules` in the directory the program was run, but you can change this with `irc:set_module_dir(dir)`. For example, `irc:set_module_dir("ircmodules")`.


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

Sender tables are derived from the message prefix and are structured like this:
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
sender = {""}
```

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
	Sends USER like so: User <username> <mode> :<realname>
	If "mode" is omitted, 8 is sent as the mode.

QUIT (quit_msg)
	Sends a QUIT with the specified quit message, or with no message if it is omitted.

```

#### Handlers
```
PING (params)
	Called when a PING is received.
	Responds with a PONG, and passes the single parameter to the callback.

NICK (sender, new_nick)
	Called when someone changes their nickname.
	Passes the sender table and the new nick of that sender to the callback.

QUIT (quit_msg)
	Called when someone quits.
	Passes the quit message (if there is one) to the callback.
```
`TODO: Document the rest.`
### Channel
#### Senders
```

```

#### Handlers
```

```

### Message
#### Senders
```

```

#### Handlers
```

```


More on modules
===============
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


License
=======
> Copyright (c) 2014 Andrew Abbott

> Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

> The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

> Except as contained in this notice, the name(s) of the above copyright holders
shall not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization.

> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
