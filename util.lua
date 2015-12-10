local util = {}

---

-- Prints a formatted string.
function util.printf(s, ...)
	return print(string.format(s, ...))
end

-- Like printf, but throws an error with the formatted string
-- as the error message.
function util.errorf(s, ...)
	return error(string.format(s, ...))
end

---

util.string = {}

function util.string.split(str, delim)
	-- TODO: Write this.
end

-- Returns a table in which each element is a single character of str
-- such that `table.concat(util.string.chars(str)) == str`.
function util.string.chars(str)
	local charpattern = utf8.charpattern or "."
	local t = {}

	for c in str:gmatch(charpattern) do
		table.insert(t, c)
	end

	return t
end

-- Returns all the whitespace-separated words of str in a table.
function util.string.words(str)
	local result = {}

	for s in str:gmatch("%S+") do
		table.insert(result, s)
	end

	return result
end

-- Strips whitespace off the ends of a string.
function util.string.strip(str)
	return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

---

util.table = {}

-- Returns a deep copy of a table (with the same metatable).
function util.table.clone(t)
	local mt = getmetatable(t)
	local c = setmetatable({}, type(mt) == "table" and mt or {})

	for k, v in pairs(t) do
		if type(v) == "table" then
			c[k] = util.table.clone(v)
		else
			c[k] = v
		end
	end

	return c
end

-- Joins two or more tables together.
function util.table.join(...)
	local result = {}

	for _, tab in ipairs({...}) do
		-- Deal with number keys first so we can get them in order.
		for i, v in ipairs(tab) do
			table.insert(result, v)
		end

		for k, v in pairs(tab) do
			if not tonumber(k) then
				result[k] = v
			end
		end
	end

	return result
end

-- If t doesn't have a key that kv does, the key
-- and its value from kv will be added to t.
function util.table.fill(t, kv)
	for k, v in pairs(kv) do
		if not t[k] then
			t[k] = v
		end
	end
end

-- Returns a new table with the values of t as keys and vice versa.
function util.table.invert(t)
	local result = {}

	for k, v in pairs(t) do
		result[v] = k
	end

	return result
end

-- Checks whether t has all the keys listed in keys.
function util.table.has(t, keys)
	for _, c in ipairs(keys) do
		if not t[c] then return false end
	end

	return true
end

-- Like has, but on failure also returns a string detailing the missing fields.
function util.table.check(t, keys, msg)
	local missing = {}

	for _, c in ipairs(keys) do
		if not t[c] then
			table.insert(missing, c)
		end
	end

	if #missing > 0 then
		return false, ("%smissing fields: %s"):format(
			msg and (msg .. ": ") or "", table.concat(missing, ", "))
	else
		return true
	end
end

-- Returns the highest numerical key of t.
function util.table.maxn(t)
	local max = -math.huge

	for k, v in pairs(t) do
		if type(k) == "number" then
			max = math.max(k, max)
		end
	end

	return (max ~= -math.huge) and max
end

-- Returns the number of (non-nil) elements in t.
function util.table.nelem(t)
	local count = 0

	for k,v in pairs(t) do
		count = count + 1
	end

	return count
end

---

util.io = {}

-- Given a file handle, this function returns the size
-- of the file pointed to by that handle.
function util.io.filesize(file)
	local current = file:seek()
	local size = file:seek("end")
	file:seek("set", current)
	return size
end

---

util.math = {}

-- Rounds num to idp decimal places.
-- http://lua-users.org/wiki/SimpleRound
function util.math.round(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

-- Returns the integer part of n.
function util.math.truncate(n)
	return math.floor(n + 0.5)
end

-- Checks whether n is within min and max, inclusive.
function util.math.range(min, n, max)
	return (n >= min) and (n <= max)
end

-- Returns n if it is within min and max, or else
-- returns min or max if n is too high or low respectively.
function util.math.clamp(min, n, max)
	return math.max(math.min(n, max), min)
end

-- Returns 1 if n is positive, -1 if n is negative or 0 if n is 0.
function util.math.sign(n)
	return (n > 0) and 1 or (n < 0) and -1 or 0
end

-- Maps n from one range to another range.
function util.math.map(n, in_min, in_max, out_min, out_max)
	return (n - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

-- Wraps a value into a range, inclusive.
function util.math.wrap(min, n, max)
	local diff = (max - min + 1)

	if n < min then
		repeat n = n + diff until n >= min
	elseif n > max then
		repeat n = n - diff until n <= max
	end

	return n
end

-- Takes a range, a value and an increment, adds the increment to the value
-- and wraps it to the range, inclusive.
function util.math.cycle(low, n, high, inc)
	return util.math.wrap(low, n + inc, high)
end

return util
