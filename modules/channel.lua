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

---

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

		["353"] = function(self, sender, params)
			local target = params[1]
			local kind = params[2]
			local channel = params[3]
			local list = string_explode(params[4])

			-- TODO: Is it worth supporting the RFC1459 specification of not
			-- having a channel type parameter?

			return channel, list, kind
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
		end
	}
}
