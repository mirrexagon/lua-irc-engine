-- Localisations --
local unpack = table.unpack or unpack
-- ============= --

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
		error(("set_sender: There is already a sender set for \"%s\""):format(command))
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
		error(("set_handler: There is already a handler set for \"%s\""):format(command))
	else
		self.handlers[command] = func
		return true
	end
end

function Base:clear_handler(command)
	self.handlers[handler] = nil
	return true
end

---

function Base:set_callback(command, func)
	local old = self.callbacks[command]
	if self.callbacks[command] then
		error(("set_callback: There is already a callback set for \"%s\""):format(command))
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

return {
	new = new
}
