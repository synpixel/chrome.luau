local Transport = require("../transport")
local Page = require("../protocol/Page")

export type Dialog = {
	session_id: string,
	transport: Transport.Transport,
	accept: (self: Dialog, text: string?) -> (),
	dismiss: (self: Dialog) -> (),
}

local function handle(self: Dialog, accept: boolean, text: string?)
	self.transport:call_method_on_target(
		Page.HandleJavaScriptDialog,
		{ accept = accept, prompt_text = text },
		self.session_id
	)
end

local function accept(self: Dialog, text: string?)
	handle(self, true, text)
end

local function dismiss(self: Dialog)
	handle(self, false)
end

local function new(session_id: string, transport: Transport.Transport): Dialog
	return {
		session_id = session_id,
		transport = transport,
		accept = accept,
		dismiss = dismiss,
	}
end

return { new = new }
