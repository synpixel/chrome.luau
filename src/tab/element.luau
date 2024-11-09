local serde = require("@lune/serde")
local ElementQuad = require("./element-quad")
local BoxModel = require("./box-model")
local Wait = require("../utils/wait")
local types = require("./types")
local DOM = require("../protocol/DOM")
local Runtime = require("../protocol/Runtime")

--[=[
	A handle to a [DOM Element](https://developer.mozilla.org/en-US/docs/Web/API/Element).

	Typically you get access to these by passing `Tab.waitForElement` a CSS selector. Once
	you have a handle to an element, you can click it, type into it, inspect its
	attributes, and more. You can even run a JavaScript function inside the tab which can reference
	the element via `this`.

	@class Element
]=]
export type Element = types.Element

--- @prop remoteObjectId string
--- @within Element

--- @prop backendNodeId DOM.NodeId
--- @within Element

--- @prop nodeId DOM.NodeId
--- @within Element

--- @prop parent Tab
--- @within Element

--- @prop attributes { string }?
--- @within Element

--- @prop tag string
--- @within Element

--- @prop value string
--- @within Element

type Tab = types.Tab
type BoxModel = BoxModel.BoxModel

local DEFAULT_TIMEOUT = 3

local function extractMidpoint(remoteObject: Runtime.RemoteObject): types.Point
	if remoteObject.preview == nil then
		return { x = 0, y = 0 }
	end

	local props = {}

	for _, property in remoteObject.preview.properties do
		props[property.name] = tonumber(property.value) :: number
	end

	return {
		x = props.x + props.width / 2,
		y = props.y + props.height / 2,
	}
end

--- @within Element
local function getDescription(self: Element): DOM.Node
	return self.parent:callMethod(DOM.DescribeNode, { nodeId = self.nodeId, depth = 100 }).node
end

--- @within Element
local function getAttributes(self: Element): { string }?
	local description = self:getDescription()
	return description.attributes
end

--- @within Element
local function getAttributeValue(self: Element, name: string): string?
	local jsFunction = `function() \{ return this.getAttribute("{name}"); \}`

	local json = self:callJsFunction(jsFunction, nil, true).value
	if json == nil then
		return nil
	end
	return serde.decode("json", json)
end

--[=[
	Returns the inner text of an HTML Element. Returns an empty string on elements with no text.

	Note: .innerText and .textContent are not the same thing. See:
	<https://developer.mozilla.org/en-US/docs/Web/API/HTMLElement/innerText>

	Note: if you somehow call this on a node that's not an HTML Element (e.g. `document`), this
	will fail.

	@within Element
]=]
local function getInnerText(self: Element): string
	local text = self:callJsFunction("function() { return this.innerText }").value
	return text :: string
end

--- Get the full HTML contents of the element.
--- Equivalent to the following JS: ```element.outerHTML```.
--- @within Element
local function getContent(self: Element): string
	local html = self:callJsFunction("function() { return this.outerHTML }").value
	return html :: string
end

--- @within Element
local function findElement(self: Element, selector: string): Element?
	return self.parent:runQuerySelectorOnNode(self.nodeId, selector)
end

--- @within Element
local function findElements(self: Element, selector: string): { Element }
	return self.parent:runQuerySelectorAllOnNode(self.nodeId, selector)
end

--- @within Element
local function waitForElement(self: Element, selector: string, timeout: number?): Element
	local timeout = timeout or DEFAULT_TIMEOUT

	return Wait.withTimeout(timeout):pauseUntil(function()
		local element = self:findElement(selector)
		if element == nil then
			return Wait.None
		end

		return element
	end)
end

--- @within Element
local function waitForElements(self: Element, selector: string, timeout: number?): { Element }
	local timeout = timeout or DEFAULT_TIMEOUT

	return Wait.withTimeout(timeout):pauseUntil(function()
		local elements = self:findElements(selector)
		if #elements <= 0 then
			return Wait.None
		end

		return elements
	end)
end

--- @within Element
local function callJsFunction(
	self: Element,
	functionDeclaration: string,
	args: { string }?,
	awaitPromise: boolean?
): Runtime.RemoteObject
	local callArgs: { Runtime.CallArgument }

	if args ~= nil then
		callArgs = {}
		for index, arg in args do
			callArgs[index] = { value = arg }
		end
	end

	return self.parent:callMethod(Runtime.CallFunctionOn, {
		objectId = self.remoteObjectId,
		functionDeclaration = functionDeclaration,
		arguments = callArgs,
		returnByValue = false,
		generatePreview = true,
		silent = false,
		awaitPromise = awaitPromise,
	}).result
end

--- @within Element
local function getMidpoint(self: Element): types.Point
	local quads = self.parent:callMethod(DOM.GetContentQuads, { backendNodeId = self.backendNodeId }).quads

	local rawQuad = quads[1]
	if rawQuad ~= nil then
		local inputQuad = ElementQuad.fromRawPoints(rawQuad)
		return {
			x = (inputQuad.bottomRight.x + inputQuad.topLeft.x) / 2,
			y = (inputQuad.bottomRight.y + inputQuad.topLeft.y) / 2,
		}
	end

	return Wait.withTimeout(20):pauseUntil(function()
		local result = self:callJsFunction([[
			function() {
                let rect = this.getBoundingClientRect();

                if(rect.x != 0) {
                    this.scrollIntoView();
                }

                return this.getBoundingClientRect();
            }
		]])

		local midpoint = extractMidpoint(result)
		if midpoint.x == 0 then
			return Wait.None
		end

		return midpoint
	end)
end

--- Get boxes for this element
--- @within Element
local function getBoxModel(self: Element): BoxModel
	local model = self.parent:callMethod(DOM.GetBoxModel, { backendNodeId = self.backendNodeId }).model
	return BoxModel.new({
		content = ElementQuad.fromRawPoints(model.content),
		padding = ElementQuad.fromRawPoints(model.padding),
		border = ElementQuad.fromRawPoints(model.border),
		margin = ElementQuad.fromRawPoints(model.margin),
		width = model.width,
		height = model.height,
	})
end

--- Scrolls the current element into view
--- Used prior to any action applied to the current element to ensure action is duable.
--- @within Element
local function scrollIntoView(self: Element): Element
	local result = self:callJsFunction(
		[[
			async function() {
            	if (!this.isConnected) return "Node is detached from document";
            	if (this.nodeType !== Node.ELEMENT_NODE) return "Node is not of type HTMLElement";

            	const visibleRatio = await new Promise(resolve => {
                	const observer = new IntersectionObserver(entries => {
                    	resolve(entries[0].intersectionRatio);
                    	observer.disconnect();
                	});
                	observer.observe(this);
            	});

            	if (visibleRatio !== 1.0)
                	this.scrollIntoView({
                    	block: "center",
                    	inline: "center",
                    	behavior: "instant",
                	});
			
            	return false;
        	}
	]],
		nil,
		true
	)

	if result.type == "string" then
		error(result.value)
	end

	return self
end

--- Moves the mouse to the middle of this element
--- @within Element
local function moveMouseOver(self: Element): Element
	self:scrollIntoView()
	local midpoint = self:getMidpoint()
	self.parent:moveMouseToPoint(midpoint)
	return self
end

--- @within Element
local function click(self: Element): Element
	self:scrollIntoView()
	local midpoint = self:getMidpoint()
	self.parent:clickPoint(midpoint)
	return self
end

--- @within Element
local function typeInto(self: Element, text: string): Element
	self:click()
	self.parent:typeText(text)
	return self
end

--- @within Element
local function focus(self: Element): Element
	self:scrollIntoView()
	self.parent:callMethod(DOM.Focus, { backendNodeId = self.backendNodeId })
	return self
end

--- Capture a screenshot of this element.
--- The screenshot is taken from the surface using this element's content-box.
--- @within Element
local function captureScreenshot(
	self: Element,
	options: {
		format: "jpeg" | "png" | "webp"?,
		quality: number?,
		fromSurface: boolean?,
		optimizeForSpeed: boolean?,
	}
): buffer
	self:scrollIntoView()
	return self.parent:captureScreenshot({
		format = options.format,
		quality = options.quality,
		clip = self:getBoxModel():contentViewport(),
		fromSurface = options.fromSurface,
		optimizeForSpeed = options.optimizeForSpeed,
	})
end

--- Using a "nodeId", of the type returned by QuerySelector and QuerySelectorAll, this finds
--- the "backendNodeId" and "remoteObjectId" which are stable identifiers, unlike nodeId.
--- We use these two when making various calls to the API because of that.
--- @within Element
local function new(parent: Tab, nodeId: DOM.NodeId): Element?
	if nodeId == 0 then
		return nil
	end

	local node = parent:callMethod(DOM.DescribeNode, { nodeId = nodeId, depth = 100 }).node

	local attributes = node.attributes
	local tag = node.nodeName

	local backendNodeId = node.backendNodeId

	local object = parent:callMethod(DOM.ResolveNode, { backendNodeId = backendNodeId }).object

	local value = tostring(object.value)
	local remoteObjectId = assert(object.objectId, "Couldn't find object ID")

	return {
		remoteObjectId = remoteObjectId,
		backendNodeId = backendNodeId,
		nodeId = nodeId,
		parent = parent,
		attributes = attributes,
		tag = tag,
		value = value,
		getDescription = getDescription,
		getAttributes = getAttributes,
		getAttributeValue = getAttributeValue,
		getInnerText = getInnerText,
		getContent = getContent,
		findElement = findElement,
		findElements = findElements,
		waitForElement = waitForElement,
		waitForElements = waitForElements,
		callJsFunction = callJsFunction,
		getMidpoint = getMidpoint,
		getBoxModel = getBoxModel,
		scrollIntoView = scrollIntoView,
		moveMouseOver = moveMouseOver,
		click = click,
		typeInto = typeInto,
		focus = focus,
		captureScreenshot = captureScreenshot,
	}
end

return { new = new }
