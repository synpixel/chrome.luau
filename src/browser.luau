local ChromeProcess = require("./chrome-process")
local Transport = require("./transport")
local Tab = require("./tab")
local Context = require("./context")
local Wait = require("./utils/wait")
local types = require("./types")
local Browser = require("./protocol/Browser")
local Target = require("./protocol/Target")

export type Browser = types.Browser

local DEFAULT_IDLE_TIMEOUT = 30

local function getTabs(self: Browser): { Tab.Tab }
	return self.tabs
end

local function callMethod<Request, Response>(
	self: Browser,
	method: string & { __Request: Request, __Response: Response },
	params: Request
): Response
	return self.transport:callMethodOnBrowser(method, params)
end

local function addEventListener<Parameters>(
	self: Browser,
	event: string & { __Parameters: Parameters },
	callback: (params: Parameters) -> ()
): () -> ()
	return self.transport:listenToBrowserEvent(event, callback)
end

local function getVersion(self: Browser): {
	protocolVersion: string,
	product: string,
	revision: string,
	userAgent: string,
	jsVersion: string,
}
	return self:callMethod(Browser.GetVersion)
end

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

local function newTab(self: Browser): Tab.Tab
	return self:newTabWithOptions({ url = "about:blank" })
end

local function newContext(self: Browser): Context.Context
	local contextId = self:callMethod(Target.CreateBrowserContext, {}).browserContextId
	return Context.new(self, contextId)
end

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
		newContext = newContext,
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
