local ElementQuad = require("./element-quad")
local BoxModel = require("./box-model")
local Wait = require("../utils/wait")
local types = require("../types")
local DOM = require("../protocol/dom")
local Runtime = require("../protocol/runtime")

export type Element = types.Element

local DEFAULT_TIMEOUT = 3

local new: (parent: types.Tab, node_id: DOM.NodeId) -> Element?

local function extract_midpoint(remote_object: Runtime.RemoteObject): { x: number, y: number }
	if remote_object.preview == nil then
		return { x = 0, y = 0 }
	end

	local props = {}

	for _, property in remote_object.preview.properties do
		props[property.name] = tonumber(property.value) :: number
	end

	return {
		x = props.x + props.width / 2,
		y = props.y + props.height / 2,
	}
end

local function get_description(self: Element): DOM.Node
	return self.parent:call_method(DOM.DescribeNode, { node_id = self.node_id, depth = 100 }).node
end

local function get_attributes(self: Element): { string }?
	local description = self:get_description()
	return description.attributes
end

local function get_attribute_value(self: Element, name: string): string?
	local js_function = `function() \{ return this.getAttribute("{name}"); \}`

	local value = self:call_js_function(js_function, nil, true).value
	if value == nil then
		return nil
	end

	return value :: string
end

local function get_inner_text(self: Element): string
	local text = self:call_js_function("function() { return this.innerText }").value
	return text :: string
end

local function get_content(self: Element): string
	local html = self:call_js_function("function() { return this.outerHTML }").value
	return html :: string
end

local function find_element(self: Element, selector: string): Element?
	return self.parent:run_query_selector_on_node(self.node_id, selector)
end

local function find_element_by_xpath(self: Element, query: string): Element?
	self.parent:get_document()

	local search = self.parent:call_method(DOM.PerformSearch, { query = query, include_user_agent_shadow_dom = true })
	if search.result_count <= 0 then
		return nil
	end

	local results = self.parent:call_method(DOM.GetSearchResults, {
		search_id = search.search_id,
		from_index = 0,
		to_index = search.result_count,
	})

	local node_id = results.node_ids[1]
	return new(self.parent, node_id)
end

local function find_elements(self: Element, selector: string): { Element }
	return self.parent:run_query_selector_all_on_node(self.node_id, selector)
end

local function find_elements_by_xpath(self: Element, query: string): { Element }
	self.parent:get_document()

	local search = self.parent:call_method(DOM.PerformSearch, { query = query, include_user_agent_shadow_dom = true })
	if search.result_count <= 0 then
		return {}
	end

	local results = self.parent:call_method(DOM.GetSearchResults, {
		search_id = search.search_id,
		from_index = 0,
		to_index = search.result_count,
	})

	local node_ids = results.node_ids
	local elements = {}

	for _, node_id in node_ids do
		local element = new(self.parent, node_id)
		if element == nil then
			continue
		end

		table.insert(elements, element)
	end

	return elements
end

local function wait_for_element(self: Element, selector: string, timeout: number?): Element?
	local timeout = timeout or DEFAULT_TIMEOUT
	return Wait.with_timeout(timeout):pause_until(function()
		return self:find_element(selector)
	end)
end

local function wait_for_xpath(self: Element, selector: string, timeout: number?): Element?
	local timeout = timeout or DEFAULT_TIMEOUT
	return Wait.with_timeout(timeout):pause_until(function()
		return self:find_element_by_xpath(selector)
	end)
end

local function wait_for_elements(self: Element, selector: string, timeout: number?): { Element }
	local timeout = timeout or DEFAULT_TIMEOUT
	return Wait.with_timeout(timeout):pause_until(function()
		local elements = self:find_elements(selector)
		return #elements > 0 and elements
	end) or {}
end

local function wait_for_elements_by_xpath(self: Element, selector: string, timeout: number?): { Element }
	local timeout = timeout or DEFAULT_TIMEOUT
	return Wait.with_timeout(timeout):pause_until(function()
		local elements = self:find_elements_by_xpath(selector)
		return #elements > 0 and elements
	end) or {}
end

local function call_js_function(
	self: Element,
	function_declaration: string,
	args: { string }?,
	await_promise: boolean?
): Runtime.RemoteObject
	local call_args: { Runtime.CallArgument }

	if args ~= nil then
		call_args = {}
		for index, arg in args do
			call_args[index] = { value = arg }
		end
	end

	return self.parent:call_method(Runtime.CallFunctionOn, {
		object_id = self.remote_object_id,
		function_declaration = function_declaration,
		arguments = call_args,
		return_by_value = false,
		generate_preview = true,
		silent = false,
		await_promise = await_promise,
	}).result
end

local function get_midpoint(self: Element): types.Point
	local quads = self.parent:call_method(DOM.GetContentQuads, { backend_node_id = self.backend_node_id }).quads

	local raw_quad = quads[1]
	if raw_quad ~= nil then
		local input_quad = ElementQuad.from_raw_points(raw_quad)
		return {
			x = (input_quad.bottom_right.x + input_quad.top_left.x) / 2,
			y = (input_quad.bottom_right.y + input_quad.top_left.y) / 2,
		}
	end

	local midpoint = Wait.with_timeout(20):pause_until(function()
		local result = self:call_js_function([[
			function() {
                let rect = this.getBoundingClientRect();

                if(rect.x != 0) {
                    this.scrollIntoView();
                }

                return this.getBoundingClientRect();
            }
		]])

		local midpoint = extract_midpoint(result)
		if midpoint.x == 0 then
			return nil
		end

		return midpoint
	end)

	assert(midpoint, "Failed to get element midpoint")
	return midpoint
end

local function get_box_model(self: Element): BoxModel.BoxModel
	local model = self.parent:call_method(DOM.GetBoxModel, { backend_node_id = self.backend_node_id }).model
	return BoxModel.new({
		content = ElementQuad.from_raw_points(model.content),
		padding = ElementQuad.from_raw_points(model.padding),
		border = ElementQuad.from_raw_points(model.border),
		margin = ElementQuad.from_raw_points(model.margin),
		width = model.width,
		height = model.height,
	})
end

local function scroll_into_view(self: Element): Element
	local result = self:call_js_function(
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

local function move_mouse_over(self: Element): Element
	self:scroll_into_view()
	local midpoint = self:get_midpoint()
	self.parent:move_mouse_to_point(midpoint)
	return self
end

local function click(self: Element): Element
	self:scroll_into_view()
	local midpoint = self:get_midpoint()
	self.parent:click_point(midpoint)
	return self
end

local function type_into(self: Element, text: string): Element
	self:click()
	self.parent:type_text(text)
	return self
end

local function focus(self: Element): Element
	self:scroll_into_view()
	self.parent:call_method(DOM.Focus, { backend_node_id = self.backend_node_id })
	return self
end

local function capture_screenshot(
	self: Element,
	options: {
		format: "jpeg" | "png" | "webp"?,
		quality: number?,
		from_surface: boolean?,
		optimize_for_speed: boolean?,
	}
): buffer
	self:scroll_into_view()
	return self.parent:capture_screenshot({
		format = options.format,
		quality = options.quality,
		clip = self:get_box_model():content_viewport(),
		from_surface = options.from_surface,
		optimize_for_speed = options.optimize_for_speed,
	})
end

--- Using a "node_id", of the type returned by QuerySelector and QuerySelectorAll, this finds
--- the "backend_node_id" and "remote_object_id" which are stable identifiers, unlike node_id.
--- We use these two when making various calls to the API because of that.
--- @within Element
function new(parent: types.Tab, node_id: DOM.NodeId): Element?
	if node_id == 0 then
		return nil
	end

	local node = parent:call_method(DOM.DescribeNode, { node_id = node_id, depth = 100 }).node

	local attributes = node.attributes
	local tag = node.node_name

	local backend_node_id = node.backend_node_id

	local object = parent:call_method(DOM.ResolveNode, { backend_node_id = backend_node_id }).object

	local value = tostring(object.value)
	local remote_object_id = assert(object.object_id, "Couldn't find object ID")

	return {
		remote_object_id = remote_object_id,
		backend_node_id = backend_node_id,
		node_id = node_id,
		parent = parent,
		attributes = attributes,
		tag = tag,
		value = value,
		get_description = get_description,
		get_attributes = get_attributes,
		get_attribute_value = get_attribute_value,
		get_inner_text = get_inner_text,
		get_content = get_content,
		find_element = find_element,
		find_element_by_xpath = find_element_by_xpath,
		find_elements = find_elements,
		find_elements_by_xpath = find_elements_by_xpath,
		wait_for_element = wait_for_element,
		wait_for_xpath = wait_for_xpath,
		wait_for_elements = wait_for_elements,
		wait_for_elements_by_xpath = wait_for_elements_by_xpath,
		call_js_function = call_js_function,
		get_midpoint = get_midpoint,
		get_box_model = get_box_model,
		scroll_into_view = scroll_into_view,
		move_mouse_over = move_mouse_over,
		click = click,
		type_into = type_into,
		focus = focus,
		capture_screenshot = capture_screenshot,
	}
end

return { new = new }
