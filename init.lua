local IRCe = {
	_VERSION = "Lua IRC Engine v1.0.2",
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
local _PACKAGE = (...):gsub("%.init$", "") -- Remove trailing ".init" if present.

local DEFAULT_IRCMODULE_DIR = "modules"
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
	if self.callbacks["RAW"] then
		self.callbacks["RAW"](true, str)
	end

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
		error(("set_sender: There is already a sender set for \"%s\""):format(command), 2)
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

	if callback then
		if handler_return and #handler_return > 0 then
			-- Handler exists and returned something.
			callback(unpack(handler_return))

		elseif not handler then
			-- Handler doesn't exist.
			callback(...)

		end -- Don't call callback if handler exists but didn't return anything.
	end
end

function Base:process(message)
	if not message then return end

	-- Call RAW callback.
	if self.callbacks["RAW"] then
		self.callbacks["RAW"](false, message)
	end

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
		error(("set_handler: There is already a handler set for \"%s\""):format(command), 2)
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
		error(("set_callback: There is already a callback set for \"%s\""):format(command), 2)
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
function Base:load_module(module_name)
	local module_dir = DEFAULT_IRCMODULE_DIR
	local module_reqname = ("%s.%s.%s"):format(_PACKAGE, module_dir, module_name)

	if package.loaded[module_reqname] then
		return false, ("load_module: Could not load module \'%s\': %s")
			:format(module_name, "module already loaded")
	end

	local ok, module_table = pcall(require, module_reqname)
	if not ok then
		return false, ("load_module: Could not load module \'%s\': %s")
			:format(module_name, module_table)
	end

	if not module_table or type(module_table) ~= "table" then
		return false, ("load_module: Could not load module \'%s\': %s")
			:format(module_name, "module does not return a table")
	end

	---

	if module_table.senders then
		for command, func in pairs(module_table.senders) do
			if self.senders[command] then
				return false, ("load_module: Could not load module \'%s\': %s")
					:format(module_name,
						("sender for \'%s\' already exists"):format(command))
			end
		end

		for command, func in pairs(module_table.senders) do
			self:set_sender(command, func)
		end
	end

	if module_table.handlers then
		for command, func in pairs(module_table.handlers) do
			if self.handlers[command] then
				return false, ("load_module: Could not load module \'%s\': %s")
					:format(module_name,
						("handler for \'%s\' already exists"):format(command))
			end
		end

		for command, func in pairs(module_table.handlers) do
			self:set_handler(command, func)
		end
	end
	return true
end

function Base:unload_module(module_name)
	local module_dir = DEFAULT_IRCMODULE_DIR
	local module_reqname = ("%s.%s.%s"):format(_PACKAGE, module_dir, module_name)

	local module_table = package.loaded[module_reqname]

	if not module_table then
		return false, ("unload_module: Could not unload module \'%s\': %s")
			:format(module_name, "module not loaded")
	end

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

	package.loaded[module_reqname] = nil

	return true
end
---- ==== ----


---- Object creation ----
function IRCe.new()
	return setmetatable({
		senders = {
			RAW = function(message)
				return message
			end
		},
		handlers = {},
		callbacks = {}
	}, Base)
end
---- ==== ----


return IRCe
