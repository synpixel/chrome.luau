local task = require("@lune/task")
local net = require("@lune/net")
local serde = require("@lune/serde")
local Target = require("./protocol/Target")

export type Transport = {
	connection: net.WebSocket,
	waitingCalls: { [number]: thread },
	listeners: { { event: string, sessionId: string?, callback: (params: any) -> () } },
	open: boolean,
	callIdCounter: number,
	-- loop_shutdown_tx
	idleBrowserTimeout: number,
	uniqueCallId: (self: Transport) -> number,
	callMethodOnBrowser: <Request, Response>(
		self: Transport,
		method: string & { __Request: Request, __Response: Response },
		parameters: Request
	) -> Response,
	callMethodOnTarget: <Request, Response>(
		self: Transport,
		method: string & { __Request: Request, __Response: Response },
		parameters: Request,
		sessionId: string
	) -> Response,
	listenToBrowserEvent: <Parameters>(
		self: Transport,
		event: string & { __Parameters: Parameters },
		callback: (params: Parameters) -> ()
	) -> () -> (),
	listenToTargetEvent: <Parameters>(
		self: Transport,
		event: string & { __Parameters: Parameters },
		sessionId: string,
		callback: (params: Parameters) -> ()
	) -> () -> (),
	shutdown: (self: Transport) -> (),
}

local function uniqueCallId(self: Transport): number
	self.callIdCounter += 1
	return self.callIdCounter
end

local function callMethodOnBrowser<Request, Response>(
	self: Transport,
	method: string & { __Request: Request, __Response: Response },
	params: Request
): Response
	assert(self.open, "Connection was closed")

	local id = self:uniqueCallId()
	local call = {
		id = id,
		method = method,
		params = params,
	}

	local message = serde.encode("json", call)

	local thread = coroutine.running()
	self.waitingCalls[id] = thread

	self.connection.send(message)

	local response = coroutine.yield()
	if response.error ~= nil then
		error(response.error.message)
	end

	return response.result
end

local function callMethodOnTarget<Request, Response>(
	self: Transport,
	method: string & { __Request: Request, __Response: Response },
	params: Request,
	sessionId: string
): Response
	assert(self.open, "Connection was closed")

	local id = self:uniqueCallId()
	local call = {
		id = id,
		method = method,
		params = params,
	}

	local message = serde.encode("json", call)

	local thread = coroutine.running()
	self.waitingCalls[id] = thread

	self:callMethodOnBrowser(Target.SendMessageToTarget, {
		sessionId = sessionId,
		message = message,
	})

	local response = coroutine.yield()
	if response.error ~= nil then
		error(response.error.message)
	end

	return response.result
end

local function listenToBrowserEvent<Parameters>(
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

local function listenToTargetEvent<Parameters>(
	self: Transport,
	event: string & { __Parameters: Parameters },
	sessionId: string,
	callback: (params: Parameters) -> ()
): () -> ()
	local listener = { event = event, sessionId = sessionId, callback = callback }
	table.insert(self.listeners, listener)

	return function()
		local index = table.find(self.listeners, listener)
		table.remove(self.listeners, index)
	end
end

local function handleIncomingMessages(self: Transport)
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
			local sessionId = if response.params ~= nil then response.params.sessionId else nil

			if response.method == Target.ReceivedMessageFromTarget then
				response = serde.decode("json", response.params.message)
			end

			for id, call in self.waitingCalls do
				if response.id == id then
					self.waitingCalls[id] = nil
					task.spawn(call, response)
					break
				end
			end

			for index, listener in self.listeners do
				if sessionId ~= listener.sessionId then
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

local function new(websocketUrl: string, idleBrowserTimeout: number): Transport
	local connection = net.socket(websocketUrl)

	local transport = {
		connection = connection,
		waitingCalls = {},
		listeners = {},
		open = true,
		callIdCounter = 0,
		idleBrowserTimeout = idleBrowserTimeout,
		uniqueCallId = uniqueCallId,
		callMethodOnBrowser = callMethodOnBrowser,
		callMethodOnTarget = callMethodOnTarget,
		listenToBrowserEvent = listenToBrowserEvent,
		listenToTargetEvent = listenToTargetEvent,
		shutdown = shutdown,
	}

	handleIncomingMessages(transport)

	return transport
end

return { new = new }
