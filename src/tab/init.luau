local serde = require("@lune/serde")
local Regex = require("@lune/regex")
local Transport = require("../transport")
local Element = require("./element")
local ElementQuad = require("./element-quad")
local BoxModel = require("./box-model")
local Dialog = require("./dialog")
local keys = require("./keys")
local Wait = require("../utils/wait")
local base64 = require("../utils/base64")
local types = require("../types")
local Target = require("../protocol/Target")
local Page = require("../protocol/Page")
local Browser = require("../protocol/Browser")
local Runtime = require("../protocol/Runtime")
local Network = require("../protocol/Network")
local DOM = require("../protocol/DOM")
local Input = require("../protocol/Input")
local Log = require("../protocol/Log")
local Debugger = require("../protocol/Debugger")
local Profiler = require("../protocol/Profiler")

--- A handle to a single page. Exposes methods for simulating user actions (clicking,
--- typing), and also for getting information about the DOM and other parts of the page.
--- @class Tab
export type Tab = types.Tab

export type Element = Element.Element
export type ElementQuad = ElementQuad.ElementQuad
export type BoxModel = BoxModel.BoxModel

--- @within Tab
local function getTargetId(self: Tab): string
	return self.targetId
end

--- @within Tab
local function updateTargetInfo(self: Tab, targetInfo: Target.TargetInfo)
	self.targetInfo = targetInfo
end

--- @within Tab
local function getUrl(self: Tab): string
	return self.targetInfo.url
end

--- Set default timeout for the tab
--- This will be applied to all `waitForElement` and `waitForElements` calls without a timeout for this tab
--- @within Tab
local function setDefaultTimeout(self: Tab, timeout: number): Tab
	self.defaultTimeout = timeout
	return self
end

--- Call a target method.
--- @within Tab
local function callMethod<Request, Response>(
	self: Tab,
	method: string & { __Request: Request, __Response: Response },
	parameters: Request
): Response
	return self.transport:callMethodOnTarget(method, parameters, self.sessionId)
end

--- Adds event listener to `event`
--- @within Tab
local function addEventListener<Parameters>(
	self: Tab,
	event: string & { __Parameters: Parameters },
	callback: (params: Parameters) -> ()
): () -> ()
	return self.transport:listenToTargetEvent(event, self.sessionId, callback)
end

--- Fetches the most recent info about this target
--- @within Tab
local function getTargetInfo(self: Tab): Target.TargetInfo
	return self.transport:callMethodOnBrowser(Target.GetTargetInfo, { targetId = self.targetId }).targetInfo
end

--- @within Tab
local function getBrowserContextId(self: Tab): string?
	local targetInfo = self:getTargetInfo()
	return targetInfo.browserContextId
end

--- Allows overriding user agent with the given string.
--- @within Tab
local function setUserAgent(self: Tab, userAgent: string, acceptLanguage: string?, platform: string?)
	self:callMethod(
		Network.SetUserAgentOverride,
		{ userAgent = userAgent, acceptLanguage = acceptLanguage, platform = platform }
	)
end

--- @within Tab
local function setExtraHttpHeaders(self: Tab, headers: { [string]: string })
	self:callMethod(Network.Enable, {})
	self:callMethod(Network.SetExtraHTTPHeaders, { headers = headers })
end

--- If enabled, instead of using the GUI to select files, the browser will
--- wait for the `handleFileChooser` method to be called.
--- \**WARNING**: Only works on Chromium / Chrome 77 and above.
--- @within Tab
local function setFileChooserDialogInterception(self: Tab, enabled: boolean)
	self:callMethod(Page.SetInterceptFileChooserDialog, { enabled = enabled })
end

--[=[
	Will have the same effect as choosing these files from the file chooser dialog that would've
	popped up had `set_file_chooser_dialog_interception` not been called. Calls to this method
	must be preceded by calls to that method.

	Supports selecting files or closing the file chooser dialog.

	NOTE: the filepaths listed in `files` must be absolute.

	@within Tab
]=]
local function handleFileChooser(self: Tab, files: { string }, nodeId: number)
	self:callMethod(DOM.SetFileInputFiles, { files = files, nodeId = nodeId })
end

--- Pulls focus to this tab
--- @within Tab
local function bringToFront(self: Tab)
	self:callMethod(Page.BringToFront)
end

--[=[
	Reloads given page optionally ignoring the cache

	If `ignoreCache` is true, the browser cache is ignored (as if the user pressed Shift+F5).  
	If `scriptToEvaluate` is given, the script will be injected into all frames of the
	inspected page after reload. Argument will be ignored if reloading dataURL origin.

	@within Tab
]=]
local function reload(self: Tab, ignoreCache: boolean?, scriptToEvaluateOnLoad: string?): Tab
	self:callMethod(Page.Reload, { ignoreCache = ignoreCache, scriptToEvaluateOnLoad = scriptToEvaluateOnLoad })
	return self
end

--- @within Tab
local function stopLoading(self: Tab)
	self:callMethod(Page.StopLoading)
end

--- @within Tab
local function navigateTo(self: Tab, url: string): Tab
	self:callMethod(Page.Navigate, { url = url })
	self.navigating = true

	return self
end

--- @within Tab
local function waitUntilNavigated(self: Tab): Tab
	Wait.withTimeout(self.defaultTimeout):pauseUntil(function()
		return if self.navigating then Wait.None else nil
	end)

	return self
end

--- @within Tab
local function waitUntilRedirect(self: Tab): Tab
	self.navigating = true
	return self:waitUntilNavigated()
end

--[=[
	Get position and size of the browser window associated with this `Tab`.

	Note that the returned bounds are always specified for normal (windowed)
	state; they do not change when minimizing, maximizing or setting to
	fullscreen.

	@within Tab
]=]
local function getBounds(self: Tab): Browser.Bounds
	return self.transport:callMethodOnBrowser(Browser.GetWindowForTarget, { targetId = self.targetId }).bounds
end

--[=[
	Set position and/or size of the browser window associated with this `Tab`.

	When setting the window to normal (windowed) state, unspecified fields
	are left unchanged.

	@within Tab
]=]
local function setBounds(self: Tab, bounds: Browser.Bounds): Tab
	local windowId =
		self.transport:callMethodOnBrowser(Browser.GetWindowForTarget, { targetId = self.targetId }).windowId

	self.transport:callMethodOnBrowser(Browser.SetWindowBounds, { windowId = windowId, bounds = bounds })

	return self
end

--- Evaluates expression on global object.
--- @within Tab
local function evaluate(self: Tab, expression: string, awaitPromise: boolean?): Runtime.RemoteObject
	return self:callMethod(Runtime.Evaluate, {
		expression = expression,
		returnByValue = false,
		generatePreview = true,
		silent = false,
		awaitPromise = awaitPromise,
		includeCommandLineAPI = false,
		userGesture = false,
	}).result
end

--- Returns the title of the document.
--- @within Tab
local function getTitle(self: Tab): string
	local result = self:evaluate("document.title")
	return result.value :: string
end

--- Set cookies with tab's current URL
--- @within Tab
local function setCookies(self: Tab, cookies: { Network.CookieParam })
	local url = self:getUrl()
	local startsWithHttp = url:sub(1, 4) == "http"

	local patchedCookies = {}

	for index, cookie in cookies do
		if cookie.url == nil and startsWithHttp then
			cookie = table.clone(cookie)
			cookie.url = url
		end

		patchedCookies[index] = cookie
	end

	self:deleteCookies(patchedCookies :: any)
	self:callMethod(Network.SetCookies, { cookies = patchedCookies })
end

--- Returns all cookies that match the tab's current URL.
--- @within Tab
local function getCookies(self: Tab): { Network.Cookie }
	return self:callMethod(Network.GetCookies, {}).cookies
end

--- Delete cookies with tab's current URL
--- @within Tab
local function deleteCookies(
	self: Tab,
	cookies: {
		{
			name: string,
			url: string?,
			domain: string?,
			path: string?,
			partitionKey: Network.CookiePartitionKey?,
		}
	}
)
	local url = self:getUrl()
	local startsWithHttp = url:sub(1, 4) == "http"

	for _, cookie in cookies do
		if cookie.url == nil and startsWithHttp then
			cookie = table.clone(cookie)
			cookie.url = url
		end

		self:callMethod(Network.DeleteCookies, cookie)
	end
end

--- @within Tab
local function setStorage(self: Tab, name: string, item: any)
	local json = serde.encode("json", item)
	local value = if typeof(item) == "string" then json else `JSON.stringify({json})`
	self:evaluate(`localStorage.setItem("{name}", {value})`)
end

--- @within Tab
local function getStorage(self: Tab, name: string): any?
	local result = self:evaluate(`localStorage.getItem("{name}")`)
	if result.type ~= "string" then
		return nil
	end

	local success, item = pcall(serde.decode, "json" :: any, result.value :: string)
	if success then
		return item
	end

	return result.value
end

--- @within Tab
local function removeStorage(self: Tab, name: string)
	self:evaluate(`localStorage.removeItem("{name}")`)
end

--[=[
	Capture a screenshot of the current page.

	If `clip` is given, the screenshot is taken of the specified region only.
	`Element.getBoxModel` can be used to get regions of certains elements on the page; there is
	also `Element.captureScreenshot` as a shorthand.

	If `fromSurface` is true, the screenshot is taken from the surface rather than the view.

	@within Tab
]=]
local function captureScreenshot(
	self: Tab,
	options: {
		format: "jpeg" | "png" | "webp"?,
		quality: number?,
		clip: Page.Viewport?,
		fromSurface: boolean?,
		captureBeyondViewport: boolean?,
		optimizeForSpeed: boolean?,
	}
): buffer
	local screenshot = self:callMethod(Page.CaptureScreenshot, options)
	local data = buffer.fromstring(screenshot.data)
	return base64.decode(data)
end

--- @within Tab
local function printToPdf(
	self: Tab,
	options: {
		landscape: boolean?,
		displayHeaderFooter: boolean?,
		printBackground: boolean?,
		scale: number?,
		paperWidth: number?,
		paperHeight: number?,
		marginTop: number?,
		marginBottom: number?,
		marginLeft: number?,
		marginRight: number?,
		pageRanges: string?,
		headerTemplate: string?,
		footerTemplate: string?,
		preferCSSPageSize: boolean?,
		generateTaggedPDF: boolean?,
		generateDocumentOutline: boolean?,
	}?
): buffer
	local pdf = self:callMethod(Page.PrintToPDF, options :: any or {})
	local data = buffer.fromstring(pdf.data)
	return base64.decode(data)
end

--- @within Tab
local function startScreencast(
	self: Tab,
	options: {
		format: "jpeg" | "png"?,
		quality: number?,
		maxWidth: number?,
		maxHeight: number?,
		everyNthFrame: number?,
	}
)
	self:callMethod(Page.StartScreencast, options)
end

--- @within Tab
local function stopScreencast(self: Tab)
	self:callMethod(Page.StopScreencast)
end

--- @within Tab
local function ackScreencast(self: Tab, sessionId: number)
	self:callMethod(Page.ScreencastFrameAck, { sessionId = sessionId })
end

--- Get the handle of the dialog opened in this tab.
--- @within Tab
local function getDialog(self: Tab): Dialog.Dialog
	return Dialog.new(self.sessionId, self.transport)
end

--- @within Tab
local function getDocument(self: Tab): DOM.Node
	return self:callMethod(DOM.GetDocument, { depth = 0, pierce = false }).root
end

--- Get the full HTML contents of the page.
--- @within Tab
local function getContent(self: Tab): string
	local expression = [[
		let content = "";
        if (document.doctype)
            content += new XMLSerializer().serializeToString(document.doctype);
        if (document.documentElement)
            content += document.documentElement.outerHTML;
        return content;
	]]

	local html = self:evaluate(expression).value
	return html :: string
end

--- @within Tab
local function runQuerySelectorOnNode(self: Tab, nodeId: DOM.NodeId, selector: string): Element?
	local nodeId = self:callMethod(DOM.QuerySelector, { nodeId = nodeId, selector = selector }).nodeId
	return Element.new(self, nodeId)
end

--- @within Tab
local function runQuerySelectorAllOnNode(self: Tab, nodeId: DOM.NodeId, selector: string): { Element }
	local nodeIds = self:callMethod(DOM.QuerySelectorAll, { nodeId = nodeId, selector = selector }).nodeIds

	local elements = {}

	for _, nodeId in nodeIds do
		local element = Element.new(self, nodeId)
		if element == nil then
			continue
		end

		table.insert(elements, element)
	end

	return elements
end

--- Returns the first element in the document which matches the given selector.
--- Equivalent to the following JS:
--- ```js
--- document.querySelector(selector)
--- ```
--- @within Tab
local function findElement(self: Tab, selector: string): Element?
	local rootNodeId = self:getDocument().nodeId
	return self:runQuerySelectorOnNode(rootNodeId, selector)
end

--- @within Tab
local function findElementByXPath(self: Tab, query: string): Element?
	self:getDocument()

	local search = self:callMethod(DOM.PerformSearch, { query = query })
	if search.resultCount <= 0 then
		return nil
	end

	local results = self:callMethod(DOM.GetSearchResults, {
		searchId = search.searchId,
		fromIndex = 0,
		toIndex = search.resultCount,
	})

	local nodeId = results.nodeIds[1]
	return Element.new(self, nodeId)
end

--- @within Tab
local function findElements(self: Tab, selector: string): { Element }
	local rootNodeId = self:getDocument().nodeId
	return self:runQuerySelectorAllOnNode(rootNodeId, selector)
end

--- @within Tab
local function findElementsByXPath(self: Tab, query: string): { Element }
	self:getDocument()

	local search = self:callMethod(DOM.PerformSearch, { query = query })
	if search.resultCount <= 0 then
		return {}
	end

	local results = self:callMethod(DOM.GetSearchResults, {
		searchId = search.searchId,
		fromIndex = 0,
		toIndex = search.resultCount,
	})

	local nodeIds = results.nodeIds
	local elements = {}

	for _, nodeId in nodeIds do
		local element = Element.new(self, nodeId)
		if element == nil then
			continue
		end

		table.insert(elements, element)
	end

	return elements
end

--- @within Tab
local function waitForElement(self: Tab, selector: string, timeout: number?): Element
	local timeout = timeout or self.defaultTimeout

	return Wait.withTimeout(timeout):pauseUntil(function()
		local element = self:findElement(selector)
		if element == nil then
			return Wait.None
		end

		return element
	end)
end

--- @within Tab
local function waitForXPath(self: Tab, selector: string, timeout: number?): Element
	local timeout = timeout or self.defaultTimeout

	return Wait.withTimeout(timeout):pauseUntil(function()
		local element = self:findElementByXPath(selector)
		if element == nil then
			return Wait.None
		end

		return element
	end)
end

--- @within Tab
local function waitForElements(self: Tab, selector: string, timeout: number?): { Element }
	local timeout = timeout or self.defaultTimeout

	return Wait.withTimeout(timeout):pauseUntil(function()
		local elements = self:findElements(selector)
		if #elements <= 0 then
			return Wait.None
		end

		return elements
	end)
end

--- @within Tab
local function waitForElementsByXPath(self: Tab, selector: string, timeout: number?): { Element }
	local timeout = timeout or self.defaultTimeout

	return Wait.withTimeout(timeout):pauseUntil(function()
		local elements = self:findElementsByXPath(selector)
		if #elements <= 0 then
			return Wait.None
		end

		return elements
	end)
end

--- Moves the mouse to this point (dispatches a mouseMoved event)
--- @within Tab
local function moveMouseToPoint(self: Tab, point: types.Point): Tab
	self:callMethod(Input.DispatchMouseEvent, {
		type = "mouseMoved",
		x = point.x,
		y = point.y,
	})

	return self
end

--- @within Tab
local function clickPoint(self: Tab, point: types.Point): Tab
	self:moveMouseToPoint(point)

	self:callMethod(Input.DispatchMouseEvent, {
		type = "mousePressed",
		x = point.x,
		y = point.y,
		button = "left",
		clickCount = 1,
	})

	self:callMethod(Input.DispatchMouseEvent, {
		type = "mouseReleased",
		x = point.x,
		y = point.y,
		button = "left",
		clickCount = 1,
	})

	return self
end

--- Does the same as `typeText` but it only dispatches a `keypress` and `input` event.
--- It does not send a `keydown` or `keyup` event. What this means is that it is much faster.
--- It is especially useful when you have a lot of text as input.
--- @within Tab
local function insertText(self: Tab, text: string): Tab
	self:callMethod(Input.InsertText, { text = text })
	return self
end

--- @within Tab
local function typeText(self: Tab, text: string): Tab
	for _, char in text:split("") do
		local definition = keys.getKeyDefinition(char :: keys.Key)
		if definition ~= nil then
			self:pressKey(definition.key)
		else
			self:insertText(char)
		end
	end

	return self
end

--- Press a key on the keyboard, optionally with some modifier keys.
--- See [this file](https://github.com/puppeteer/puppeteer/blob/62da2366c65b335751896afbb0206f23c61436f1/lib/USKeyboardLayout.js)
--- for a full definition of which strings correspond with which keys.
--- @within Tab
local function pressKeyWithModifiers(self: Tab, key: keys.Key, modifiers: { "Alt" | "Ctrl" | "Meta" | "Shift" }?): Tab
	local definition = keys.getKeyDefinition(key)
	assert(definition ~= nil, "Invalid key")

	local text = if definition.text ~= nil then definition.text elseif #definition.key == 1 then definition.key else nil
	local keyDownEvent: "char" | "keyDown" | "keyUp" | "rawKeyDown" = if text ~= nil then "keyDown" else "rawKeyDown"

	local mods = 0
	if modifiers ~= nil then
		for _, modifier in modifiers do
			local index = if modifier == "Alt"
				then 1
				elseif modifier == "Ctrl" then 2
				elseif modifier == "Meta" then 4
				elseif modifier == "Shift" then 8
				else 0

			mods = bit32.bor(mods, index)
		end
	end

	self:callMethod(Input.DispatchKeyEvent, {
		type = keyDownEvent,
		key = definition.key,
		text = text,
		code = definition.code,
		windowsVirtualKeyCode = definition.keyCode,
		nativeVirtualKeyCode = definition.keyCode,
		modifiers = mods,
	})

	self:callMethod(Input.DispatchKeyEvent, {
		type = "keyUp",
		key = definition.key,
		text = text,
		code = definition.code,
		windowsVirtualKeyCode = definition.keyCode,
		nativeVirtualKeyCode = definition.keyCode,
		modifiers = mods,
	})

	return self
end

--- Press a key on the keyboard. See [this file](https://github.com/puppeteer/puppeteer/blob/62da2366c65b335751896afbb0206f23c61436f1/lib/USKeyboardLayout.js)
--- for a full definition of which strings correspond with which keys.
--- @within Tab
local function pressKey(self: Tab, key: keys.Key): Tab
	return self:pressKeyWithModifiers(key)
end

--- Enables log domain.
--- Sends the entries collected so far to the client by means of the entryAdded notification.
--- See <https://chromedevtools.github.io/devtools-protocol/tot/Log#method-enable>.
--- @within Tab
local function enableLog(self: Tab): Tab
	self:callMethod(Log.Enable)
	return self
end

--- Disables log domain.
--- Prevents further log entries from being reported to the client.
--- See <https://chromedevtools.github.io/devtools-protocol/tot/Log#method-disable>.
--- @within Tab
local function disableLog(self: Tab): Tab
	self:callMethod(Log.Disable)
	return self
end

--- Starts violation reporting.
--- See <https://chromedevtools.github.io/devtools-protocol/tot/Log#method-startViolationsReport>.
--- @within Tab
local function startViolationsReport(self: Tab, config: { Log.ViolationSetting }): Tab
	self:callMethod(Log.StartViolationsReport, { config = config })
	return self
end

--- Stops violation reporting.
--- See <https://chromedevtools.github.io/devtools-protocol/tot/Log#method-stopViolationsReport>.
--- @within Tab
local function stopViolationsReport(self: Tab): Tab
	self:callMethod(Log.StopViolationsReport)
	return self
end

--- Enables runtime domain.
--- @within Tab
local function enableRuntime(self: Tab): Tab
	self:callMethod(Runtime.Enable)
	return self
end

--- Disables runtime domain.
--- @within Tab
local function disableRuntime(self: Tab): Tab
	self:callMethod(Runtime.Disable)
	return self
end

--- Enables debugger domain.
--- @within Tab
local function enableDebugger(self: Tab): Tab
	self:callMethod(Debugger.Enable, {})
	return self
end

--- Disables debugger domain.
--- @within Tab
local function disableDebugger(self: Tab): Tab
	self:callMethod(Debugger.Disable)
	return self
end

--- Returns source for the script with given id.
--- Debugger domain must be enabled.
--- @within Tab
local function getScriptSource(self: Tab, scriptId: string): string
	return self:callMethod(Debugger.GetScriptSource, { scriptId = scriptId }).scriptSource
end

--- Enables the profiler domain.
--- @within Tab
local function enableProfiler(self: Tab): Tab
	self:callMethod(Profiler.Enable)
	return self
end

--- Disables the profiler domain.
--- @within Tab
local function disableProfiler(self: Tab): Tab
	self:callMethod(Profiler.Disable)
	return self
end

--[=[
	Starts tracking which lines of JS have been executed

	Will error unless `enableProfiler` has been called.

	Equivalent to hitting the record button in the "coverage" tab in Chrome DevTools.

	By default we enable the 'detailed' flag on StartPreciseCoverage, which enables block-level
	granularity, and also enable 'callCount' (which when disabled always sets count to 1 or 0).

	@within Tab
]=]
local function startJsCoverage(self: Tab): Tab
	self:callMethod(Profiler.StartPreciseCoverage, { callCount = true, detailed = true })
	return self
end

--- Stops tracking which lines of JS have been executed.
--- If you're finished with the profiler, don't forget to call `disableProfiler`.
--- @within Tab
local function stopJsCoverage(self: Tab): Tab
	self:callMethod(Profiler.StopPreciseCoverage)
	return self
end

--[=[
	Collect coverage data for the current isolate, and resets execution counters.

	Precise code coverage needs to have started (see `startJsCoverage`).

	Will only send information about code that's been executed since this method was last
	called, or (if this is the first time) since calling `startJsCoverage`.
	Another way of thinking about it is: every time you call this, the call counts for
	FunctionRanges are reset after returning.

	The format of the data is a little unintuitive, see here for details:
	<https://chromedevtools.github.io/devtools-protocol/tot/Profiler#type-ScriptCoverage>

	@within Tab
]=]
local function takeJsCoverage(self: Tab): { Profiler.ScriptCoverage }
	return self:callMethod(Profiler.TakePreciseCoverage).result
end

local function bypassUserAgent(self: Tab)
	local object = self:evaluate("window.navigator.userAgent", true)
	local userAgent = object.value :: string?

	if userAgent == nil then
		return
	end

	userAgent = userAgent:gsub("HeadlessChrome/", "Chrome/")

	local regex = Regex.new([[\(([^)]+)\)]])
	userAgent = regex:replace(userAgent, "(Windows NT 10.0; Win64; x64)")

	self:setUserAgent(userAgent)
end

local function bypassWebDriver(self: Tab)
	self:callMethod(Page.AddScriptToEvaluateOnNewDocument, {
		source = 'Object.defineProperty(navigator, "webdriver", { get: () => undefined });',
	})
end

local function bypassChrome(self: Tab)
	self:callMethod(Page.AddScriptToEvaluateOnNewDocument, {
		source = "window.chrome = { runtime: {} };",
	})
end

local function bypassPermissions(self: Tab)
	local source = [[
		const originalQuery = window.navigator.permissions.query;
        window.navigator.permissions.__proto__.query = (parameters) =>
        parameters.name === "notifications"
            ? Promise.resolve({state: Notification.permission})
            : originalQuery(parameters);
	]]

	self:callMethod(Page.AddScriptToEvaluateOnNewDocument, {
		source = source,
	})
end

local function bypassPlugins(self: Tab)
	local source = [[
		Object.defineProperty(navigator, "plugins", {
			get: () => [
            	{ filename: "internal-pdf-viewer" },
            	{ filename: "adsfkjlkjhalkh" },
            	{ filename: "internal-nacl-plugin" },
          	],
		});
	]]

	self:callMethod(Page.AddScriptToEvaluateOnNewDocument, {
		source = source,
	})
end

local function bypassWebGlVendor(self: Tab)
	local source = [[
		const getParameter = WebGLRenderingContext.getParameter;
        WebGLRenderingContext.prototype.getParameter = (parameter) => {
            // UNMASKED_VENDOR_WEBGL
            if (parameter === 37445) {
                return "Google Inc. (NVIDIA)";
            }
			
            // UNMASKED_RENDERER_WEBGL
            if (parameter === 37446) {
                return "ANGLE (NVIDIA, NVIDIA GeForce GTX 1050 Direct3D11 vs_5_0 ps_5_0, D3D11-27.21.14.5671)";
            }

            return getParameter(parameter);
        };
	]]

	self:callMethod(Page.AddScriptToEvaluateOnNewDocument, {
		source = source,
	})
end

--- @within Tab
local function enableStealthMode(self: Tab)
	bypassUserAgent(self)
	bypassWebDriver(self)
	bypassChrome(self)
	bypassPermissions(self)
	bypassPlugins(self)
	bypassWebGlVendor(self)
end

--- Closes the target Page
--- @within Tab
local function close(self: Tab)
	self:callMethod(Target.CloseTarget, { targetId = self.targetId })
end

local function handleTabLevelEvents(self: Tab)
	self:addEventListener(Page.LifecycleEvent, function(event)
		if event.name == "networkAlmostIdle" then
			self.navigating = false
		elseif event.name == "init" then
			self.navigating = true
		end
	end)
end

--- @within Tab
local function new(targetInfo: Target.TargetInfo, transport: Transport.Transport): Tab
	local targetId = targetInfo.targetId
	local sessionId = transport:callMethodOnBrowser(Target.AttachToTarget, { targetId = targetId }).sessionId

	local tab = {
		targetId = targetId,
		transport = transport,
		sessionId = sessionId,
		navigating = false,
		targetInfo = targetInfo,
		defaultTimeout = 20,
		getTargetId = getTargetId,
		updateTargetInfo = updateTargetInfo,
		getUrl = getUrl,
		setDefaultTimeout = setDefaultTimeout,
		callMethod = callMethod,
		addEventListener = addEventListener,
		getTargetInfo = getTargetInfo,
		getBrowserContextId = getBrowserContextId,
		setUserAgent = setUserAgent,
		setExtraHttpHeaders = setExtraHttpHeaders,
		setFileChooserDialogInterception = setFileChooserDialogInterception,
		handleFileChooser = handleFileChooser,
		bringToFront = bringToFront,
		reload = reload,
		stopLoading = stopLoading,
		navigateTo = navigateTo,
		waitUntilNavigated = waitUntilNavigated,
		waitUntilRedirect = waitUntilRedirect,
		getBounds = getBounds,
		setBounds = setBounds,
		evaluate = evaluate,
		getTitle = getTitle,
		setCookies = setCookies,
		getCookies = getCookies,
		deleteCookies = deleteCookies,
		setStorage = setStorage,
		getStorage = getStorage,
		removeStorage = removeStorage,
		captureScreenshot = captureScreenshot,
		printToPdf = printToPdf,
		startScreencast = startScreencast,
		stopScreencast = stopScreencast,
		ackScreencast = ackScreencast,
		getDialog = getDialog,
		getDocument = getDocument,
		getContent = getContent,
		runQuerySelectorOnNode = runQuerySelectorOnNode,
		runQuerySelectorAllOnNode = runQuerySelectorAllOnNode,
		findElement = findElement,
		findElementByXPath = findElementByXPath,
		findElements = findElements,
		findElementsByXPath = findElementsByXPath,
		waitForElement = waitForElement,
		waitForXPath = waitForXPath,
		waitForElements = waitForElements,
		waitForElementsByXPath = waitForElementsByXPath,
		moveMouseToPoint = moveMouseToPoint,
		clickPoint = clickPoint,
		insertText = insertText,
		typeText = typeText,
		pressKeyWithModifiers = pressKeyWithModifiers,
		pressKey = pressKey,
		enableLog = enableLog,
		disableLog = disableLog,
		startViolationsReport = startViolationsReport,
		stopViolationsReport = stopViolationsReport,
		enableRuntime = enableRuntime,
		disableRuntime = disableRuntime,
		enableDebugger = enableDebugger,
		disableDebugger = disableDebugger,
		getScriptSource = getScriptSource,
		enableProfiler = enableProfiler,
		disableProfiler = disableProfiler,
		startJsCoverage = startJsCoverage,
		stopJsCoverage = stopJsCoverage,
		takeJsCoverage = takeJsCoverage,
		enableStealthMode = enableStealthMode,
		close = close,
	}

	tab:callMethod(Page.Enable)
	handleTabLevelEvents(tab)
	tab:callMethod(Page.SetLifecycleEventsEnabled, { enabled = true })

	return tab
end

return { new = new }
