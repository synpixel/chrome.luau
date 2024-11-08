local serde = require("@lune/serde")
local Regex = require("@lune/regex")
local Transport = require("../transport")
local Element = require("./element")
local Dialog = require("./dialog")
local keys = require("./keys")
local Wait = require("../utils/wait")
local base64 = require("../utils/base64")
local types = require("./types")
local Target = require("../protocol/Target")
local Page = require("../protocol/Page")
local Browser = require("../protocol/Browser")
local Runtime = require("../protocol/Runtime")
local Network = require("../protocol/Network")
local DOM = require("../protocol/DOM")
local Input = require("../protocol/Input")
local Log = require("../protocol/Log")

export type Tab = types.Tab

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
	return self:callMethod(Target.GetTargetInfo, { targetId = self.targetId }).targetInfo
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

local function bringToFront(self: Tab)
	self:callMethod(Page.BringToFront)
end

local function reload(self: Tab, ignoreCache: boolean?, scriptToEvaluateOnLoad: string?): Tab
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
	Wait.withTimeout(20):pauseUntil(function()
		return if self.navigating then Wait.None else true
	end)

	return self
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

local function getStorage(self: Tab, name: string): any
	local json = self:evaluate(`localStorage.getItem("{name}")`).value
	local item = serde.decode("json", json :: string)
	return item
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

local function onScreencast(
	self: Tab,
	callback: (
		frame: { data: buffer, metadata: Page.ScreencastFrameMetadata, sessionId: number }
	) -> ()
): () -> ()
	return self:addEventListener(Page.ScreencastFrame, function(frame)
		local data = buffer.fromstring(frame.data)

		callback({
			data = base64.decode(data),
			metadata = frame.metadata,
			sessionId = frame.sessionId,
		})
	end)
end

local function getDialog(self: Tab): Dialog.Dialog
	return Dialog.new(self.sessionId, self.transport)
end

local function getDocument(self: Tab): DOM.Node
	return self:callMethod(DOM.GetDocument, { depth = 0, pierce = false }).root
end

local function runQuerySelectorOnNode(self: Tab, nodeId: DOM.NodeId, selector: string): types.Element?
	local nodeId = self:callMethod(DOM.QuerySelector, { nodeId = nodeId, selector = selector }).nodeId
	return Element.new(self, nodeId)
end

local function runQuerySelectorAllOnNode(self: Tab, nodeId: DOM.NodeId, selector: string): { types.Element }
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

local function findElement(self: Tab, selector: string): types.Element?
	local rootNodeId = self:getDocument().nodeId
	return self:runQuerySelectorOnNode(rootNodeId, selector)
end

local function findElements(self: Tab, selector: string): { types.Element }
	local rootNodeId = self:getDocument().nodeId
	return self:runQuerySelectorAllOnNode(rootNodeId, selector)
end

local function waitForElement(self: Tab, selector: string, timeout: number?): types.Element
	local timeout = timeout or self.defaultTimeout

	return Wait.withTimeout(timeout):pauseUntil(function()
		local element = self:findElement(selector)
		if element == nil then
			return Wait.None :: any
		end

		return element
	end)
end

local function waitForElements(self: Tab, selector: string, timeout: number?): { types.Element }
	local timeout = timeout or self.defaultTimeout

	return Wait.withTimeout(timeout):pauseUntil(function()
		local elements = self:findElements(selector)
		if #elements <= 0 then
			return Wait.None :: any
		end

		return elements
	end)
end

local function moveMouseToPoint(self: Tab, point: types.Point): Tab
	self:callMethod(Input.DispatchMouseEvent, {
		type = "mouseMoved",
		x = point.x,
		y = point.y,
	})

	return self
end

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

local function insertText(self: Tab, text: string): Tab
	self:callMethod(Input.InsertText, { text = text })
	return self
end

local function typeText(self: Tab, text: string): Tab
	for _, char in text:split("") do
		local definition = keys.getKeyDefinition(char)
		if definition ~= nil then
			self:pressKey(definition.key)
		else
			self:insertText(char)
		end
	end

	return self
end

local function pressKeyWithModifiers(self: Tab, key: string, modifiers: { "Alt" | "Ctrl" | "Meta" | "Shift" }?): Tab
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

local function pressKey(self: Tab, key: string): Tab
	return self:pressKeyWithModifiers(key)
end

local function startViolationsReport(self: Tab, config: { Log.ViolationSetting }): Tab
	self:callMethod(Log.StartViolationsReport, { config = config })
	return self
end

local function stopViolationsReport(self: Tab): Tab
	self:callMethod(Log.StopViolationsReport)
	return self
end

local function bypassUserAgent(self: Tab)
	local object = self:evaluate("window.navigator.userAgent", true)
	local userAgent = object.value :: string?

	if userAgent == nil then
		return
	end

	userAgent = userAgent:gsub("HeadlessChrome/", "Chrome/")

	local regex = Regex.new("(([^)]+))")
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
            	{filename: "internal-pdf-viewer"},
            	{filename: "adsfkjlkjhalkh"},
            	{filename: "internal-nacl-plugin"},
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
		bringToFront = bringToFront,
		reload = reload,
		stopLoading = stopLoading,
		navigateTo = navigateTo,
		waitUntilNavigated = waitUntilNavigated,
		getBounds = getBounds,
		setBounds = setBounds,
		evaluate = evaluate,
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
		onScreencast = onScreencast,
		getDialog = getDialog,
		getDocument = getDocument,
		runQuerySelectorOnNode = runQuerySelectorOnNode,
		runQuerySelectorAllOnNode = runQuerySelectorAllOnNode,
		findElement = findElement,
		findElements = findElements,
		waitForElement = waitForElement,
		waitForElements = waitForElements,
		moveMouseToPoint = moveMouseToPoint,
		clickPoint = clickPoint,
		insertText = insertText,
		typeText = typeText,
		pressKeyWithModifiers = pressKeyWithModifiers,
		pressKey = pressKey,
		startViolationsReport = startViolationsReport,
		stopViolationsReport = stopViolationsReport,
		enableStealthMode = enableStealthMode,
		close = close,
	}

	tab:callMethod(Page.Enable)
	handleTabLevelEvents(tab)
	tab:callMethod(Page.SetLifecycleEventsEnabled, { enabled = true })

	return tab
end

return { new = new }
