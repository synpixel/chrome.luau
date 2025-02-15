local process = require("@lune/process")
local fs = require("@lune/fs")

local NUM_RANDOM_CHARS = 6
local NUM_RETRIES = 2 ^ 31

local function assert_temp(): string
	assert(process.env.TEMP ~= nil, "Missing TEMP")
	assert(fs.isDir(process.env.TEMP), "TEMP is not a directory")
	return process.env.TEMP
end

local function characters_between(a: string, b: string): () -> string?
	local index = string.byte(a)
	local finish = string.byte(b)

	return function()
		local char = string.char(index)

		if index > finish then
			return nil
		end

		index += 1
		return char
	end
end

local function tempname(prefix: string, length: number): string
	local charset = {}

	for uppercase in characters_between("A", "Z") do
		table.insert(charset, uppercase)
	end

	for lowercase in characters_between("a", "z") do
		table.insert(charset, lowercase)
	end

	for digit in characters_between("0", "9") do
		table.insert(charset, digit)
	end

	local name = ""

	for _ = 1, length do
		local char = charset[math.random(1, #charset)]
		name ..= char
	end

	return prefix .. name
end

local function tempfile(prefix: string): string
	local temp = assert_temp()

	for _ = 0, NUM_RETRIES do
		local name = tempname(prefix, NUM_RANDOM_CHARS)
		local path = `{temp}/{name}`

		if fs.isFile(path) or fs.isDir(path) then
			continue
		end

		return path
	end

	error("Too many temporary files exist")
end

return tempfile
