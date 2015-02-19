-- Utility functions
local function string_splitchar(str)
	local t = {}
	for c in str:gmatch(".") do
		table.insert(t, c)
	end
	return t
end

local function string_explode(str)
	local result = {}
	for s in str:gmatch("%S+") do
		table.insert(result, s)
	end
	return result
end

local function table_join(...)
	local result = {}
	for _, tab in ipairs({...}) do
		---
		-- Deal with number keys first so we can get them in order.
		for i, v in ipairs(tab) do
			table.insert(result, v)
		end

		for k, v in pairs(tab) do
			if not tonumber(k) then
				result[k] = v
			end
		end
		---
	end
	return result
end

---

local namelists = setmetatable({}, {__mode = "k"})

return {
	senders = {
		JOIN = function(self, channel, key)
			if key then
				return ("JOIN %s %s"):format(channel, key)
			else
				return "JOIN " .. channel
			end
		end,

		PART = function(self, channel, part_message)
			if part_message then
				return ("PART %s :%s"):format(channel, part_message)
			else
				return "PART " .. channel
			end
		end,


		TOPIC = function(self, channel, topic)
			if topic then
				return ("TOPIC %s :%s"):format(channel, topic)
			else
				return "TOPIC " .. channel
			end
		end
	},

	handlers = {
		JOIN = function(self, sender, params)
			local channel = params[1]
			return sender, channel
		end,

		PART = function(self, sender, params)
			local channel = params[1]
			local part_message = params[2]
			return sender, channel, part_message
		end,

		MODE = function(self, sender, params)
			local target = params[1]
			local mode_string = params[2]

			local operation = mode_string:sub(1, 1)
			mode_string = mode_string:sub(2)

			local modes = string_splitchar(mode_string)

			if target:find("[#&]") then
				-- Channel mode.
				local mode_params = {}
				for i = 3, #params do
					mode_params[i-2] = params[i]
				end
				return sender, operation, modes, mode_params
			else
				-- User mode.
				return nil, operation, modes, target
			end
		end,


		-- RPL_NOTOPIC
		["331"] = function(self, sender, params)
			return sender, params[2], params[3]
		end,

		-- RPL_TOPIC
		["332"] = function(self, sender, params)
			return sender, params[2], params[3]
		end,


		-- Channel names list.
		-- RPL_NAMREPLY
		["353"] = function(self, sender, params)
			local target = params[1]
			local kind = params[2]
			local channel = params[3]
			local list = string_explode(params[4])

			-- TODO: Is it worth supporting the RFC1459 specification of not
			-- having a channel type parameter?

			-- Get or create the persistent list.
			-- TODO: Should any of these tables be weak?
			namelists[self] = namelists[self] or {}
			local state_list = namelists[self][channel] or {}

			if not state_list.kind then state_list.kind = kind end

			namelists[self][channel] = table_join(state_list, list)

			---

			return sender, channel, list, kind
		end,

		-- RPL_ENDOFNAMES
		["366"] = function(self, sender, params)
			local target = params[1]
			local channel = params[2]
			local message = params[3]

			local state_list
			if namelists[self] then
				state_list = namelists[self][channel]
				namelists[self][channel] = nil
			end

			self:handle("NAMES", sender, channel, state_list, state_list and state_list.kind, message)

			---

			return sender, channel, message
		end
	}
}
