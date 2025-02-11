local serde = require("@lune/serde")
local Regex = require("@lune/regex")
local task = require("@lune/task")
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
local Emulation = require("../protocol/Emulation")
local Runtime = require("../protocol/Runtime")
local Network = require("../protocol/Network")
local DOM = require("../protocol/DOM")
local Input = require("../protocol/Input")
local Log = require("../protocol/Log")
local Debugger = require("../protocol/Debugger")
local Profiler = require("../protocol/Profiler")
local Fetch = require("../protocol/Fetch")

export type Tab = types.Tab

export type Element = Element.Element
export type ElementQuad = ElementQuad.ElementQuad
export type BoxModel = BoxModel.BoxModel

local function getTargetId(self: Tab): string
	return self.targetId
end

local function updateTargetInfo(self: Tab, targetInfo: Target.TargetInfo)
	self.targetInfo = targetInfo
end

local function getUrl(self: Tab): string
	return self.targetInfo.url
end

local function setDefaultTimeout(self: Tab, timeout: number): Tab
	self.defaultTimeout = timeout
	return self
end

local function setSlowMotionMultiplier(self: Tab, multiplier: number): Tab
	self.slowMotionMultiplier = multiplier
	return self
end

local function optionalSlowMotionSleep(self: Tab, millis: number)
	if self.slowMotionMultiplier == 0 then
		return
	end

	local seconds = millis / 1000
	task.wait(seconds * self.slowMotionMultiplier)
end

local function callMethod<Request, Response>(
	self: Tab,
	method: string & { __Request: Request, __Response: Response },
	parameters: Request
): Response
	return self.transport:callMethodOnTarget(method, parameters, self.sessionId)
end

local function addEventListener<Parameters>(
	self: Tab,
	event: string & { __Parameters: Parameters },
	callback: (params: Parameters) -> ()
): () -> ()
	return self.transport:listenToTargetEvent(event, self.sessionId, callback)
end

local function getTargetInfo(self: Tab): Target.TargetInfo
	return self.transport:callMethodOnBrowser(Target.GetTargetInfo, { targetId = self.targetId }).targetInfo
end

local function getBrowserContextId(self: Tab): string?
	local targetInfo = self:getTargetInfo()
	return targetInfo.browserContextId
end

local function setUserAgent(self: Tab, userAgent: string, acceptLanguage: string?, platform: string?)
	self:callMethod(
		Network.SetUserAgentOverride,
		{ userAgent = userAgent, acceptLanguage = acceptLanguage, platform = platform }
	)
end

local function setExtraHttpHeaders(self: Tab, headers: { [string]: string })
	self:callMethod(Network.Enable, {})
	self:callMethod(Network.SetExtraHTTPHeaders, { headers = headers })
end

local function setFileChooserDialogInterception(self: Tab, enabled: boolean)
	self:callMethod(Page.SetInterceptFileChooserDialog, { enabled = enabled })
end

local function handleFileChooser(self: Tab, files: { string }, nodeId: DOM.NodeId)
	self:callMethod(DOM.SetFileInputFiles, { files = files, nodeId = nodeId })
end

local function bringToFront(self: Tab)
	self:callMethod(Page.BringToFront)
end

local function reload(self: Tab, ignoreCache: boolean?, scriptToEvaluateOnLoad: string?): Tab
	optionalSlowMotionSleep(self, 100)
	self:callMethod(Page.Reload, { ignoreCache = ignoreCache, scriptToEvaluateOnLoad = scriptToEvaluateOnLoad })
	return self
end

local function stopLoading(self: Tab)
	self:callMethod(Page.StopLoading)
end

local function navigateTo(self: Tab, url: string): Tab
	self:callMethod(Page.Navigate, { url = url })
	self.navigating = true

	return self
end

local function waitUntilNavigated(self: Tab): Tab
	Wait.withTimeout(self.defaultTimeout):pauseUntil(function()
		return if self.navigating then Wait.None else nil
	end)

	return self
end

local function waitUntilRedirect(self: Tab): Tab
	self.navigating = true
	return self:waitUntilNavigated()
end

local function getBounds(self: Tab): Browser.Bounds
	return self.transport:callMethodOnBrowser(Browser.GetWindowForTarget, { targetId = self.targetId }).bounds
end

local function setBounds(self: Tab, bounds: Browser.Bounds): Tab
	local windowId =
		self.transport:callMethodOnBrowser(Browser.GetWindowForTarget, { targetId = self.targetId }).windowId

	self.transport:callMethodOnBrowser(Browser.SetWindowBounds, { windowId = windowId, bounds = bounds })

	return self
end

local function setTransparentBackgroundColor(self: Tab): Tab
	self:callMethod(Emulation.SetDefaultBackgroundColorOverride, {
		color = { r = 0, g = 0, b = 0, a = 0 },
	})
	return self
end

local function setBackgroundColor(self: Tab, color: DOM.RGBA): Tab
	self:callMethod(Emulation.SetDefaultBackgroundColorOverride, { color = color })
	return self
end

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

local function getTitle(self: Tab): string
	local result = self:evaluate("document.title")
	return result.value :: string
end

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

local function getCookies(self: Tab): { Network.Cookie }
	return self:callMethod(Network.GetCookies, {}).cookies
end

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

local function setStorage(self: Tab, name: string, item: any)
	local json = serde.encode("json", item)
	local value = if typeof(item) == "string" then json else `JSON.stringify({json})`
	self:evaluate(`localStorage.setItem("{name}", {value})`)
end

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

local function removeStorage(self: Tab, name: string)
	self:evaluate(`localStorage.removeItem("{name}")`)
end

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

local function stopScreencast(self: Tab)
	self:callMethod(Page.StopScreencast)
end

local function ackScreencast(self: Tab, sessionId: number)
	self:callMethod(Page.ScreencastFrameAck, { sessionId = sessionId })
end

local function getDialog(self: Tab): Dialog.Dialog
	return Dialog.new(self.sessionId, self.transport)
end

local function getDocument(self: Tab): DOM.Node
	return self:callMethod(DOM.GetDocument, { depth = 0, pierce = false }).root
end

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

local function describeNode(self: Tab, nodeId: DOM.NodeId): DOM.Node
	return self:callMethod(DOM.DescribeNode, { nodeId = nodeId, depth = 100 }).node
end

local function runQuerySelectorOnNode(self: Tab, nodeId: DOM.NodeId, selector: string): Element?
	local nodeId = self:callMethod(DOM.QuerySelector, { nodeId = nodeId, selector = selector }).nodeId
	return Element.new(self, nodeId)
end

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

local function findElement(self: Tab, selector: string): Element?
	local rootNodeId = self:getDocument().nodeId
	return self:runQuerySelectorOnNode(rootNodeId, selector)
end

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

local function findElements(self: Tab, selector: string): { Element }
	local rootNodeId = self:getDocument().nodeId
	return self:runQuerySelectorAllOnNode(rootNodeId, selector)
end

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

local function moveMouseToPoint(self: Tab, point: types.Point): Tab
	optionalSlowMotionSleep(self, 100)

	self:callMethod(Input.DispatchMouseEvent, {
		type = "mouseMoved",
		x = point.x,
		y = point.y,
	})

	return self
end

local function clickPoint(self: Tab, point: types.Point): Tab
	self:moveMouseToPoint(point)

	optionalSlowMotionSleep(self, 250)

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

local function insertText(self: Tab, text: string): Tab
	self:callMethod(Input.InsertText, { text = text })
	return self
end

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

	optionalSlowMotionSleep(self, 25)

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

local function pressKey(self: Tab, key: keys.Key): Tab
	return self:pressKeyWithModifiers(key)
end

local function enableLog(self: Tab): Tab
	self:callMethod(Log.Enable)
	return self
end

local function disableLog(self: Tab): Tab
	self:callMethod(Log.Disable)
	return self
end

local function startViolationsReport(self: Tab, config: { Log.ViolationSetting }): Tab
	self:callMethod(Log.StartViolationsReport, { config = config })
	return self
end

local function stopViolationsReport(self: Tab): Tab
	self:callMethod(Log.StopViolationsReport)
	return self
end

local function enableRuntime(self: Tab): Tab
	self:callMethod(Runtime.Enable)
	return self
end

local function disableRuntime(self: Tab): Tab
	self:callMethod(Runtime.Disable)
	return self
end

local function enableDebugger(self: Tab): Tab
	self:callMethod(Debugger.Enable, {})
	return self
end

local function disableDebugger(self: Tab): Tab
	self:callMethod(Debugger.Disable)
	return self
end

local function getScriptSource(self: Tab, scriptId: string): string
	return self:callMethod(Debugger.GetScriptSource, { scriptId = scriptId }).scriptSource
end

local function enableProfiler(self: Tab): Tab
	self:callMethod(Profiler.Enable)
	return self
end

local function disableProfiler(self: Tab): Tab
	self:callMethod(Profiler.Disable)
	return self
end

local function startJsCoverage(self: Tab): Tab
	self:callMethod(Profiler.StartPreciseCoverage, { callCount = true, detailed = true })
	return self
end

local function stopJsCoverage(self: Tab): Tab
	self:callMethod(Profiler.StopPreciseCoverage)
	return self
end

local function takeJsCoverage(self: Tab): { Profiler.ScriptCoverage }
	return self:callMethod(Profiler.TakePreciseCoverage).result
end

local function enableFetch(self: Tab, patterns: { Fetch.RequestPattern }?, handleAuthRequests: boolean?): Tab
	self:callMethod(Fetch.Enable, { patterns = patterns, handleAuthRequests = handleAuthRequests })
	return self
end

local function disableFetch(self: Tab): Tab
	self:callMethod(Fetch.Disable)
	return self
end

local function enableRequestInterception(self: Tab, interceptor: types.RequestInterceptor)
	self.requestInterceptor = interceptor
end

--- @within Tab
local function authenticate(self: Tab, username: string?, password: string?): Tab
	self.authHandler = {
		response = "ProvideCredentials",
		username = username,
		password = password,
	}
	return self
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

local function enableStealthMode(self: Tab)
	bypassUserAgent(self)
	bypassWebDriver(self)
	bypassChrome(self)
	bypassPermissions(self)
	bypassPlugins(self)
	bypassWebGlVendor(self)
end

local function close(self: Tab)
	optionalSlowMotionSleep(self, 50)
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

	self:addEventListener(Fetch.RequestPaused, function(params)
		local interceptor = self.requestInterceptor
		if interceptor == nil then
			self:callMethod(Fetch.ContinueRequest, { requestId = params.requestId })
			return
		end

		local decision = interceptor(self.transport, self.sessionId, params)

		if decision.action == "Continue" then
			if (decision :: any).requestId ~= nil then
				self:callMethod(Fetch.ContinueRequest, decision :: any)
			else
				self:callMethod(Fetch.ContinueRequest, { requestId = params.requestId })
			end
		elseif decision.action == "Fulfill" then
			self:callMethod(Fetch.FulfillRequest, decision)
		elseif decision.action == "Fail" then
			self:callMethod(Fetch.FailRequest, decision)
		end
	end)

	self:addEventListener(Fetch.AuthRequired, function(params)
		local response = self.authHandler
		if response == nil then
			return
		end

		local requestId = params.requestId
		self:callMethod(Fetch.ContinueWithAuth, {
			requestId = requestId,
			authChallengeResponse = response,
		})
	end)
end

local function new(targetInfo: Target.TargetInfo, transport: Transport.Transport): Tab
	local targetId = targetInfo.targetId
	local sessionId = transport:callMethodOnBrowser(Target.AttachToTarget, { targetId = targetId }).sessionId

	local tab = {
		targetId = targetId,
		transport = transport,
		sessionId = sessionId,
		navigating = false,
		targetInfo = targetInfo,
		requestInterceptor = nil,
		authHandler = nil,
		defaultTimeout = 20,
		slowMotionMultiplier = 0,
		getTargetId = getTargetId,
		updateTargetInfo = updateTargetInfo,
		getUrl = getUrl,
		setDefaultTimeout = setDefaultTimeout,
		setSlowMotionMultiplier = setSlowMotionMultiplier,
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
		setTransparentBackgroundColor = setTransparentBackgroundColor,
		setBackgroundColor = setBackgroundColor,
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
		describeNode = describeNode,
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
		enableFetch = enableFetch,
		disableFetch = disableFetch,
		enableRequestInterception = enableRequestInterception,
		authenticate = authenticate,
		enableStealthMode = enableStealthMode,
		close = close,
	}

	tab:callMethod(Page.Enable)
	tab:callMethod(Page.SetLifecycleEventsEnabled, { enabled = true })

	handleTabLevelEvents(tab)

	return tab
end

return { new = new }
