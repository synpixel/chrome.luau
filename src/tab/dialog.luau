local Transport = require("../transport")
local Page = require("../protocol/Page")

export type Dialog = {
	sessionId: string,
	transport: Transport.Transport,
	accept: (self: Dialog, text: string?) -> (),
	dismiss: (self: Dialog) -> (),
}

local function handle(self: Dialog, accept: boolean, text: string?)
	self.transport:callMethodOnTarget(
		Page.HandleJavaScriptDialog,
		{ accept = accept, promptText = text },
		self.sessionId
	)
end

local function accept(self: Dialog, text: string?)
	handle(self, true, text)
end

local function dismiss(self: Dialog)
	handle(self, false)
end

local function new(sessionId: string, transport: Transport.Transport): Dialog
	return {
		sessionId = sessionId,
		transport = transport,
		accept = accept,
		dismiss = dismiss,
	}
end

return { new = new }
