local IRCe = {
	_VERSION = "Lua IRC Engine v2.0.0",
	_DESCRIPTION = "A Lua IRC module that tries to be minimal and extensible.",
	_URL = "https://github.com/legospacy/lua-irc-engine",
	_LICENSE = [[
		Copyright (c) 2014-2015 Andrew Abbott

		Permission is hereby granted, free of charge, to any person obtaining a copy
		of this software and associated documentation files (the "Software"), to deal
		in the Software without restriction, including without limitation the rights
		to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
		copies of the Software, and to permit persons to whom the Software is
		furnished to do so, subject to the following conditions:

		The above copyright notice and this permission notice shall be included in
		all copies or substantial portions of the Software.

		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
		IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
		FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
		AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
		LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
		OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
		THE SOFTWARE.
	]]
}


---- Utility functions ----
local unpack = table.unpack or unpack

local function string_explode(str)
	local result = {}
	for s in str:gmatch("%S+") do
		table.insert(result, s)
	end
	return result
end
---- ==== ----

---- Constants ----
-- Unique values for callbacks.
IRCe.RAW = {}
IRCe.DISCONNECT = {}
---- ==== ----


------ ======= ------


local Base = {}

---- Sending ----
-- Low-level --
function Base:set_send_func(func)
	self.send_func = func
	return true
end

function Base:send_raw(str)
	-- Call RAW callback.
	self:handle(IRCe.RAW, false, str)
	self:handle("RAW", false, str) -- COMPAT - For backwards compatibility.

	return self.send_func(str .. "\r\n")
end
-- ==== --

-- High-level --
function Base:translate(command, ...)
	if self.senders[command] then
		return self.senders[command](self, ...)
	end
end

function Base:send(command, ...)
	if self.senders[command] then
		return self:send_raw(self:translate(command, ...))
	end
end

Base.__index = function(self, key)
	if self.senders[key] then
		return function(self, ...)
			return self:send(key, ...)
		end
	else
		return rawget(Base, key)
	end
end
-- ==== --

-- Setting and clearing senders --
function Base:set_sender(command, func)
	if self.senders[command] then
		return nil, ("There is already a sender set for \"%s\""):format(command)
	else
		self.senders[command] = func
		return true
	end
end

function Base:clear_sender(command)
	self.senders[command] = nil
	return true
end
-- ==== --
---- ==== ----


---- Receiving ----
-- Main --
-- http://calebdelnay.com/blog/2010/11/parsing-the-irc-message-format-as-a-client
local function parse_message(message)
	-- Prefix
	local prefix_end = 0
	local prefix
	if message:find(":") == 1 then
		prefix_end = message:find(" ")
		prefix = message:sub(2, prefix_end - 1)
	end

	-- Trailing parameter
	local trailing
	local trailing_start = message:find(" :")
	if trailing_start then
		trailing = message:sub(trailing_start + 2)
	else
		trailing_start = #message
	end

	-- Command and parameters
	local the_rest = string_explode(message:sub(
		prefix_end + 1, trailing_start))

	-- Returning results
	local command = the_rest[1]
	table.remove(the_rest, 1)
	table.insert(the_rest, trailing)
	return prefix, command, the_rest
end

-- Calls the handler for the command if there is one, then calls the callback
-- if the handler returned anything and there is a callback for this command.
function Base:handle(command, ...)
	local handler = self.handlers[command]
	local callback = self.callbacks[command]
	local handler_return

	if self.handlers[command] then
		handler_return = {handler(self, ...)}
	end

	local args = (handler_return and #handler_return > 0)
		and handler_return or {...}

	if callback then
		callback(unpack(args))
	end

	-- Call module hooks.
	-- NOTE: Loading or unloading modules in a hook is a bad idea.
	for mod in pairs(self.modules) do
		if mod.hooks and mod.hooks[command] then
			mod.hooks[command](self, unpack(args))
		end
	end
end

function Base:process(message)
	if not message then return end

	-- Call RAW callback.
	self:handle(IRCe.RAW, true, message)
	self:handle("RAW", true, message) -- COMPAT - For backwards compatibility.

	---

	local prefix, command, params = parse_message(message)

	local sender
	if prefix then
		local nick, username, host = prefix:match("^(.+)!(.+)@(.+)$")
		if nick and username and host then
			sender = {nick, username, host}
		else
			sender = {prefix}
		end
	else
		sender = {}
	end

	self:handle(command, sender, params)
end
-- ==== --

-- Setting and clearing handlers --
function Base:set_handler(command, func)
	if self.handlers[command] then
		return nil, ("There is already a handler set for \"%s\""):format(command)
	else
		self.handlers[command] = func
		return true
	end
end

function Base:clear_handler(command)
	self.handlers[command] = nil
	return true
end
-- ==== --

-- Setting and clearing callbacks --
function Base:set_callback(command, func)
	if self.callbacks[command] then
		return nil, ("There is already a callback set for \"%s\""):format(command)
	else
		self.callbacks[command] = func
		return true
	end
end

function Base:clear_callback(command)
	self.callbacks[command] = nil
	return true
end
-- ==== --
---- ==== ----


---- Modules ---
function Base:load_module(module_table)
	local ERR_PREFIX = "Could not load module: "

	if not module_table or type(module_table) ~= "table" then
		return false, ERR_PREFIX .. "module should be a table"
	end

	if self.modules[module_table] then
		return false, ERR_PREFIX .. "module already loaded"
	end

	---

	if module_table.senders then
		for command, func in pairs(module_table.senders) do
			if self.senders[command] then
				return false, ERR_PREFIX .. ("sender for \'%s\' already exists"):format(command)
			end
		end

		for command, func in pairs(module_table.senders) do
			self:set_sender(command, func)
		end
	end

	if module_table.handlers then
		for command, func in pairs(module_table.handlers) do
			if self.handlers[command] then
				return false, ERR_PREFIX .. ("handler for \'%s\' already exists"):format(command)
			end
		end

		for command, func in pairs(module_table.handlers) do
			self:set_handler(command, func)
		end
	end

	self.modules[module_table] = true

	return true
end

function Base:unload_module(module_table)
	local ERR_PREFIX = "Could not unload module: "

	if not self.modules[module_table] then
		return false, ERR_PREFIX .. "module not loaded"
	end

	---

	if module_table.senders then
		for command in pairs(module_table.senders) do
			self:clear_sender(command)
		end
	end

	if module_table.handlers then
		for command in pairs(module_table.handlers) do
			self:clear_handler(command)
		end
	end

	self.modules[module_table] = nil

	return true
end
---- ==== ----


---- Object creation ----
function IRCe.new()
	return setmetatable({
		senders = {
			RAW = function(self, message)
				return message
			end
		},
		handlers = {},
		callbacks = {},
		modules = {}
	}, Base)
end
---- ==== ----


return IRCe
