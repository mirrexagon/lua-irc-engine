local util = {}

---

util.string = {}

function util.string.splitchar(str)
	local t = {}
	for c in str:gmatch(".") do
		table.insert(t, c)
	end
	return t
end

function util.string.explode(str)
	local result = {}
	for s in str:gmatch("%S+") do
		table.insert(result, s)
	end
	return result
end

---

util.table = {}

function util.table.join(...)
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

function util.table.clone(t)
	local c = setmetatable({}, getmetatable(t))
	for k, v in pairs(t) do
		if type(v) == "table" then
			c[k] = util.table.clone(v)
		else
			c[k] = v
		end
	end
	return c
end

---

return util
