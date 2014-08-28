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
		end
    }
}
