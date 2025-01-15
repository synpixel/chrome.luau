local Transport = require("./transport")
local Dialog = require("./tab/dialog")
local keys = require("./tab/keys")
local Target = require("./protocol/Target")
local Page = require("./protocol/Page")
local Browser = require("./protocol/Browser")
local Runtime = require("./protocol/Runtime")
local Network = require("./protocol/Network")
local DOM = require("./protocol/DOM")
local Log = require("./protocol/Log")
local Profiler = require("./protocol/Profiler")
local Fetch = require("./protocol/Fetch")

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
	tabs: { Tab },

	--- @within Browser
	getTabs: (self: Browser) -> { Tab },

	--- Call a browser method.
	--- @within Browser
	callMethod: <Request, Response>(
		self: Browser,
		method: string & { __Request: Request, __Response: Response },
		params: Request
	) -> Response,

	--- Adds event listener to `event`
	--- @within Browser
	addEventListener: <Parameters>(
		self: Browser,
		event: string & { __Parameters: Parameters },
		callback: (params: Parameters) -> ()
	) -> () -> (),

	--- Get version information
	--- @within Browser
	getVersion: (
		self: Browser
	) -> {
		protocolVersion: string,
		product: string,
		revision: string,
		userAgent: string,
		jsVersion: string,
	},

	--- Create a new tab with a starting url, height / width, context ID and 'frame control'
	--- @within Browser
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
	) -> Tab,

	--- Create a new tab and return a handle to it.
	--- If you want to specify its starting options, see `newTabWithOptions`.
	--- @within Browser
	newTab: (self: Browser) -> Tab,

	--- Creates the equivalent of a new incognito window, AKA a browser context
	--- @within Browser
	newContext: (self: Browser) -> Context,

	--- Adds tabs that have not been opened with `newTab` to the list of tabs
	--- @within Browser
	registerMissingTabs: (self: Browser) -> (),

	--- Closes the browser.
	--- @within Browser
	close: (self: Browser) -> (),
}

--- Equivalent to a new incognito window
--- @class Context
export type Context = {
	id: string,
	browser: Browser,

	--- The BrowserContextId associated with this context
	--- @within Context
	getId: (self: Context) -> string,

	--- Any tabs created in this context
	--- @within Context
	getTabs: (self: Context) -> { Tab },

	--- Opens a new tab in this context. It will not share cookies or a cache with the default
	--- browsing context or any other contexts created
	--- @within Context
	newTab: (self: Context) -> Tab,
}

--- A handle to a single page. Exposes methods for simulating user actions (clicking,
--- typing), and also for getting information about the DOM and other parts of the page.
--- @class Tab
export type Tab = {
	targetId: string,
	transport: Transport.Transport,
	sessionId: string,
	navigating: boolean,
	targetInfo: Target.TargetInfo,
	requestInterceptor: RequestInterceptor?,
	-- TODO: response_handler
	-- TODO: loading_failed_handler
	authHandler: Fetch.AuthChallengeResponse?,
	defaultTimeout: number,
	-- TODO: page_bindings
	slowMotionMultiplier: number,

	--- @within Tab
	getTargetId: (self: Tab) -> string,

	--- @within Tab
	updateTargetInfo: (self: Tab, targetInfo: Target.TargetInfo) -> (),

	--- @within Tab
	getUrl: (self: Tab) -> string,

	--- Set default timeout for the tab
	--- This will be applied to all `waitForElement` and `waitForElements` calls without a timeout for this tab
	--- @within Tab
	setDefaultTimeout: (self: Tab, timeout: number) -> Tab,

	--[=[
		Analogous to Puppeteer's ['slowMo' option](https://github.com/GoogleChrome/puppeteer/blob/v1.20.0/docs/api.md#puppeteerconnectoptions),
		but with some differences:

		* It doesn't add a delay after literally every message sent via the protocol, but instead
		just for:
			* clicking a specific point on the page (default: 100ms before moving the mouse, 250ms
			before pressing and releasting mouse button)
			* pressing a key (default: 25 ms)
			* reloading the page (default: 100ms)
			* closing a tab (default: 100ms)
		* Instead of an absolute number of milliseconds, it's a multiplier, so that we can delay
		longer on certain actions like clicking or moving the mouse, and shorter on others like
		on pressing a key (or the individual 'mouseDown' and 'mouseUp' actions that go across the
		wire. If the delay was always the same, filling out a form (e.g.) would take ages).

		By default the multiplier is set to zero, which effectively disables the slow motion.

		The defaults for the various actions (i.e. how long we sleep for when
		multiplier is 1.0) are supposed to be just slow enough to help a human see what's going on
		as a test runs.

		@within Tab
	]=]
	setSlowMotionMultiplier: (self: Tab, multiplier: number) -> Tab,

	--- Call a target method.
	--- @within Tab
	callMethod: <Request, Response>(
		self: Tab,
		method: string & { __Request: Request, __Response: Response },
		params: Request
	) -> Response,

	--- Adds event listener to `event`
	--- @within Tab
	addEventListener: <Parameters>(
		self: Tab,
		event: string & { __Parameters: Parameters },
		callback: (params: Parameters) -> ()
	) -> () -> (),

	--- Fetches the most recent info about this target
	--- @within Tab
	getTargetInfo: (self: Tab) -> Target.TargetInfo,

	--- @within Tab
	getBrowserContextId: (self: Tab) -> string?,

	--- Allows overriding user agent with the given string.
	--- @within Tab
	setUserAgent: (self: Tab, userAgent: string, acceptLanguage: string?, platform: string?) -> (),

	--- @within Tab
	setExtraHttpHeaders: (self: Tab, headers: { [string]: string }) -> (),

	--- If enabled, instead of using the GUI to select files, the browser will
	--- wait for the `handleFileChooser` method to be called.
	--- \**WARNING**: Only works on Chromium / Chrome 77 and above.
	--- @within Tab
	setFileChooserDialogInterception: (self: Tab, enabled: boolean) -> (),

	--[=[
		Will have the same effect as choosing these files from the file chooser dialog that would've
		popped up had `setFileChooserDialogInterception` not been called. Calls to this method
		must be preceded by calls to that method.

		Supports selecting files or closing the file chooser dialog.

		NOTE: the filepaths listed in `files` must be absolute.

		@within Tab
	]=]
	handleFileChooser: (self: Tab, files: { string }, nodeId: DOM.NodeId) -> (),

	--- Pulls focus to this tab
	--- @within Tab
	bringToFront: (self: Tab) -> (),

	--[=[
		Reloads given page optionally ignoring the cache

		If `ignoreCache` is true, the browser cache is ignored (as if the user pressed Shift+F5).  
		If `scriptToEvaluate` is given, the script will be injected into all frames of the
		inspected page after reload. Argument will be ignored if reloading dataURL origin.

		@within Tab
	]=]
	reload: (self: Tab, ignoreCache: boolean?, scriptToEvaluateOnLoad: string?) -> Tab,

	--- @within Tab
	stopLoading: (self: Tab) -> (),

	--- @within Tab
	navigateTo: (self: Tab, url: string) -> Tab,

	--- @within Tab
	waitUntilNavigated: (self: Tab) -> Tab,

	--- @within Tab
	waitUntilRedirect: (self: Tab) -> Tab,

	--[=[
		Get position and size of the browser window associated with this `Tab`.

		Note that the returned bounds are always specified for normal (windowed)
		state; they do not change when minimizing, maximizing or setting to
		fullscreen.

		@within Tab
	]=]
	getBounds: (self: Tab) -> Browser.Bounds,

	--[=[
		Set position and/or size of the browser window associated with this `Tab`.

		When setting the window to normal (windowed) state, unspecified fields
		are left unchanged.

		@within Tab
	]=]
	setBounds: (self: Tab, bounds: Browser.Bounds) -> Tab,

	--- Set the background color of the dom to transparent.
	--- Useful when you want capture a .png
	--- @within Tab
	setTransparentBackgroundColor: (self: Tab) -> Tab,

	--- Set the default background color of the dom.
	--- Pass a RGBA to override the backrgound color of the dom.
	--- @within Tab
	setBackgroundColor: (self: Tab, color: DOM.RGBA) -> Tab,

	--- Evaluates expression on global object.
	--- @within Tab
	evaluate: (self: Tab, expression: string, awaitPromise: boolean?) -> Runtime.RemoteObject,

	--- Returns the title of the document.
	--- @within Tab
	getTitle: (self: Tab) -> string,

	--- Set cookies with tab's current URL
	--- @within Tab
	setCookies: (self: Tab, cookies: { Network.CookieParam }) -> (),

	--- Returns all cookies that match the tab's current URL.
	--- @within Tab
	getCookies: (self: Tab) -> { Network.Cookie },

	--- Delete cookies with tab's current URL
	--- @within Tab
	deleteCookies: (
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
	) -> (),

	--- @within Tab
	setStorage: (self: Tab, name: string, item: any) -> (),

	--- @within Tab
	getStorage: (self: Tab, name: string) -> any?,

	--- @within Tab
	removeStorage: (self: Tab, name: string) -> (),

	--[=[
		Capture a screenshot of the current page.

		If `clip` is given, the screenshot is taken of the specified region only.
		`Element.getBoxModel` can be used to get regions of certains elements on the page; there is
		also `Element.captureScreenshot` as a shorthand.

		If `fromSurface` is true, the screenshot is taken from the surface rather than the view.

		@within Tab
	]=]
	captureScreenshot: (
		self: Tab,
		options: {
			format: "jpeg" | "png" | "webp"?,
			quality: number?,
			clip: Page.Viewport?,
			fromSurface: boolean?,
			captureBeyondViewport: boolean?,
			optimizeForSpeed: boolean?,
		}
	) -> buffer,

	--- @within Tab
	printToPdf: (
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
	) -> buffer,

	--- @within Tab
	startScreencast: (
		self: Tab,
		options: {
			format: "jpeg" | "png"?,
			quality: number?,
			maxWidth: number?,
			maxHeight: number?,
			everyNthFrame: number?,
		}
	) -> (),

	--- @within Tab
	stopScreencast: (self: Tab) -> (),

	--- @within Tab
	ackScreencast: (self: Tab, sessionId: number) -> (),

	--- Get the handle of the dialog opened in this tab.
	--- @within Tab
	getDialog: (self: Tab) -> Dialog.Dialog,

	--- @within Tab
	getDocument: (self: Tab) -> DOM.Node,

	--- Get the full HTML contents of the page.
	--- @within Tab
	getContent: (self: Tab) -> string,

	--- @within Tab
	describeNode: (self: Tab, nodeId: DOM.NodeId) -> DOM.Node,

	--- @within Tab
	runQuerySelectorOnNode: (self: Tab, nodeId: DOM.NodeId, selector: string) -> Element?,

	--- @within Tab
	runQuerySelectorAllOnNode: (self: Tab, nodeId: DOM.NodeId, selector: string) -> { Element },

	--- Returns the first element in the document which matches the given selector.
	--- Equivalent to the following JS:
	--- ```js
	--- document.querySelector(selector)
	--- ```
	--- @within Tab
	findElement: (self: Tab, selector: string) -> Element?,

	--- @within Tab
	findElementByXPath: (self: Tab, selector: string) -> Element?,

	--- @within Tab
	findElements: (self: Tab, selector: string) -> { Element },

	--- @within Tab
	findElementsByXPath: (self: Tab, selector: string) -> { Element },

	--- @within Tab
	waitForElement: (self: Tab, selector: string, timeout: number?) -> Element,

	--- @within Tab
	waitForXPath: (self: Tab, selector: string, timeout: number?) -> Element,

	--- @within Tab
	waitForElements: (self: Tab, selector: string, timeout: number?) -> { Element },

	--- @within Tab
	waitForElementsByXPath: (self: Tab, selector: string, timeout: number?) -> { Element },

	--- Moves the mouse to this point (dispatches a mouseMoved event)
	--- @within Tab
	moveMouseToPoint: (self: Tab, point: Point) -> Tab,

	--- @within Tab
	clickPoint: (self: Tab, point: Point) -> Tab,

	--- Does the same as `typeText` but it only dispatches a `keypress` and `input` event.
	--- It does not send a `keydown` or `keyup` event. What this means is that it is much faster.
	--- It is especially useful when you have a lot of text as input.
	--- @within Tab
	insertText: (self: Tab, text: string) -> Tab,

	--- @within Tab
	typeText: (self: Tab, text: string) -> Tab,

	--- Press a key on the keyboard, optionally with some modifier keys.
	--- See [this file](https://github.com/puppeteer/puppeteer/blob/62da2366c65b335751896afbb0206f23c61436f1/lib/USKeyboardLayout.js)
	--- for a full definition of which strings correspond with which keys.
	--- @within Tab
	pressKeyWithModifiers: (self: Tab, key: keys.Key, modifiers: { "Alt" | "Ctrl" | "Meta" | "Shift" }?) -> Tab,

	--- Press a key on the keyboard. See [this file](https://github.com/puppeteer/puppeteer/blob/62da2366c65b335751896afbb0206f23c61436f1/lib/USKeyboardLayout.js)
	--- for a full definition of which strings correspond with which keys.
	--- @within Tab
	pressKey: (self: Tab, key: keys.Key) -> Tab,

	--- Enables log domain.
	--- Sends the entries collected so far to the client by means of the entryAdded notification.
	--- See <https://chromedevtools.github.io/devtools-protocol/tot/Log#method-enable>.
	--- @within Tab
	enableLog: (self: Tab) -> Tab,

	--- Disables log domain.
	--- Prevents further log entries from being reported to the client.
	--- See <https://chromedevtools.github.io/devtools-protocol/tot/Log#method-disable>.
	--- @within Tab
	disableLog: (self: Tab) -> Tab,

	--- Starts violation reporting.
	--- See <https://chromedevtools.github.io/devtools-protocol/tot/Log#method-startViolationsReport>.
	--- @within Tab
	startViolationsReport: (self: Tab, config: { Log.ViolationSetting }) -> Tab,

	--- Stops violation reporting.
	--- See <https://chromedevtools.github.io/devtools-protocol/tot/Log#method-stopViolationsReport>.
	--- @within Tab
	stopViolationsReport: (self: Tab) -> Tab,

	--- Enables runtime domain.
	--- @within Tab
	enableRuntime: (self: Tab) -> Tab,

	--- Disables runtime domain.
	--- @within Tab
	disableRuntime: (self: Tab) -> Tab,

	--- Enables debugger domain.
	--- @within Tab
	enableDebugger: (self: Tab) -> Tab,

	--- Disables debugger domain.
	--- @within Tab
	disableDebugger: (self: Tab) -> Tab,

	--- Returns source for the script with given id.
	--- Debugger domain must be enabled.
	--- @within Tab
	getScriptSource: (self: Tab, scriptId: string) -> string,

	--- Enables the profiler domain.
	--- @within Tab
	enableProfiler: (self: Tab) -> Tab,

	--- Disables the profiler domain.
	--- @within Tab
	disableProfiler: (self: Tab) -> Tab,

	--[=[
		Starts tracking which lines of JS have been executed

		Will error unless `enableProfiler` has been called.

		Equivalent to hitting the record button in the "coverage" tab in Chrome DevTools.

		By default we enable the 'detailed' flag on StartPreciseCoverage, which enables block-level
		granularity, and also enable 'callCount' (which when disabled always sets count to 1 or 0).

		@within Tab
	]=]
	startJsCoverage: (self: Tab) -> Tab,

	--- Stops tracking which lines of JS have been executed.
	--- If you're finished with the profiler, don't forget to call `disableProfiler`.
	--- @within Tab
	stopJsCoverage: (self: Tab) -> Tab,

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
	takeJsCoverage: (self: Tab) -> { Profiler.ScriptCoverage },

	--- Enables fetch domain.
	--- @within Tab
	enableFetch: (self: Tab, patterns: { Fetch.RequestPattern }?, handleAuthRequests: boolean?) -> Tab,

	--- Disables fetch domain.
	--- @within Tab
	disableFetch: (self: Tab) -> Tab,

	--[=[
		Allows you to inspect outgoing network requests from the tab, and optionally return
		your own responses to them

		The `interceptor` argument is a closure which takes this tab's `Transport` and its SessionID
		so that you can call methods from within the closure using `transport.callMethodOnTarget`.

		The closure needs to return { action: "Fulfill" | "Fail" | "Continue", ... }.

		@within Tab
	]=]
	enableRequestInterception: (self: Tab, interceptor: RequestInterceptor) -> (),

	--- @within Tab
	authenticate: (self: Tab, username: string, password: string?) -> Tab,

	--- @within Tab
	enableStealthMode: (self: Tab) -> (),

	--- Closes the target Page
	--- @within Tab
	close: (self: Tab) -> (),
}

export type RequestInterceptor = (
	transport: Transport.Transport,
	sessionId: string,
	params: {
		requestId: Fetch.RequestId,
		request: Network.Request,
		frameId: Page.FrameId,
		resourceType: Network.ResourceType,
		responseErrorReason: Network.ErrorReason?,
		responseStatusCode: number?,
		responseStatusText: string?,
		responseHeaders: { Fetch.HeaderEntry }?,
		networkId: Network.RequestId?,
		redirectedRequestId: Fetch.RequestId?,
	}
) -> {
	action: "Fulfill",
	requestId: Fetch.RequestId,
	responseCode: number,
	responseHeaders: { Fetch.HeaderEntry }?,
	binaryResponseHeaders: string?,
	body: string?,
	responsePhrase: string?,
} | {
	action: "Fail",
	requestId: Fetch.RequestId,
	errorReason: Network.ErrorReason,
} | {
	action: "Continue",
} | {
	action: "Continue",
	requestId: Fetch.RequestId,
	url: string?,
	method: string?,
	postData: string?,
	headers: { Fetch.HeaderEntry }?,
	interceptResponse: boolean?,
}

--[=[
	A handle to a [DOM Element](https://developer.mozilla.org/en-US/docs/Web/API/Element).

	Typically you get access to these by passing `Tab.waitForElement` a CSS selector. Once
	you have a handle to an element, you can click it, type into it, inspect its
	attributes, and more. You can even run a JavaScript function inside the tab which can reference
	the element via `this`.

	@class Element
]=]
export type Element = {
	--- @prop remoteObjectId string
	--- @within Element
	remoteObjectId: string,

	--- @prop backendNodeId DOM.NodeId
	--- @within Element
	backendNodeId: DOM.BackendNodeId,

	--- @prop nodeId DOM.NodeId
	--- @within Element
	nodeId: DOM.NodeId,

	--- @prop parent Tab
	--- @within Element
	parent: Tab,

	--- @prop attributes { string }?
	--- @within Element
	attributes: { string }?,

	--- @prop tag string
	--- @within Element
	tag: string,

	--- @prop value string
	--- @within Element
	value: string,

	--- @within Element
	getDescription: (self: Element) -> DOM.Node,

	--- @within Element
	getAttributes: (self: Element) -> { string }?,

	--- @within Element
	getAttributeValue: (self: Element, name: string) -> string?,

	--[=[
		Returns the inner text of an HTML Element. Returns an empty string on elements with no text.

		Note: .innerText and .textContent are not the same thing. See:
		<https://developer.mozilla.org/en-US/docs/Web/API/HTMLElement/innerText>

		Note: if you somehow call this on a node that's not an HTML Element (e.g. `document`), this
		will fail.

		@within Element
	]=]
	getInnerText: (self: Element) -> string,

	--- Get the full HTML contents of the element.
	--- Equivalent to the following JS: ```element.outerHTML```.
	--- @within Element
	getContent: (self: Element) -> string,

	--- @within Element
	findElement: (self: Element, selector: string) -> Element?,

	--- @within Element
	findElements: (self: Element, selector: string) -> { Element },

	--- @within Element
	waitForElement: (self: Element, selector: string, timeout: number?) -> Element,

	--- @within Element
	waitForElements: (self: Element, selector: string, timeout: number?) -> { Element },

	--- @within Element
	callJsFunction: (
		self: Element,
		functionDeclaration: string,
		args: { string }?,
		awaitPromise: boolean?
	) -> Runtime.RemoteObject,

	--- @within Element
	getMidpoint: (self: Element) -> Point,

	--- Get boxes for this element
	--- @within Element
	getBoxModel: (self: Element) -> BoxModel,

	--- Scrolls the current element into view
	--- Used prior to any action applied to the current element to ensure action is duable.
	--- @within Element
	scrollIntoView: (self: Element) -> Element,

	--- Moves the mouse to the middle of this element
	--- @within Element
	moveMouseOver: (self: Element) -> Element,

	--- @within Element
	click: (self: Element) -> Element,

	--- @within Element
	typeInto: (self: Element, text: string) -> Element,

	--- @within Element
	focus: (self: Element) -> Element,

	--- Capture a screenshot of this element.
	--- The screenshot is taken from the surface using this element's content-box.
	--- @within Element
	captureScreenshot: (
		self: Element,
		options: {
			format: "jpeg" | "png" | "webp"?,
			quality: number?,
			fromSurface: boolean?,
			optimizeForSpeed: boolean?,
		}
	) -> buffer,
}

export type Point = { x: number, y: number }

--- @class ElementQuad
export type ElementQuad = {
	topLeft: Point,
	topRight: Point,
	bottomRight: Point,
	bottomLeft: Point,

	--- @within ElementQuad
	height: (self: ElementQuad) -> number,

	--- @within ElementQuad
	width: (self: ElementQuad) -> number,

	--- The width divided by the height
	--- @within ElementQuad
	aspectRatio: (self: ElementQuad) -> number,

	--- The most left (smallest) x-coordinate
	--- @within ElementQuad
	mostLeft: (self: ElementQuad) -> number,

	--- The most right (largest) x-coordinate
	--- @within ElementQuad
	mostRight: (self: ElementQuad) -> number,

	--- The most top (smallest) y-coordinate
	--- @within ElementQuad
	mostTop: (self: ElementQuad) -> number,

	--- The most bottom (largest) y-coordinate
	--- @within ElementQuad
	mostBottom: (self: ElementQuad) -> number,

	--- If the most bottom point of `self` is above the most top point of `other`
	--- @within ElementQuad
	strictlyAbove: (self: ElementQuad, other: ElementQuad) -> boolean,

	--- If the most bottom point of `self` is above or on the same line as the
	--- most top point of `other`
	--- @within ElementQuad
	above: (self: ElementQuad, other: ElementQuad) -> boolean,

	--- If the most top point of `self` is below the most bottom point of `other`
	--- @within ElementQuad
	strictlyBelow: (self: ElementQuad, other: ElementQuad) -> boolean,

	--- If the most top point of `self` is below or on the same line as the
	--- most bottom point of `other`
	--- @within ElementQuad
	below: (self: ElementQuad, other: ElementQuad) -> boolean,

	--- If the most right point of `self` is left of the most left point of `other`
	--- @within ElementQuad
	strictlyLeftOf: (self: ElementQuad, other: ElementQuad) -> boolean,

	--- If the most right point of `self` is left or on the same line as the
	--- most left point of `other`
	--- @within ElementQuad
	leftOf: (self: ElementQuad, other: ElementQuad) -> boolean,

	--- If the most left point of `self` is right of the most right point of `other`
	--- @within ElementQuad
	strictlyRightOf: (self: ElementQuad, other: ElementQuad) -> boolean,

	--- If the most left point of `self` is right or on the same line as the
	--- most right point of `other`
	--- @within ElementQuad
	rightOf: (self: ElementQuad, other: ElementQuad) -> boolean,

	--- If `self` is within the left/right boundaries defined by `other`.
	--- @within ElementQuad
	withinHorizontalBoundsOf: (self: ElementQuad, other: ElementQuad) -> boolean,

	--- If `self` is within the top/bottom boundaries defined by `other`.
	--- @within ElementQuad
	withinVerticalBoundsOf: (self: ElementQuad, other: ElementQuad) -> boolean,

	--- If `self` is within the boundaries defined by `other`.
	--- @within ElementQuad
	withinBoundsOf: (self: ElementQuad, other: ElementQuad) -> boolean,
}

--- @class BoxModel
export type BoxModel = {
	content: ElementQuad,
	padding: ElementQuad,
	border: ElementQuad,
	margin: ElementQuad,
	width: number,
	height: number,

	--- Create a `Page.Viewport` equal to the content-box, using a scale of 1.0
	--- @within BoxModel
	contentViewport: (self: BoxModel) -> Page.Viewport,

	--- Create a `Page.Viewport` equal to the padding-box, using a scale of 1.0
	--- @within BoxModel
	paddingViewport: (self: BoxModel) -> Page.Viewport,

	--- Create a `Page.Viewport` equal to the border-box, using a scale of 1.0
	--- @within BoxModel
	borderViewport: (self: BoxModel) -> Page.Viewport,

	--- Create a `Page.Viewport` equal to the margin-box, using a scale of 1.0
	--- @within BoxModel
	marginViewport: (self: BoxModel) -> Page.Viewport,
}

return nil
