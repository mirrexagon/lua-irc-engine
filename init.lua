local IRCe = {
	_VERSION = "Lua IRC Engine v5.2.1",
	_DESCRIPTION = "A Lua IRC module that tries to be minimal and extensible.",
	_URL = "https://github.com/mirrexagon/lua-irc-engine",
	_LICENSE = [[
		Lua IRC engine is released into the public domain via CC0 (https://creativecommons.org/publicdomain/zero/1.0).
	]]
}


--- Require ---
local _NAME = ...

local util = require(_NAME .. ".util")
--- ==== ---


--- Utility functions ---
local unpack = table.unpack or unpack
--- ==== ---


--- Constants ---
--- Unique values for special callbacks.

-- Raw IRC messages in both directions.
IRCe.RAW = setmetatable({}, {__tostring = function() return "IRCe RAW" end})

-- Host program should call this when a disconnect occurs.
IRCe.DISCONNECT = setmetatable({}, {__tostring = function() return "IRCe DISCONNECT" end})

-- Called for every callback, with the command name as the first argument after `self`.
IRCe.ALL = setmetatable({}, {__tostring = function() return "IRCe ALL" end})
--- ==== ---


--- === <> === ---


--- Base object definition ---
local Base = {}
--- ==== ---


--- Module state ---
function Base:get_state_for(kind, command)
	local mod = self.modules[kind][command]

	if mod then
		return self.modules.state[mod]
	end
end

function Base:get_sender_state(command)
	return self:get_state_for("senders", command)
end

function Base:get_handler_state(command)
	return self:get_state_for("handlers", command)
end
--- ==== ---


--- Sending ---
-- Low-level --
function Base:set_send_func(func)
	self.send_func = func
	return true
end

function Base:send_raw(str)
	-- Call RAW callback.
	self:handle(IRCe.RAW, false, str)

	return self.send_func(self.userobj, str .. "\r\n")
end
-- ==== --


-- High-level --
function Base:translate(command, ...)
	if self.senders[command] then
		local state = self:get_sender_state(command)
		return self.senders[command](self, state, ...)
	end
	-- TODO: Return an error message if the sender doesn't exist?
end

function Base:send(command, ...)
	return self:send_raw(self:translate(command, ...))
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
--- ==== ---


--- Receiving ---
-- IRCv3.2 tags
local escapers = {
	["s"] = " ";
	["r"] = "\r";
	["n"] = "\n";
	[":"] = ";";
	["\\"] = "\\";
}

local function parse_tags(tag_message)
	local tags = {}
	local cur_name
	local charbuf = {}
	local pos = 1
	local message_len = #tag_message

	while pos <= message_len do
		if tag_message:match("^\\", pos) then
			local lookahead = tag_message:sub(pos+1, pos+1)
			charbuf[#charbuf+1] = escapers[lookahead] or lookahead
			pos = pos + 2
		elseif cur_name then
			if tag_message:match("^;", pos) then
				tags[cur_name] = table.concat(charbuf)
				cur_name = nil
				charbuf = {}
				pos = pos + 1
			else
				charbuf[#charbuf+1], pos = tag_message:match("([^\\;]+)()", pos)
			end
		else
			if tag_message:match("^=", pos) then
				if #charbuf > 0 then
					cur_name = table.concat(charbuf)
					charbuf = {}
				end
				pos = pos + 1
			elseif tag_message:match("^;", pos) then
				if #charbuf > 0 then
					tags[table.concat(charbuf)] = true
					charbuf = {}
				end
				pos = pos + 1
			else
				charbuf[#charbuf+1], pos = tag_message:match("([^\\=;]+)()", pos)
			end
		end
	end

	-- Handle no trailing semicolon.
	if cur_name then
		tags[cur_name] = table.concat(charbuf)
	else
		tags[table.concat(charbuf)] = true
	end

	return tags
end

-- Main --
-- http://calebdelnay.com/blog/2010/11/parsing-the-irc-message-format-as-a-client
local function parse_message(message_tagged)
	-- Tags
	local tags, message
	if message_tagged:sub(1, 1) == "@" then
		local tag_space = message_tagged:find(" ")
		tags = parse_tags(message_tagged:sub(2, tag_space - 1))
		message = message_tagged:sub(tag_space + 1)
	else
		message = message_tagged
	end

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
	local the_rest = util.string.words(message:sub(
		prefix_end + 1, trailing_start))

	-- Returning results
	local command = the_rest[1]
	table.remove(the_rest, 1)
	table.insert(the_rest, trailing)
	return prefix, command, the_rest, tags
end

local function do_callbacks(self, command, ...)
	if select("#", ...) == 0 then
		-- Don't call callbacks or hooks if handler returned nothing
		return
	end

	-- Take reference to functions so unloading modules doesn't mess up iteration.
	local callback = self.callbacks[command]
	local all_callback = self.callbacks[IRCe.ALL]
	local hooks = {}
	for mod in pairs(self.modules.modules) do
		if mod.hooks and mod.hooks[command] then
			hooks[mod] = mod.hooks[command]
		end
	end

	if callback then callback(self.userobj, ...) end
	if all_callback then all_callback(self.userobj, command, ...) end

	-- Call module hooks.
	-- It'll be garbage collected eventually, letting the actual unloaded
	-- modules be collected too.
	for mod, hook in pairs(hooks) do
		local state = self.modules.state[mod] -- or nil

		hook(self, state, ...)
	end
end

-- Calls the handler for the command if there is one, then calls the callback.
function Base:handle(command, ...)
	local handler = self.handlers[command]

	-- Call the handler if it exists.
	if handler then
		local state = self:get_handler_state(command)
		return do_callbacks(self, command, handler(self, state, ...))
	else
		return do_callbacks(self, command, ...)
	end
end

function Base:process(message)
	if not message then return end

	-- Call RAW callback.
	self:handle(IRCe.RAW, true, message)

	---

	local prefix, command, params, tags = parse_message(message)

	local sender
	if prefix then
		local nick, username, host = prefix:match("^(.+)!(.+)@(.+)$")
		if nick and username and host then
			sender = {type = "user", nick, username, host}
		else
			sender = {type = "server", prefix}
		end
	else
		sender = {type = "none"}
	end

	self:handle(command, sender, params, tags)
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
--- ==== ---


--- Modules ---
function Base:load_module(module_table)
	local ERR_PREFIX = "Could not load module: "

	-- Make sure module is a table.
	if not module_table or type(module_table) ~= "table" then
		return false, ERR_PREFIX .. "module should be a table"
	end

	-- Make sure module isn't already loaded.
	if self.modules.modules[module_table] then
		return false, ERR_PREFIX .. "module already loaded"
	end

	---

	if module_table.senders then
		-- First, make sure the module doesn't add any already-present senders.
		for command, _ in pairs(module_table.senders) do
			if self.senders[command] then
				return false, ERR_PREFIX .. ("sender for \'%s\' already exists"):format(command)
			end
		end

		-- If it doesn't, go ahead and add the module's senders.
		for command, func in pairs(module_table.senders) do
			self:set_sender(command, func)

			-- Register that this module added this particular sender.
			self.modules.senders[command] = module_table
		end
	end

	if module_table.handlers then
		for command, _ in pairs(module_table.handlers) do
			if self.handlers[command] then
				return false, ERR_PREFIX .. ("handler for \'%s\' already exists"):format(command)
			end
		end

		for command, func in pairs(module_table.handlers) do
			self:set_handler(command, func)

			self.modules.handlers[command] = module_table
		end
	end

	---

	-- Keep a reference to the module.
	self.modules.modules[module_table] = module_table

	-- Create a state table for this module.
	local state = {}

	-- Run the module's init function.
	if module_table.init then
		module_table.init(self, state)
	end

	-- Save state.
	self.modules.state[module_table] = state

	return true
end

function Base:unload_module(module_table)
	local ERR_PREFIX = "Could not unload module: "

	if not self.modules[module_table] then
		return false, ERR_PREFIX .. "module not loaded"
	end

	---

	-- Run the module's deinit function.
	if module_table.deinit then
		local state = self.modules.state[module_table]
		module_table.deinit(self, state)
	end

	---

	if module_table.senders then
		for command in pairs(module_table.senders) do
			self:clear_sender(command)

			self.modules.senders[command] = nil
		end
	end

	if module_table.handlers then
		for command in pairs(module_table.handlers) do
			self:clear_handler(command)

			self.modules.handlers[command] = nil
		end
	end

	-- Erase the main reference to the module.
	self.modules.modules[module_table] = nil

	-- Erase the module's state.
	self.modules.state[module_table] = nil

	return true
end
--- ==== ---


--- Object creation ---
function IRCe.new(userobj)
	local o = setmetatable({
		senders = {
			[IRCe.RAW] = function(self, message)
				return message
			end
		},
		handlers = {},
		callbacks = {},

		modules = {
			modules = {}, -- Keeps module tables.
			state = {}, -- Keeps a state table for each module.

			senders = {}, -- Keeps track of which module added which
			handlers = {} -- sender or handler.
		}
	}, Base)

	o.userobj = userobj or o

	return o
end
--- ==== ---


return IRCe
