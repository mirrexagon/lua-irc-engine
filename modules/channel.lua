local function string_splitchar(str)
	local t = {}
	for c in str:gmatch(".") do
		table.insert(t, c)
	end
	return t
end

return {
    senders = {
		JOIN = function(self, channel, key)
			if key then
				return ("JOIN %s %s"):format(channel, key)
			else
				return "JOIN " .. channel
			end
		end,

		PART = function(self, channel, part_msg)
			if part_msg then
				return ("PART %s :%s"):format(channel, part_msg)
			else
				return "PART " .. channel
			end
		end

		-- TODO: Channel MODE.
    },

    handlers = {
		JOIN = function(self, sender, params)
			local channel = params[1]
			return sender, channel
		end,

		PART = function(self, sender, params)
			local channel = params[1]
			local part_msg = params[2]
			return sender, channel, part_msg
		end,

		["353"] = function(self, sender, params)
			local channel = params[1]

			local list = {}
			for i = 2, #params do
				table.insert(list, params[i])
			end

			return channel, list
		end,

		MODE = function(self, sender, params)
			local target = params[1]
			local mode_string = params[2]

			local operation = mode_string:sub(1, 1)
			mode_string = mode_string:sub(2)

			if target:find("[#&]") then
				-- Channel mode.
				local modes = string_splitchar(mode_string)
				local mode_params = {params[3], params[4], params[5]}

				return sender, operation, modes, mode_params
			else
				-- User mode.
				return nil, operation, mode_string, target
			end
		end
    }
}
