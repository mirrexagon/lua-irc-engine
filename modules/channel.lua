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

		-- TODO: 353 (user list).
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
		end
    }
}
