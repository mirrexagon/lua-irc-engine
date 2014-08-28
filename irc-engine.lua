-- Utility functions --
local function string_explode(str)
	local result = {}
	for s in str:gmatch("%S+") do
		table.insert(result, s)
	end
	return result
end
-- ================= --

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

function Base:translate(command, ...)
	if self.senders[command] then
		return self.senders[command](self, ...)
	end
end

function Base:send(command, ...)
	if self.senders[command] then
		return self:send_raw( self:translate(command, ...) )
	end
end

Base.__index = function(self, key)
	if self.senders[key] then
		return function(self, ...)
			return self:send(key, ...)
		end
	else
		local self_v = rawget(self, key)
		if self_v then return self_v end

		local base_v = rawget(Base, key)
		if base_v then return base_v end
	end
end

---

function Base:set_sender(command, func)
	local old = self.senders[command]
	if old then
		return false, ("set_sender: There is already a sender set for \"%s\""):format(command)
	else
		self.senders[command] = func
		return true
	end

end

function Base:clear_sender(command)
	if not self.senders[command] then
		return false, ("clear_sender: There is no sender set for \"%s\""):format(command)
	else
		self.senders[command] = nil
		return true
	end
end

---
---

-- http://calebdelnay.com/blog/2010/11/parsing-the-irc-message-format-as-a-client
local function parse_message(msg)
	-- Prefix
	local prefix_end = 0
	local prefix
	if msg:find(":") == 1 then
		prefix_end = msg:find(" ")
		prefix = msg:sub(2, prefix_end - 1)
	end

	-- Trailing parameter
	local trailing
	local trailing_start = msg:find(" :")
	if trailing_start then
		trailing = msg:sub(trailing_start + 2)
	else
		trailing_start = #msg
	end

	-- Command and parameters
	local the_rest = string_explode(msg:sub(
		prefix_end + 1, trailing_start))

	-- Returning results
	local command = the_rest[1]
	table.remove(the_rest, 1)
	table.insert(the_rest, trailing)
	return prefix, command, the_rest
end

function Base:process(msg)
	if not msg then return end

	-- Call RAW callback.
	if self.callbacks["RAW"] then
		self.callbacks["RAW"](false, msg)
	end

	---

	local prefix, command, params = parse_message(msg)

	local sender
	if prefix then
		local nick, username, host = prefix:match("^(.+)!(.+)@(.+)$")
		if nick and username and host then
			sender = {nick, username, host}
		else
			sender = {prefix}
		end
	else
		sender = {""}
	end

	-- Call appropriate handler and possibly callback.
	if self.handlers[command] then
		if self.callbacks[command] then
			self.callbacks[command]( self.handlers[command](self, sender, params) )
		else
			self.handlers[command](self, sender, params)
		end
	end
end

---

function Base:set_handler(command, func)
	local old = self.handlers[command]
	if old then
		return false, ("set_handler: There is already a handler set for \"%s\""):format(command)
	else
		self.handlers[command] = func
		return true
	end

end

function Base:clear_handler(command)
	if not self.handlers[handler] then
		return false, ("clear_handler: There is no handler set for \"%s\""):format(command)
	else
		self.handlers[handler] = nil
		return true
	end
end

---

function Base:set_callback(command, func)
	local old = self.callbacks[command]
	if old then
		return false, ("set_callback: There is already a callback set for \"%s\""):format(command)
	else
		self.callbacks[command] = func
		return true
	end

end

function Base:clear_callback(command)
	if not self.callbacks[command] then
		return false, ("clear_callback: There is no callback set for \"%s\""):format(command)
	else
		self.callbacks[command] = nil
		return true
	end
end

---
---

function Base:set_module_dir(dir)
	self.module_dir = dir
end

function Base:load_module(module_name)
	local searchdir = self.module_dir or "modules"

	local ok, modt = pcall(dofile, ("%s/%s.lua"):format(searchdir, module_name))
	if not ok then
		return false, ("load_module: Could not load module \"%s\": %s"):format(module_name, modt)
	end

	if not modt or type(modt) ~= "table" then
		return false, ("load_module: Could not load module \"%s\": %s"):format(module_name, "module does not return a table")
	end

	---

	local module_added = {
		senders = {},
		handlers = {}
	}

	if modt.senders then
		for sender, func in pairs(modt.senders) do
			local ok = self:set_sender(sender, func)
			if not ok then
				return false,("load_module: Could not load module \"%s\": %s"):format(module_name,
					("module tried to overwrite sender \"%s\""):format(sender))
			else
				module_added.senders[sender] = sender
			end
		end
	end

	if modt.handlers then
		for handler, func in pairs(modt.handlers) do
			local ok = self:set_handler(handler, func)
			if not ok then
				return false,("load_module: Could not load module \"%s\": %s"):format(module_name,
					("module tried to overwrite handler \"%s\""):format(handler))
			else
				module_added.handlers[handler] = handler
			end
		end
	end

	self.modules[module_name] = module_added
	return true
end

function Base:unload_module(module_name)
	if not self.modules[module_name] then
		return false, ("unload_module: Could not unload module \"%s\": %s"):format(module_name, "module not loaded")
	end

	for sender in pairs(self.modules[module_name].senders) do
		self:clear_sender(sender)
	end

	for handler in pairs(self.modules[module_name].handlers) do
		self:clear_handler(handler)
	end
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

return {
	new = new
}
