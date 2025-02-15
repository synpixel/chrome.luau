local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local casing = require("../src/utils/casing")

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
local FORMAT = true

local function stylua(input: string): string
	local result = process.spawn("stylua", { "-" }, { stdin = input, shell = true })
	assert(result.ok, result.stderr)

	return result.stdout
end

local function read_json(path: string): any
	local file = fs.readFile(path)
	return serde.decode("json", file)
end

local function fix_key(key: string): string
	key = casing.camel_to_snake(key)

	if key == "function" or key == "end" then
		return `["{key}"]`
	end

	return key
end

local function translate_type(definition: TypeDefinition): string
	local optional_suffix = if definition.optional then "?" else ""

	if definition["$ref"] ~= nil then
		return definition["$ref"] .. optional_suffix
	end

	if definition.enum ~= nil then
		local enum = {}

		for _, value in definition.enum do
			table.insert(enum, `"{value}"`)
		end

		return table.concat(enum, "|") .. optional_suffix
	end

	if definition.type == "array" then
		if definition.items == nil then
			return "{}"
		end

		return `\{ {translate_type(definition.items)} \}` .. optional_suffix
	end

	if definition.type == "object" then
		if definition.properties == nil then
			return "{}"
		end

		local translated = "{"

		for _, property in definition.properties do
			translated ..= `{fix_key(property.name)}: {translate_type(property)},`
		end

		translated ..= "}"

		return translated .. optional_suffix
	end

	if definition.type == "integer" then
		return "number" .. optional_suffix
	end

	assert(definition.type ~= nil, `unsupported type: {stdio.format(definition)}`)
	return definition.type .. optional_suffix
end

local function write_domain_definition(domain: DomainDefinition): string
	local file = ""

	if domain.dependencies ~= nil then
		for _, dependency in domain.dependencies do
			file ..= `local {dependency} = require("./{dependency}")\n`
		end
	end

	if domain.types ~= nil then
		for _, type in domain.types do
			file ..= `export type {type.id} = {translate_type(type)}\n`
		end
	end

	file ..= "return table.freeze({"

	if domain.commands ~= nil then
		for _, command in domain.commands do
			local request_type: string

			if command.parameters == nil then
				request_type = "nil"
			else
				request_type = "{"

				for _, parameter in command.parameters do
					request_type ..= `{fix_key(parameter.name)}: {translate_type(parameter)},`
				end

				request_type ..= "}"
			end

			local response_type: string
			if command.returns == nil then
				response_type = "nil"
			else
				response_type = "{"

				for _, ret in command.returns do
					response_type ..= `{fix_key(ret.name)}: {translate_type(ret)},`
				end

				response_type ..= "}"
			end

			local pascal_name = command.name:sub(1, 1):upper() .. command.name:sub(2)
			file ..= `{pascal_name} = "{domain.domain}.{command.name}" :: string & \{ __Request: {request_type}, __Response: {response_type} \},`
		end
	end

	if domain.events ~= nil then
		for _, event in domain.events do
			local params_type: string

			if event.parameters == nil then
				params_type = "nil"
			else
				params_type = "{"

				for _, parameter in event.parameters do
					params_type ..= `{fix_key(parameter.name)}: {translate_type(parameter)},`
				end

				params_type ..= "}"
			end

			local pascal_name = event.name:sub(1, 1):upper() .. event.name:sub(2)
			file ..= `{pascal_name} = "{domain.domain}.{event.name}" :: string & \{ __Parameters: {params_type} \},`
		end
	end

	file ..= "})"

	return if FORMAT then stylua(file) else file
end

local function write_method_file(...: ProtocolDefinition): string
	local definitions = { ... }
	local file = ""

	for _, definition in definitions do
		for _, domain in definition.domains do
			if domain.commands == nil then
				continue
			end
			file ..= `local {domain.domain} = require("./{domain.domain}")\n`
		end
	end

	file ..= "return table.freeze({"

	for _, definition in definitions do
		for _, domain in definition.domains do
			if domain.commands == nil then
				continue
			end

			for _, command in domain.commands do
				local pascal_name = command.name:sub(1, 1):upper() .. command.name:sub(2)
				file ..= `{domain.domain}{pascal_name} = {domain.domain}.{pascal_name},`
			end
		end
	end

	file ..= "})"

	return if FORMAT then stylua(file) else file
end

local function write_event_file(...: ProtocolDefinition): string
	local definitions = { ... }
	local file = ""

	for _, definition in definitions do
		for _, domain in definition.domains do
			if domain.events == nil then
				continue
			end
			file ..= `local {domain.domain} = require("./{domain.domain}")\n`
		end
	end

	file ..= "return table.freeze({"

	for _, definition in definitions do
		for _, domain in definition.domains do
			if domain.events == nil then
				continue
			end

			for _, event in domain.events do
				local pascal_name = event.name:sub(1, 1):upper() .. event.name:sub(2)
				file ..= `{domain.domain}{pascal_name} = {domain.domain}.{pascal_name},`
			end
		end
	end

	file ..= "})"

	return if FORMAT then stylua(file) else file
end

local browser_definition = read_json(`{IN}/browser_protocol.json`) :: ProtocolDefinition
local js_definition = read_json(`{IN}/js_protocol.json`) :: ProtocolDefinition

if fs.isDir(OUT) then
	fs.removeDir(OUT)
end
fs.writeDir(OUT)

local log = `{stdio.color("cyan")}%s{stdio.color("reset")} {stdio.style("dim")}>{stdio.style("reset")} {OUT}/%s.luau`

for _, domain in browser_definition.domains do
	local file = write_domain_definition(domain)
	fs.writeFile(`{OUT}/{domain.domain}.luau`, file)

	print(log:format(domain.domain, domain.domain))
end

for _, domain in js_definition.domains do
	local file = write_domain_definition(domain)
	fs.writeFile(`{OUT}/{domain.domain}.luau`, file)

	print(log:format(domain.domain, domain.domain))
end

do
	local file = write_method_file(browser_definition, js_definition)
	fs.writeFile(`{OUT}/method.luau`, file)

	print(log:format("Method", "method"))
end

do
	local file = write_event_file(browser_definition, js_definition)
	fs.writeFile(`{OUT}/event.luau`, file)

	print(log:format("Event", "event"))
end
