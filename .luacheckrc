ignore = {
	"212", -- Unused arguments.
	"unpack" -- Unpack not being defined.
}

-- Shadowed self. Hopefully doesn't hide other useful warnings
files["init.lua"] = {ignore = {"432"}}
files["spec"] = {std = "+busted"}
