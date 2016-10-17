--- Include ---
local _NAME = (...):match("^(.+)%..+%.") -- Get parent module.

local IRCe = require(_NAME)
local util = require(_NAME .. ".util")
--- ==== ---


return {
	init = function(self, state)
		state.namelists = {}
	end,

	senders = {
		JOIN = function(self, state, channel, key)
			if key then
				return ("JOIN %s %s"):format(channel, key)
			else
				return "JOIN " .. channel
			end
		end,

		PART = function(self, state, channel, part_message)
			if part_message then
				return ("PART %s :%s"):format(channel, part_message)
			else
				return "PART " .. channel
			end
		end,

		TOPIC = function(self, state, channel, topic)
			if topic then
				return ("TOPIC %s :%s"):format(channel, topic)
			else
				return "TOPIC " .. channel
			end
		end
	},

	handlers = {
		JOIN = function(self, state, sender, params)
			local channel = params[1]
			return sender, channel
		end,

		PART = function(self, state, sender, params)
			local channel = params[1]
			local part_message = params[2]
			return sender, channel, part_message
		end,


		-- RPL_NOTOPIC
		["331"] = function(self, state, sender, params)
			local channel = params[2]
			local message = params[3]

			self:handle("TOPIC", channel, nil, message)
		end,

		-- RPL_TOPIC
		["332"] = function(self, state, sender, params)
			local channel = params[2]
			local topic = params[3]

			self:handle("TOPIC", channel, topic)
		end,


		-- Channel names list.
		-- RPL_NAMREPLY
		["353"] = function(self, state, sender, params)
			local kind = params[2]
			local channel = params[3]
			local list = util.string.words(params[4])

			local namelist = state.namelists[channel] or {}

			if not namelist.kind then namelist.kind = kind end

			 state.namelists[channel] = util.table.join(namelist, list)
		end,

		-- RPL_ENDOFNAMES
		["366"] = function(self, state, sender, params)
			local channel = params[2]
			local message = params[3]

			local namelist = state.namelists[channel]

			-- Clear this namelist, we're done with it.
			state.namelists[channel] = nil

			-- Run NAMES callback.
			self:handle("NAMES", sender, channel, namelist, namelist and namelist.kind, message)
		end
	},

	hooks = {
		[IRCe.DISCONNECT] = function(self, state)
			state.namelists = {}
		end
	}
}
