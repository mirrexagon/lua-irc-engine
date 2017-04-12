local _version = "5.2.1"
local _rock_version = "5.2.1"
local _release = "1"

package = "irc-engine"
version = _rock_version .. "-" .. _release

source = {
	url = "https://github.com/mirrexagon/lua-irc-engine/archive/v" .. _version .. ".tar.gz",
	dir = "lua-irc-engine-" .. _version
}

description = {
	summary = "A Lua IRC module that tries to be minimal and extensible.",
	detailed = [[
		Lua IRC Engine is a callback-based, basic IRC "translator".
		It provides basic message parsing and a way to easily add new command
		sending and handling functions, but leaves most of the actual processing
		of command content to the host application.
	]],
	homepage = "http://github.com/mirrexagon/lua-irc-engine",
	license = "CC0"
}

dependencies = {
	"lua >= 5.1"
}

build = {
	type = "builtin",
	modules = {
		-- Main module file.
		["irce"] = "init.lua",

		-- Standard modules.
		["irce.modules.base"] = "modules/base.lua",
		["irce.modules.message"] = "modules/message.lua",
		["irce.modules.channel"] = "modules/channel.lua",
		["irce.modules.motd"] = "modules/motd.lua",

		-- Utilities.
		["irce.util"] = "util.lua"
	}
}
