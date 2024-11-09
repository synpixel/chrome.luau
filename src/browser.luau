local ChromeProcess = require("./chrome-process")
local Transport = require("./transport")
local Tab = require("./tab")
local Wait = require("./utils/wait")
local Browser = require("./protocol/Browser")
local Target = require("./protocol/Target")

--[=[
	A handle to an instance of Chrome / Chromium, which wraps a WebSocket connection to its debugging port.

	Most of your actual "driving" (e.g. clicking, typing, navigating) will be via instances of [Tab](../api/Tab), which are accessible via methods such as `getTabs`.

	A Browser can either manage its own Chrome process or connect to a remote one.

	`Browser.new()` will return a headless instance of whatever browser can be found using
	`defaultExecutable`, which will search on your PATH for relevant binaries or use the path
	specified in the `CHROME` env var.

	@class Browser
]=]
export type Browser = {
	transport: Transport.Transport,
	tabs: { Tab.Tab },
	getTabs: (self: Browser) -> { Tab.Tab },
	callMethod: <Request, Response>(
		self: Browser,
		method: string & { __Request: Request, __Response: Response },
		params: Request
	) -> Response,
	addEventListener: <Parameters>(
		self: Browser,
		event: string & { __Parameters: Parameters },
		callback: (params: Parameters) -> ()
	) -> () -> (),
	getVersion: (
		self: Browser
	) -> {
		protocolVersion: string,
		product: string,
		revision: string,
		userAgent: string,
		jsVersion: string,
	},
	newTabWithOptions: (
		self: Browser,
		options: {
			url: string,
			width: number?,
			height: number?,
			browserContextId: Browser.BrowserContextID?,
			enableBeginFrameControl: boolean?,
			newWindow: boolean?,
			background: boolean?,
			forTab: boolean?,
		}
	) -> Tab.Tab,
	newTab: (self: Browser) -> Tab.Tab,
	registerMissingTabs: (self: Browser) -> (),
	close: (self: Browser) -> (),
}

local DEFAULT_IDLE_TIMEOUT = 30

--- @within Browser
local function getTabs(self: Browser): { Tab.Tab }
	return self.tabs
end

--- Call a browser method.
--- @within Browser
local function callMethod<Request, Response>(
	self: Browser,
	method: string & { __Request: Request, __Response: Response },
	params: Request
): Response
	return self.transport:callMethodOnBrowser(method, params)
end

--- Adds event listener to `event`
--- @within Browser
local function addEventListener<Parameters>(
	self: Browser,
	event: string & { __Parameters: Parameters },
	callback: (params: Parameters) -> ()
): () -> ()
	return self.transport:listenToBrowserEvent(event, callback)
end

--- Get version information
--- @within Browser
local function getVersion(self: Browser): {
	protocolVersion: string,
	product: string,
	revision: string,
	userAgent: string,
	jsVersion: string,
}
	return self:callMethod(Browser.GetVersion)
end

--- Create a new tab with a starting url, height / width, context ID and 'frame control'
--- @within Browser
local function newTabWithOptions(
	self: Browser,
	options: {
		url: string,
		width: number?,
		height: number?,
		browserContextId: Browser.BrowserContextID?,
		enableBeginFrameControl: boolean?,
		newWindow: boolean?,
		background: boolean?,
		forTab: boolean?,
	}
): Tab.Tab
	local targetId = self:callMethod(Target.CreateTarget, options).targetId

	return Wait.withTimeout(20):pauseUntil(function()
		for index, tab in self.tabs do
			if tab:getTargetId() == targetId then
				return tab :: any
			end
		end

		return Wait.None
	end)
end

--- Create a new tab and return a handle to it.
--- If you want to specify its starting options, see `newTabWithOptions`.
--- @within Browser
local function newTab(self: Browser): Tab.Tab
	return self:newTabWithOptions({ url = "about:blank" })
end

--- Adds tabs that have not been opened with `newTab` to the list of tabs
--- @within Browser
local function registerMissingTabs(self: Browser)
	local targets = self:callMethod(Target.GetTargets, nil :: any)

	local previousTargetId = ""

	for _, target in targets.targetInfos do
		local targetId = target.targetId

		for _, tab in self.tabs do
			if tab:getTargetId() == targetId or target.attached == false then
				previousTargetId = targetId
				break
			end
		end

		if previousTargetId == targetId then
			continue
		end

		local tab = Tab.new(target, self.transport)
		local tabIndex: number?

		for index, tab in self.tabs do
			if tab:getTargetId() == previousTargetId then
				tabIndex = index
				break
			end
		end

		if tabIndex ~= nil then
			table.insert(self.tabs, tabIndex, tab)
		else
			table.insert(self.tabs, tab)
		end

		previousTargetId = targetId
	end
end

local function handleBrowserLevelEvents(self: Browser)
	self:addEventListener(Target.TargetCreated, function(target)
		local targetInfo = target.targetInfo
		if targetInfo.type ~= "page" then
			return
		end

		local tab = Tab.new(targetInfo, self.transport)
		table.insert(self.tabs, tab)
	end)

	self:addEventListener(Target.TargetInfoChanged, function(target)
		local targetInfo = target.targetInfo
		if targetInfo.type ~= "page" or targetInfo.url:sub(1, 11) == "devtools://" then
			return
		end

		for _, tab in self.tabs do
			if targetInfo.targetId == tab:getTargetId() then
				tab:updateTargetInfo(targetInfo)
				break
			end
		end
	end)

	self:addEventListener(Target.TargetDestroyed, function(target)
		for index, tab in self.tabs do
			if target.targetId == tab:getTargetId() then
				table.remove(self.tabs, index)
				break
			end
		end
	end)
end

--- Closes the browser.
--- @within Browser
local function close(self: Browser)
	self.transport:callMethodOnBrowser(Browser.Close)
	self.transport:shutdown()
end

--- Allows you to drive an externally-launched Chrome process instead of launch one via Browser.new.
--- If the browser is idle for `idleBrowserTimeout`, the connection will be dropped.
--- @within Browser
local function connectWithTimeout(websocketUrl: string, idleBrowserTimeout: number): Browser
	local transport = Transport.new(websocketUrl, idleBrowserTimeout)

	local browser = {
		transport = transport,
		tabs = {},
		getTabs = getTabs,
		callMethod = callMethod,
		addEventListener = addEventListener,
		getVersion = getVersion,
		newTabWithOptions = newTabWithOptions,
		newTab = newTab,
		registerMissingTabs = registerMissingTabs,
		close = close,
	}

	handleBrowserLevelEvents(browser)
	browser:callMethod(Target.SetDiscoverTargets, { discover = true })

	return browser
end

--- Allows you to drive an externally-launched Chrome process instead of launch one via Browser.new.
--- If the browser is idle for 30 seconds, the connection will be dropped.
--- @within Browser
local function connect(websocketUrl: string): Browser
	return connectWithTimeout(websocketUrl, DEFAULT_IDLE_TIMEOUT)
end

--- Launch a new Chrome browser.
--- The browser will have its user data (aka "profile") directory stored in a temporary directory.
--- @within Browser
local function new(launchOptions: ChromeProcess.LaunchOptions?): Browser
	local chromeProcess = ChromeProcess.new(launchOptions)
	local idleBrowserTimeout = if launchOptions == nil or launchOptions.idleBrowserTimeout == nil
		then DEFAULT_IDLE_TIMEOUT
		else launchOptions.idleBrowserTimeout

	return connectWithTimeout(chromeProcess.websocketUrl, idleBrowserTimeout)
end

return {
	connectWithTimeout = connectWithTimeout,
	connect = connect,
	new = new,
}
