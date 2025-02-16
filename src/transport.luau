local task = require("@lune/task")
local net = require("@lune/net")
local serde = require("@lune/serde")
local casing = require("./utils/casing")
local Target = require("./protocol/Target")

export type Transport = {
	connection: net.WebSocket,
	waiting_calls: { [number]: thread },
	listeners: { { event: string, session_id: string?, callback: (params: any) -> () } },
	open: boolean,
	call_id_counter: number,
	-- loop_shutdown_tx
	idle_browser_timeout: number,
	unique_call_id: (self: Transport) -> number,
	call_method_on_browser: <Request, Response>(
		self: Transport,
		method: string & { __Request: Request, __Response: Response },
		parameters: Request
	) -> Response,
	call_method_on_target: <Request, Response>(
		self: Transport,
		method: string & { __Request: Request, __Response: Response },
		parameters: Request,
		session_id: string
	) -> Response,
	listen_to_browser_event: <Parameters>(
		self: Transport,
		event: string & { __Parameters: Parameters },
		callback: (params: Parameters) -> ()
	) -> () -> (),
	listen_to_target_event: <Parameters>(
		self: Transport,
		event: string & { __Parameters: Parameters },
		session_id: string,
		callback: (params: Parameters) -> ()
	) -> () -> (),
	shutdown: (self: Transport) -> (),
}

local function unique_call_id(self: Transport): number
	self.call_id_counter += 1
	return self.call_id_counter
end

local function call_method_on_browser<Request, Response>(
	self: Transport,
	method: string & { __Request: Request, __Response: Response },
	params: Request
): Response
	assert(self.open, "Connection was closed")

	local id = self:unique_call_id()
	local call = {
		id = id,
		method = method,
		params = casing.snake_to_camel(params),
	}

	local message = serde.encode("json", call)

	local thread = coroutine.running()
	self.waiting_calls[id] = thread

	self.connection.send(message)

	local response = coroutine.yield()
	if response.error ~= nil then
		error(response.error.message)
	end

	return response.result
end

local function call_method_on_target<Request, Response>(
	self: Transport,
	method: string & { __Request: Request, __Response: Response },
	params: Request,
	session_id: string
): Response
	assert(self.open, "Connection was closed")

	local id = self:unique_call_id()
	local call = {
		id = id,
		method = method,
		params = casing.snake_to_camel(params),
	}

	local message = serde.encode("json", call)

	local thread = coroutine.running()
	self.waiting_calls[id] = thread

	self:call_method_on_browser(Target.SendMessageToTarget, {
		session_id = session_id,
		message = message,
	})

	local response = coroutine.yield()
	if response.error ~= nil then
		error(response.error.message)
	end

	return response.result
end

local function listen_to_browser_event<Parameters>(
	self: Transport,
	event: string & { __Parameters: Parameters },
	callback: (params: Parameters) -> ()
): () -> ()
	local listener = { event = event, callback = callback }
	table.insert(self.listeners, listener)

	return function()
		local index = table.find(self.listeners, listener)
		table.remove(self.listeners, index)
	end
end

local function listen_to_target_event<Parameters>(
	self: Transport,
	event: string & { __Parameters: Parameters },
	session_id: string,
	callback: (params: Parameters) -> ()
): () -> ()
	local listener = { event = event, session_id = session_id, callback = callback }
	table.insert(self.listeners, listener)

	return function()
		local index = table.find(self.listeners, listener)
		table.remove(self.listeners, index)
	end
end

local function handle_incoming_messages(self: Transport)
	task.spawn(function()
		while true do
			if self.open == false then
				break
			end

			local message = self.connection.next()
			if message == nil then
				continue
			end

			local response = serde.decode("json", message)
			local session_id = if response.params ~= nil then response.params.sessionId else nil

			if response.method == Target.ReceivedMessageFromTarget then
				response = serde.decode("json", response.params.message)
			end

			response = casing.camel_to_snake(response)

			for id, call in self.waiting_calls do
				if response.id == id then
					self.waiting_calls[id] = nil
					task.spawn(call, response)
					break
				end
			end

			for index, listener in self.listeners do
				if session_id ~= listener.session_id then
					continue
				end

				if response.method == listener.event then
					task.spawn(listener.callback, response.params)
				end
			end
		end
	end)
end

local function shutdown(self: Transport)
	self.open = false
	self.connection.close(1000)
end

local function new(websocket_url: string, idle_browser_timeout: number): Transport
	local connection = net.socket(websocket_url)

	local transport = {
		connection = connection,
		waiting_calls = {},
		listeners = {},
		open = true,
		call_id_counter = 0,
		idle_browser_timeout = idle_browser_timeout,
		unique_call_id = unique_call_id,
		call_method_on_browser = call_method_on_browser,
		call_method_on_target = call_method_on_target,
		listen_to_browser_event = listen_to_browser_event,
		listen_to_target_event = listen_to_target_event,
		shutdown = shutdown,
	}

	handle_incoming_messages(transport)

	return transport
end

return { new = new }
