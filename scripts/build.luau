local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

type TypeDefinition = {
	name: string,
	description: string,
	optional: boolean?,
	type: string?,
	enum: { string }?,
	items: TypeDefinition?,
	properties: { TypeDefinition }?,
	["$ref"]: string?,
}

type CommandDefinition = {
	name: string,
	parameters: { TypeDefinition }?,
	returns: { TypeDefinition }?,
}

type EventDefinition = {
	name: string,
	parameters: { TypeDefinition }?,
}

type DomainDefinition = {
	domain: string,
	dependencies: { string }?,
	types: { TypeDefinition & { id: string } }?,
	commands: { CommandDefinition }?,
	events: { EventDefinition }?,
}

type ProtocolDefinition = {
	domains: { DomainDefinition },
}

local IN = "json"
local OUT = "src/protocol"
local FORMAT = false

local function stylua(input: string): string
	local result = process.spawn("stylua", { "-" }, { stdin = input, shell = true })
	assert(result.ok, result.stderr)

	return result.stdout
end

local function readJson(path: string): any
	local file = fs.readFile(path)
	return serde.decode("json", file)
end

local function fixKey(key: string): string
	if key == "function" or key == "end" then
		return `["{key}"]`
	end

	return key
end

local function translateType(definition: TypeDefinition): string
	local optionalSuffix = if definition.optional then "?" else ""

	if definition["$ref"] ~= nil then
		return definition["$ref"] .. optionalSuffix
	end

	if definition.enum ~= nil then
		local enum = {}

		for _, value in definition.enum do
			table.insert(enum, `"{value}"`)
		end

		return table.concat(enum, "|") .. optionalSuffix
	end

	if definition.type == "array" then
		if definition.items == nil then
			return "{}"
		end

		return `\{ {translateType(definition.items)} \}` .. optionalSuffix
	end

	if definition.type == "object" then
		if definition.properties == nil then
			return "{}"
		end

		local translated = "{"

		for _, property in definition.properties do
			translated ..= `{fixKey(property.name)}: {translateType(property)},`
		end

		translated ..= "}"

		return translated .. optionalSuffix
	end

	if definition.type == "integer" then
		return "number" .. optionalSuffix
	end

	assert(definition.type ~= nil, `Unsupported type: {stdio.format(definition)}`)
	return definition.type .. optionalSuffix
end

local function writeDomainDefinition(domain: DomainDefinition): string
	local file = ""

	if domain.dependencies ~= nil then
		for _, dependency in domain.dependencies do
			file ..= `local {dependency} = require("./{dependency}")\n`
		end
	end

	if domain.types ~= nil then
		for _, type in domain.types do
			file ..= `export type {type.id} = {translateType(type)}\n`
		end
	end

	file ..= "return table.freeze({"

	if domain.commands ~= nil then
		for _, command in domain.commands do
			local requestType: string

			if command.parameters == nil then
				requestType = "nil"
			else
				requestType = "{"

				for _, parameter in command.parameters do
					requestType ..= `{fixKey(parameter.name)}: {translateType(parameter)},`
				end

				requestType ..= "}"
			end

			local responseType: string
			if command.returns == nil then
				responseType = "nil"
			else
				responseType = "{"

				for _, ret in command.returns do
					responseType ..= `{fixKey(ret.name)}: {translateType(ret)},`
				end

				responseType ..= "}"
			end

			local pascalName = command.name:sub(1, 1):upper() .. command.name:sub(2)
			file ..= `{pascalName} = "{domain.domain}.{command.name}" :: string & \{ __Request: {requestType}, __Response: {responseType} \},`
		end
	end

	if domain.events ~= nil then
		for _, event in domain.events do
			local paramsType: string

			if event.parameters == nil then
				paramsType = "nil"
			else
				paramsType = "{"

				for _, parameter in event.parameters do
					paramsType ..= `{fixKey(parameter.name)}: {translateType(parameter)},`
				end

				paramsType ..= "}"
			end

			local pascalName = event.name:sub(1, 1):upper() .. event.name:sub(2)
			file ..= `{pascalName} = "{domain.domain}.{event.name}" :: string & \{ __Parameters: {paramsType} \},`
		end
	end

	file ..= "})"

	return if FORMAT then stylua(file) else file
end

local browserDefinition = readJson(`{IN}/browser_protocol.json`) :: ProtocolDefinition
local jsDefinition = readJson(`{IN}/js_protocol.json`) :: ProtocolDefinition

if fs.isDir(OUT) == false then
	fs.writeDir(OUT)
end

for _, domain in browserDefinition.domains do
	local file = writeDomainDefinition(domain)
	fs.writeFile(`{OUT}/{domain.domain}.luau`, file)
end

for _, domain in jsDefinition.domains do
	local file = writeDomainDefinition(domain)
	fs.writeFile(`{OUT}/{domain.domain}.luau`, file)
end
