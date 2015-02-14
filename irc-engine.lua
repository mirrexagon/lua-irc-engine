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

---

-- Localisations
local unpack = table.unpack or unpack

-- Utility functions
local function string_explode(str)
	local result = {}
	for s in str:gmatch("%S+") do
		table.insert(result, s)
	end
	return result
end

---

local Base = {}

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

---

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

---

function Base:translate(command, ...)
	if self.senders[command] then
		return self.senders[command](self, ...)
	end
end

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

---
---

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

---

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

---

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

---
---

function Base:set_module_dir(dir)
	self.module_dir = dir
end

-- TODO: Rewrite using require, use _PACKAGE so IRCe module directory can be relative to irc-engine.lua
function Base:load_module(module_name)
	if self.modules[module_name] then
		return false, ("load_module: Could not load module \"%s\": %s"):format(module_name, "module already loaded")
	end

	local searchdir = self.module_dir or "modules"

	local ok, modt = pcall(dofile, ("%s/%s.lua"):format(searchdir, module_name))
	if not ok then
		return false, ("load_module: Could not load module \"%s\": %s"):format(module_name, modt)
	end

	if not modt or type(modt) ~= "table" then
		return false, ("load_module: Could not load module \"%s\": %s"):format(module_name, "module does not return a table")
	end

	---

	if modt.senders then
		for command, func in pairs(modt.senders) do
			if self.senders[command] then
				return false, ("load_module: Could not load module \'%s\': %s"):format(module_name,
					("sender for \'%s\' already exists"):format(command))
			end
		end

		---

		for command, func in pairs(modt.senders) do
			self:set_sender(command, func)
		end
	end

	if modt.handlers then
		for command, func in pairs(modt.handlers) do
			if self.handlers[command] then
				return false, ("load_module: Could not load module \'%s\': %s"):format(module_name,
					("handler for \'%s\' already exists"):format(command))
			end
		end

		---

		for command, func in pairs(modt.handlers) do
			self:set_handler(command, func)
		end
	end

	self.modules[module_name] = modt
	return true
end

function Base:unload_module(module_name)
	local modt = self.modules[module_name]

	if not modt then
		return false, ("unload_module: Could not unload module \"%s\": %s"):format(module_name, "module not loaded")
	end

	if modt.senders then
		for command in pairs(self.modules[module_name].senders) do
			self:clear_sender(command)
		end
	end

	if modt.handlers then
		for command in pairs(self.modules[module_name].handlers) do
			self:clear_handler(command)
		end
	end

	self.modules[module_name] = nil

	return true
end

---
---

local function new()
	return setmetatable({
		senders = {
			RAW = function(message)
				return message
			end
		},
		handlers = {},
		callbacks = {},
		modules = {}
	}, Base)
end

IRCe.new = new

return IRCe
