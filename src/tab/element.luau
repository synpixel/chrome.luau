local serde = require("@lune/serde")
local ElementQuad = require("./element-quad")
local BoxModel = require("./box-model")
local Wait = require("../utils/wait")
local types = require("./types")
local DOM = require("../protocol/DOM")
local Runtime = require("../protocol/Runtime")
local Page = require("../protocol/Page")

export type Element = types.Element

local DEFAULT_TIMEOUT = 3

local function getDescription(self: Element): DOM.Node
	return self.parent:callMethod(DOM.DescribeNode, { nodeId = self.nodeId, depth = 100 }).node
end

local function getAttributes(self: Element): { string }?
	local description = self:getDescription()
	return description.attributes
end

local function getAttributeValue(self: Element, name: string): string?
	local jsFunction = `function() \{ return this.getAttribute("{name}"); \}`

	local json = self:callJsFunction(jsFunction, nil, true).value
	if json == nil then
		return nil
	end
	return serde.decode("json", json)
end

local function getInnerText(self: Element): string
	local text = self:callJsFunction("function() { return this.innerText }").value
	return text :: string
end

local function getContent(self: Element): string
	local html = self:callJsFunction("function() { return this.outerHTML }").value
	return html :: string
end

local function findElement(self: Element, selector: string): Element?
	return self.parent:runQuerySelectorOnNode(self.nodeId, selector)
end

local function findElements(self: Element, selector: string): { Element }
	return self.parent:runQuerySelectorAllOnNode(self.nodeId, selector)
end

local function waitForElement(self: Element, selector: string, timeout: number?): Element
	local timeout = timeout or DEFAULT_TIMEOUT

	return Wait.withTimeout(timeout):pauseUntil(function()
		local element = self:findElement(selector)
		if element == nil then
			return Wait.None :: any
		end

		return element
	end)
end

local function waitForElements(self: Element, selector: string, timeout: number?): { Element }
	local timeout = timeout or DEFAULT_TIMEOUT

	return Wait.withTimeout(timeout):pauseUntil(function()
		local elements = self:findElements(selector)
		if #elements <= 0 then
			return Wait.None :: any
		end

		return elements
	end)
end

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

local function getMidpoint(self: Element): types.Point
	local quads = self.parent:callMethod(DOM.GetContentQuads, { backendNodeId = self.backendNodeId }).quads

	local rawQuad = quads[1]
	local inputQuad = ElementQuad.fromRawPoints(rawQuad)
	return {
		x = (inputQuad.bottomRight.x + inputQuad.topLeft.x) / 2,
		y = (inputQuad.bottomRight.y + inputQuad.topLeft.y) / 2,
	}
end

local function getBoxModel(self: Element): BoxModel.BoxModel
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

local function moveMouseOver(self: Element): Element
	self:scrollIntoView()
	local midpoint = self:getMidpoint()
	self.parent:moveMouseToPoint(midpoint)
	return self
end

local function click(self: Element): Element
	self:scrollIntoView()
	local midpoint = self:getMidpoint()
	self.parent:clickPoint(midpoint)
	return self
end

local function typeInto(self: Element, text: string): Element
	self:click()
	self.parent:typeText(text)
	return self
end

local function focus(self: Element): Element
	self:scrollIntoView()
	self.parent:callMethod(DOM.Focus, { backendNodeId = self.backendNodeId })
	return self
end

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

local function new(parent: types.Tab, nodeId: DOM.NodeId): Element?
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
