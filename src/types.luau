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

export type Browser = {
	transport: Transport.Transport,
	tabs: { Tab },
	getTabs: (self: Browser) -> { Tab },
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
	) -> Tab,
	newTab: (self: Browser) -> Tab,
	newContext: (self: Browser) -> Context,
	registerMissingTabs: (self: Browser) -> (),
	close: (self: Browser) -> (),
}

export type Context = {
	id: string,
	browser: Browser,
	getId: (self: Context) -> string,
	getTabs: (self: Context) -> { Tab },
	newTab: (self: Context) -> Tab,
}

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
	-- TODO: event_listeners
	slowMotionMultiplier: number,
	getTargetId: (self: Tab) -> string,
	updateTargetInfo: (self: Tab, targetInfo: Target.TargetInfo) -> (),
	getUrl: (self: Tab) -> string,
	setDefaultTimeout: (self: Tab, timeout: number) -> Tab,
	setSlowMotionMultiplier: (self: Tab, multiplier: number) -> Tab,
	callMethod: <Request, Response>(
		self: Tab,
		method: string & { __Request: Request, __Response: Response },
		params: Request
	) -> Response,
	addEventListener: <Parameters>(
		self: Tab,
		event: string & { __Parameters: Parameters },
		callback: (params: Parameters) -> ()
	) -> () -> (),
	getTargetInfo: (self: Tab) -> Target.TargetInfo,
	getBrowserContextId: (self: Tab) -> string?,
	setUserAgent: (self: Tab, userAgent: string, acceptLanguage: string?, platform: string?) -> (),
	setExtraHttpHeaders: (self: Tab, headers: { [string]: string }) -> (),
	setFileChooserDialogInterception: (self: Tab, enabled: boolean) -> (),
	handleFileChooser: (self: Tab, files: { string }, nodeId: DOM.NodeId) -> (),
	bringToFront: (self: Tab) -> (),
	reload: (self: Tab, ignoreCache: boolean?, scriptToEvaluateOnLoad: string?) -> Tab,
	stopLoading: (self: Tab) -> (),
	navigateTo: (self: Tab, url: string) -> Tab,
	waitUntilNavigated: (self: Tab) -> Tab,
	waitUntilRedirect: (self: Tab) -> Tab,
	getBounds: (self: Tab) -> Browser.Bounds,
	setBounds: (self: Tab, bounds: Browser.Bounds) -> Tab,
	setTransparentBackgroundColor: (self: Tab) -> Tab,
	setBackgroundColor: (self: Tab, color: DOM.RGBA) -> Tab,
	evaluate: (self: Tab, expression: string, awaitPromise: boolean?) -> Runtime.RemoteObject,
	getTitle: (self: Tab) -> string,
	setCookies: (self: Tab, cookies: { Network.CookieParam }) -> (),
	getCookies: (self: Tab) -> { Network.Cookie },
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
	setStorage: (self: Tab, name: string, item: any) -> (),
	getStorage: (self: Tab, name: string) -> any?,
	removeStorage: (self: Tab, name: string) -> (),
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
	stopScreencast: (self: Tab) -> (),
	ackScreencast: (self: Tab, sessionId: number) -> (),
	getDialog: (self: Tab) -> Dialog.Dialog,
	getDocument: (self: Tab) -> DOM.Node,
	getContent: (self: Tab) -> string,
	describeNode: (self: Tab, nodeId: DOM.NodeId) -> DOM.Node,
	runQuerySelectorOnNode: (self: Tab, nodeId: DOM.NodeId, selector: string) -> Element?,
	runQuerySelectorAllOnNode: (self: Tab, nodeId: DOM.NodeId, selector: string) -> { Element },
	findElement: (self: Tab, selector: string) -> Element?,
	findElementByXPath: (self: Tab, selector: string) -> Element?,
	findElements: (self: Tab, selector: string) -> { Element },
	findElementsByXPath: (self: Tab, selector: string) -> { Element },
	waitForElement: (self: Tab, selector: string, timeout: number?) -> Element,
	waitForXPath: (self: Tab, selector: string, timeout: number?) -> Element,
	waitForElements: (self: Tab, selector: string, timeout: number?) -> { Element },
	waitForElementsByXPath: (self: Tab, selector: string, timeout: number?) -> { Element },
	moveMouseToPoint: (self: Tab, point: Point) -> Tab,
	clickPoint: (self: Tab, point: Point) -> Tab,
	insertText: (self: Tab, text: string) -> Tab,
	typeText: (self: Tab, text: string) -> Tab,
	pressKeyWithModifiers: (self: Tab, key: keys.Key, modifiers: { "Alt" | "Ctrl" | "Meta" | "Shift" }?) -> Tab,
	pressKey: (self: Tab, key: keys.Key) -> Tab,
	enableLog: (self: Tab) -> Tab,
	disableLog: (self: Tab) -> Tab,
	startViolationsReport: (self: Tab, config: { Log.ViolationSetting }) -> Tab,
	stopViolationsReport: (self: Tab) -> Tab,
	enableRuntime: (self: Tab) -> Tab,
	disableRuntime: (self: Tab) -> Tab,
	enableDebugger: (self: Tab) -> Tab,
	disableDebugger: (self: Tab) -> Tab,
	getScriptSource: (self: Tab, scriptId: string) -> string,
	enableProfiler: (self: Tab) -> Tab,
	disableProfiler: (self: Tab) -> Tab,
	startJsCoverage: (self: Tab) -> Tab,
	stopJsCoverage: (self: Tab) -> Tab,
	takeJsCoverage: (self: Tab) -> { Profiler.ScriptCoverage },
	enableFetch: (self: Tab, patterns: { Fetch.RequestPattern }?, handleAuthRequests: boolean?) -> Tab,
	disableFetch: (self: Tab) -> Tab,
	enableRequestInterception: (self: Tab, interceptor: RequestInterceptor) -> (),
	authenticate: (self: Tab, username: string, password: string?) -> Tab,
	enableStealthMode: (self: Tab) -> (),
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

export type Element = {
	remoteObjectId: string,
	backendNodeId: DOM.BackendNodeId,
	nodeId: DOM.NodeId,
	parent: Tab,
	attributes: { string }?,
	tag: string,
	value: string,
	getDescription: (self: Element) -> DOM.Node,
	getAttributes: (self: Element) -> { string }?,
	getAttributeValue: (self: Element, name: string) -> string?,
	getInnerText: (self: Element) -> string,
	getContent: (self: Element) -> string,
	findElement: (self: Element, selector: string) -> Element?,
	findElements: (self: Element, selector: string) -> { Element },
	waitForElement: (self: Element, selector: string, timeout: number?) -> Element,
	waitForElements: (self: Element, selector: string, timeout: number?) -> { Element },
	callJsFunction: (
		self: Element,
		functionDeclaration: string,
		args: { string }?,
		awaitPromise: boolean?
	) -> Runtime.RemoteObject,
	getMidpoint: (self: Element) -> Point,
	getBoxModel: (self: Element) -> BoxModel,
	scrollIntoView: (self: Element) -> Element,
	moveMouseOver: (self: Element) -> Element,
	click: (self: Element) -> Element,
	typeInto: (self: Element, text: string) -> Element,
	focus: (self: Element) -> Element,
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

export type ElementQuad = {
	topLeft: Point,
	topRight: Point,
	bottomRight: Point,
	bottomLeft: Point,
	height: (self: ElementQuad) -> number,
	width: (self: ElementQuad) -> number,
	aspectRatio: (self: ElementQuad) -> number,
	mostLeft: (self: ElementQuad) -> number,
	mostRight: (self: ElementQuad) -> number,
	mostTop: (self: ElementQuad) -> number,
	mostBottom: (self: ElementQuad) -> number,
	strictlyAbove: (self: ElementQuad, other: ElementQuad) -> boolean,
	above: (self: ElementQuad, other: ElementQuad) -> boolean,
	strictlyBelow: (self: ElementQuad, other: ElementQuad) -> boolean,
	below: (self: ElementQuad, other: ElementQuad) -> boolean,
	strictlyLeftOf: (self: ElementQuad, other: ElementQuad) -> boolean,
	leftOf: (self: ElementQuad, other: ElementQuad) -> boolean,
	strictlyRightOf: (self: ElementQuad, other: ElementQuad) -> boolean,
	rightOf: (self: ElementQuad, other: ElementQuad) -> boolean,
	withinHorizontalBoundsOf: (self: ElementQuad, other: ElementQuad) -> boolean,
	withinVerticalBoundsOf: (self: ElementQuad, other: ElementQuad) -> boolean,
	withinBoundsOf: (self: ElementQuad, other: ElementQuad) -> boolean,
}

export type BoxModel = {
	content: ElementQuad,
	padding: ElementQuad,
	border: ElementQuad,
	margin: ElementQuad,
	width: number,
	height: number,
	contentViewport: (self: BoxModel) -> Page.Viewport,
	paddingViewport: (self: BoxModel) -> Page.Viewport,
	borderViewport: (self: BoxModel) -> Page.Viewport,
	marginViewport: (self: BoxModel) -> Page.Viewport,
}

return nil
