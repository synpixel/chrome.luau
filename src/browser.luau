local fs = require("@lune/fs")
local task = require("@lune/task")
local ChromeProcess = require("./chrome-process")
local Transport = require("./transport")
local Tab = require("./tab")
local Context = require("./context")
local Wait = require("./utils/wait")
local types = require("./types")
local Browser = require("./protocol/browser")
local Target = require("./protocol/target")

export type Browser = types.Browser

local DEFAULT_IDLE_TIMEOUT = 30

local function get_tabs(self: Browser): { Tab.Tab }
	return self.tabs
end

local function call_method<Request, Response>(
	self: Browser,
	method: string & { __Request: Request, __Response: Response },
	params: Request
): Response
	return self.transport:call_method_on_browser(method, params)
end

local function add_event_listener<Parameters>(
	self: Browser,
	event: string & { __Parameters: Parameters },
	callback: (params: Parameters) -> ()
): () -> ()
	return self.transport:listen_to_browser_event(event, callback)
end

local function get_version(self: Browser): {
	protocol_version: string,
	product: string,
	revision: string,
	user_agent: string,
	js_version: string,
}
	return self:call_method(Browser.GetVersion)
end

local function new_tab_with_options(
	self: Browser,
	options: {
		url: string,
		width: number?,
		height: number?,
		browser_context_id: Browser.BrowserContextID?,
		enable_begin_frame_control: boolean?,
		new_window: boolean?,
		background: boolean?,
		for_tab: boolean?,
	}
): Tab.Tab
	local target_id = self:call_method(Target.CreateTarget, options).target_id
	local tab = Wait.with_timeout(20):pause_until(function()
		for index, tab in self.tabs do
			if tab:get_target_id() == target_id then
				return tab :: any
			end
		end

		return nil
	end)

	assert(tab, "Failed to fetch new tab")
	return tab
end

local function new_tab(self: Browser): Tab.Tab
	return self:new_tab_with_options({ url = "about:blank" })
end

local function new_context(self: Browser): Context.Context
	local context_id = self:call_method(Target.CreateBrowserContext, {}).browser_context_id
	return Context.new(self, context_id)
end

local function register_missing_tabs(self: Browser)
	local targets = self:call_method(Target.GetTargets, nil :: any)

	local previous_target_id = ""

	for _, target in targets.target_infos do
		local target_id = target.target_id

		for _, tab in self.tabs do
			if tab:get_target_id() == target_id or target.attached == false then
				previous_target_id = target_id
				break
			end
		end

		if previous_target_id == target_id then
			continue
		end

		local tab = Tab.new(target, self.transport)
		local tab_index: number?

		for index, tab in self.tabs do
			if tab:get_target_id() == previous_target_id then
				tab_index = index
				break
			end
		end

		if tab_index ~= nil then
			table.insert(self.tabs, tab_index, tab)
		else
			table.insert(self.tabs, tab)
		end

		previous_target_id = target_id
	end
end

local function handle_browser_level_events(self: Browser)
	self:add_event_listener(Target.TargetCreated, function(target)
		local target_info = target.target_info
		if target_info.type ~= "page" then
			return
		end

		local tab = Tab.new(target_info, self.transport)
		table.insert(self.tabs, tab)
	end)

	self:add_event_listener(Target.TargetInfoChanged, function(target)
		local target_info = target.target_info
		if target_info.type ~= "page" or target_info.url:sub(1, 11) == "devtools://" then
			return
		end

		for _, tab in self.tabs do
			if target_info.target_id == tab:get_target_id() then
				tab:update_target_info(target_info)
				break
			end
		end
	end)

	self:add_event_listener(Target.TargetDestroyed, function(target)
		for index, tab in self.tabs do
			if target.target_id == tab:get_target_id() then
				table.remove(self.tabs, index)
				break
			end
		end
	end)
end

local function close(self: Browser)
	self.transport:call_method_on_browser(Browser.Close)
	self.transport:shutdown()

	for _, on_close in self.on_close_hooks do
		on_close()
	end
end

--- Allows you to drive an externally-launched Chrome process instead of launch one via Browser.new.
--- If the browser is idle for `idleBrowserTimeout`, the connection will be dropped.
--- @within Browser
local function connect_with_timeout(websocket_url: string, idle_browser_timeout: number): Browser
	local transport = Transport.new(websocket_url, idle_browser_timeout)

	local browser = {
		transport = transport,
		tabs = {},
		on_close_hooks = {},
		get_tabs = get_tabs,
		call_method = call_method,
		add_event_listener = add_event_listener,
		get_version = get_version,
		new_tab_with_options = new_tab_with_options,
		new_tab = new_tab,
		new_context = new_context,
		register_missing_tabs = register_missing_tabs,
		close = close,
	}

	handle_browser_level_events(browser)
	browser:call_method(Target.SetDiscoverTargets, { discover = true })

	return browser
end

--- Allows you to drive an externally-launched Chrome process instead of launch one via Browser.new.
--- If the browser is idle for 30 seconds, the connection will be dropped.
--- @within Browser
local function connect(websocket_url: string): Browser
	return connect_with_timeout(websocket_url, DEFAULT_IDLE_TIMEOUT)
end

--- Launch a new Chrome browser.
--- The browser will have its user data (aka "profile") directory stored in a temporary directory.
--- @within Browser
local function new(launch_options: ChromeProcess.LaunchOptions?): Browser
	local chrome_process = ChromeProcess.new(launch_options)
	local idle_browser_timeout = if launch_options == nil or launch_options.idle_browser_timeout == nil
		then DEFAULT_IDLE_TIMEOUT
		else launch_options.idle_browser_timeout

	local browser = connect_with_timeout(chrome_process.websocket_url, idle_browser_timeout)

	local temp_user_data_dir = chrome_process.temp_user_data_dir
	if temp_user_data_dir then
		local thread = task.spawn(function()
			chrome_process.child.stderr:readToEnd()
			if fs.isDir(temp_user_data_dir) then
				fs.removeDir(temp_user_data_dir)
			end
		end)

		local ensure_cleanup = function()
			Wait.forever():pause_until(function()
				return if coroutine.status(thread) == "dead" then true else nil
			end)
		end
		table.insert(browser.on_close_hooks, ensure_cleanup)
	end

	return browser
end

return {
	connect_with_timeout = connect_with_timeout,
	connect = connect,
	new = new,
}
