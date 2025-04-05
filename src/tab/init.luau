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
local base64 = require("../../luau_packages/base64")
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

local function get_target_id(self: Tab): string
	return self.target_id
end

local function update_target_info(self: Tab, target_info: Target.TargetInfo)
	self.target_info = target_info
end

local function get_url(self: Tab): string
	return self.target_info.url
end

local function set_default_timeout(self: Tab, timeout: number): Tab
	self.default_timeout = timeout
	return self
end

local function set_slow_motion_multiplier(self: Tab, multiplier: number): Tab
	self.slow_motion_multiplier = multiplier
	return self
end

local function optional_slow_motion_sleep(self: Tab, millis: number)
	if self.slow_motion_multiplier == 0 then
		return
	end

	local seconds = millis / 1000
	task.wait(seconds * self.slow_motion_multiplier)
end

local function call_method<Request, Response>(
	self: Tab,
	method: string & { __Request: Request, __Response: Response },
	parameters: Request
): Response
	return self.transport:call_method_on_target(method, parameters, self.session_id)
end

local function add_event_listener<Parameters>(
	self: Tab,
	event: string & { __Parameters: Parameters },
	callback: (params: Parameters) -> ()
): () -> ()
	return self.transport:listen_to_target_event(event, self.session_id, callback)
end

local function get_target_info(self: Tab): Target.TargetInfo
	return self.transport:call_method_on_browser(Target.GetTargetInfo, { target_id = self.target_id }).target_info
end

local function get_browser_context_id(self: Tab): string?
	local target_info = self:get_target_info()
	return target_info.browser_context_id
end

local function set_user_agent(self: Tab, user_agent: string, accept_language: string?, platform: string?)
	self:call_method(
		Network.SetUserAgentOverride,
		{ user_agent = user_agent, accept_language = accept_language, platform = platform }
	)
end

local function set_extra_http_headers(self: Tab, headers: { [string]: string })
	self:call_method(Network.Enable, {})
	self:call_method(Network.SetExtraHTTPHeaders, { headers = headers })
end

local function set_file_chooser_dialog_interception(self: Tab, enabled: boolean)
	self:call_method(Page.SetInterceptFileChooserDialog, { enabled = enabled })
end

local function handle_file_chooser(self: Tab, files: { string }, node_id: DOM.NodeId)
	self:call_method(DOM.SetFileInputFiles, { files = files, node_id = node_id })
end

local function bring_to_front(self: Tab)
	self:call_method(Page.BringToFront)
end

local function reload(self: Tab, ignore_cache: boolean?, script_to_evaluate_on_load: string?): Tab
	optional_slow_motion_sleep(self, 100)
	self:call_method(
		Page.Reload,
		{ ignore_cache = ignore_cache, script_to_evaluate_on_load = script_to_evaluate_on_load }
	)
	return self
end

local function stop_loading(self: Tab)
	self:call_method(Page.StopLoading)
end

local function navigate_to(self: Tab, url: string): Tab
	self:call_method(Page.Navigate, { url = url })
	self.navigating = true

	return self
end

local function wait_until_navigated(self: Tab): Tab
	local success = Wait.with_timeout(self.default_timeout):pause_until(function()
		return if self.navigating then nil else true
	end) or false

	assert(success, "Tab never finished navigating")
	return self
end

local function wait_for_redirect(self: Tab): Tab
	self.navigating = true
	return self:wait_until_navigated()
end

local function get_bounds(self: Tab): Browser.Bounds
	return self.transport:call_method_on_browser(Browser.GetWindowForTarget, { target_id = self.target_id }).bounds
end

local function set_bounds(self: Tab, bounds: Browser.Bounds): Tab
	local window_id =
		self.transport:call_method_on_browser(Browser.GetWindowForTarget, { target_id = self.target_id }).window_id

	self.transport:call_method_on_browser(Browser.SetWindowBounds, { window_id = window_id, bounds = bounds })

	return self
end

local function set_transparent_background_color(self: Tab): Tab
	self:call_method(Emulation.SetDefaultBackgroundColorOverride, {
		color = { r = 0, g = 0, b = 0, a = 0 },
	})
	return self
end

local function set_background_color(self: Tab, color: DOM.RGBA): Tab
	self:call_method(Emulation.SetDefaultBackgroundColorOverride, { color = color })
	return self
end

local function evaluate(self: Tab, expression: string, await_promise: boolean?): Runtime.RemoteObject
	return self:call_method(Runtime.Evaluate, {
		expression = expression,
		return_by_value = false,
		generate_preview = true,
		silent = false,
		await_promise = await_promise,
		include_command_line_api = false,
		user_gesture = false,
	}).result
end

local function get_title(self: Tab): string
	local result = self:evaluate("document.title")
	return result.value :: string
end

local function set_cookies(self: Tab, cookies: { Network.CookieParam })
	local url = self:get_url()
	local starts_with_http = url:sub(1, 4) == "http"

	local patched_cookies = {}

	for index, cookie in cookies do
		if cookie.url == nil and starts_with_http then
			cookie = table.clone(cookie)
			cookie.url = url
		end

		patched_cookies[index] = cookie
	end

	self:delete_cookies(patched_cookies :: any)
	self:call_method(Network.SetCookies, { cookies = patched_cookies })
end

local function get_cookies(self: Tab): { Network.Cookie }
	return self:call_method(Network.GetCookies, {}).cookies
end

local function delete_cookies(
	self: Tab,
	cookies: {
		{
			name: string,
			url: string?,
			domain: string?,
			path: string?,
			partition_key: Network.CookiePartitionKey?,
		}
	}
)
	local url = self:get_url()
	local starts_with_http = url:sub(1, 4) == "http"

	for _, cookie in cookies do
		if cookie.url == nil and starts_with_http then
			cookie = table.clone(cookie)
			cookie.url = url
		end

		self:call_method(Network.DeleteCookies, cookie)
	end
end

local function set_storage(self: Tab, name: string, item: any)
	local json = serde.encode("json", item)
	local value = if typeof(item) == "string" then json else `JSON.stringify({json})`
	self:evaluate(`localStorage.setItem("{name}", {value})`)
end

local function get_storage(self: Tab, name: string): any?
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

local function remove_storage(self: Tab, name: string)
	self:evaluate(`localStorage.removeItem("{name}")`)
end

local function capture_screenshot(
	self: Tab,
	options: {
		format: "jpeg" | "png" | "webp"?,
		quality: number?,
		clip: Page.Viewport?,
		from_surface: boolean?,
		capture_beyond_viewport: boolean?,
		optimize_for_speed: boolean?,
	}
): buffer
	local screenshot = self:call_method(Page.CaptureScreenshot, options)
	local data = buffer.fromstring(screenshot.data)
	return base64.decode(data)
end

local function print_to_pdf(
	self: Tab,
	options: {
		landscape: boolean?,
		display_header_footer: boolean?,
		print_background: boolean?,
		scale: number?,
		paper_width: number?,
		paper_height: number?,
		margin_top: number?,
		margin_bottom: number?,
		margin_left: number?,
		margin_right: number?,
		page_ranges: string?,
		header_template: string?,
		footer_template: string?,
		prefer_csspage_size: boolean?,
		generate_tagged_pdf: boolean?,
		generate_document_outline: boolean?,
	}?
): buffer
	local pdf = self:call_method(Page.PrintToPDF, options :: any or {})
	local data = buffer.fromstring(pdf.data)
	return base64.decode(data)
end

local function start_screencast(
	self: Tab,
	options: {
		format: "jpeg" | "png"?,
		quality: number?,
		max_width: number?,
		max_height: number?,
		every_nth_frame: number?,
	}
)
	self:call_method(Page.StartScreencast, options)
end

local function stop_screencast(self: Tab)
	self:call_method(Page.StopScreencast)
end

local function ack_screencast(self: Tab, session_id: number)
	self:call_method(Page.ScreencastFrameAck, { session_id = session_id })
end

local function get_dialog(self: Tab): Dialog.Dialog
	return Dialog.new(self.session_id, self.transport)
end

local function get_document(self: Tab): DOM.Node
	return self:call_method(DOM.GetDocument, { depth = 0, pierce = false }).root
end

local function get_content(self: Tab): string
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

local function describe_node(self: Tab, node_id: DOM.NodeId): DOM.Node
	return self:call_method(DOM.DescribeNode, { node_id = node_id, depth = 100 }).node
end

local function run_query_selector_on_node(self: Tab, node_id: DOM.NodeId, selector: string): Element?
	local node_id = self:call_method(DOM.QuerySelector, { node_id = node_id, selector = selector }).node_id
	return Element.new(self, node_id)
end

local function run_query_selector_all_on_node(self: Tab, node_id: DOM.NodeId, selector: string): { Element }
	local node_ids = self:call_method(DOM.QuerySelectorAll, { node_id = node_id, selector = selector }).node_ids

	local elements = {}

	for _, node_id in node_ids do
		local element = Element.new(self, node_id)
		if element == nil then
			continue
		end

		table.insert(elements, element)
	end

	return elements
end

local function find_element(self: Tab, selector: string): Element?
	local root_node_id = self:get_document().node_id
	return self:run_query_selector_on_node(root_node_id, selector)
end

local function find_element_by_xpath(self: Tab, query: string): Element?
	self:get_document()

	local search = self:call_method(DOM.PerformSearch, { query = query })
	if search.result_count <= 0 then
		return nil
	end

	local results = self:call_method(DOM.GetSearchResults, {
		search_id = search.search_id,
		from_index = 0,
		to_index = search.result_count,
	})

	local node_id = results.node_ids[1]
	return Element.new(self, node_id)
end

local function find_elements(self: Tab, selector: string): { Element }
	local root_node_id = self:get_document().node_id
	return self:run_query_selector_all_on_node(root_node_id, selector)
end

local function find_elements_by_xpath(self: Tab, query: string): { Element }
	self:get_document()

	local search = self:call_method(DOM.PerformSearch, { query = query })
	if search.result_count <= 0 then
		return {}
	end

	local results = self:call_method(DOM.GetSearchResults, {
		search_id = search.search_id,
		from_index = 0,
		to_index = search.result_count,
	})

	local node_ids = results.node_ids
	local elements = {}

	for _, node_id in node_ids do
		local element = Element.new(self, node_id)
		if element == nil then
			continue
		end

		table.insert(elements, element)
	end

	return elements
end

local function wait_for_element(self: Tab, selector: string, timeout: number?): Element?
	local timeout = timeout or self.default_timeout

	return Wait.with_timeout(timeout):pause_until(function()
		return self:find_element(selector)
	end)
end

local function wait_for_xpath(self: Tab, selector: string, timeout: number?): Element?
	local timeout = timeout or self.default_timeout

	return Wait.with_timeout(timeout):pause_until(function()
		return self:find_element_by_xpath(selector)
	end)
end

local function wait_for_elements(self: Tab, selector: string, timeout: number?): { Element }
	local timeout = timeout or self.default_timeout

	return Wait.with_timeout(timeout):pause_until(function()
		local elements = self:find_elements(selector)
		return #elements > 0 and elements
	end) or {}
end

local function wait_for_elements_by_xpath(self: Tab, selector: string, timeout: number?): { Element }
	local timeout = timeout or self.default_timeout

	return Wait.with_timeout(timeout):pause_until(function()
		local elements = self:find_elements_by_xpath(selector)
		return #elements > 0 and elements
	end) or {}
end

local function move_mouse_to_point(self: Tab, point: types.Point): Tab
	optional_slow_motion_sleep(self, 100)

	self:call_method(Input.DispatchMouseEvent, {
		type = "mouseMoved",
		x = point.x,
		y = point.y,
	})

	return self
end

local function click_point(self: Tab, point: types.Point): Tab
	self:move_mouse_to_point(point)

	optional_slow_motion_sleep(self, 250)

	self:call_method(Input.DispatchMouseEvent, {
		type = "mousePressed",
		x = point.x,
		y = point.y,
		button = "left",
		click_count = 1,
	})

	self:call_method(Input.DispatchMouseEvent, {
		type = "mouseReleased",
		x = point.x,
		y = point.y,
		button = "left",
		click_count = 1,
	})

	return self
end

local function insert_text(self: Tab, text: string): Tab
	self:call_method(Input.InsertText, { text = text })
	return self
end

local function type_text(self: Tab, text: string): Tab
	for _, char in text:split("") do
		local definition = keys.get_key_definition(char :: keys.Key)
		if definition ~= nil then
			self:press_key(definition.key)
		else
			self:insert_text(char)
		end
	end

	return self
end

local function press_key_with_modifiers(
	self: Tab,
	key: keys.Key,
	modifiers: { "Alt" | "Ctrl" | "Meta" | "Shift" }?
): Tab
	local definition = keys.get_key_definition(key)
	assert(definition ~= nil, "Invalid key")

	local text = if definition.text ~= nil then definition.text elseif #definition.key == 1 then definition.key else nil
	local key_down_event: "char" | "keyDown" | "keyUp" | "rawKeyDown" = if text ~= nil then "keyDown" else "rawKeyDown"

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

	optional_slow_motion_sleep(self, 25)

	self:call_method(Input.DispatchKeyEvent, {
		type = key_down_event,
		key = definition.key,
		text = text,
		code = definition.code,
		windows_virtual_key_code = definition.key_code,
		native_virtual_key_code = definition.key_code,
		modifiers = mods,
	})

	self:call_method(Input.DispatchKeyEvent, {
		type = "keyUp",
		key = definition.key,
		text = text,
		code = definition.code,
		windows_virtual_key_code = definition.key_code,
		native_virtual_key_code = definition.key_code,
		modifiers = mods,
	})

	return self
end

local function press_key(self: Tab, key: keys.Key): Tab
	return self:press_key_with_modifiers(key)
end

local function enable_log(self: Tab): Tab
	self:call_method(Log.Enable)
	return self
end

local function disable_log(self: Tab): Tab
	self:call_method(Log.Disable)
	return self
end

local function start_violations_report(self: Tab, config: { Log.ViolationSetting }): Tab
	self:call_method(Log.StartViolationsReport, { config = config })
	return self
end

local function stop_violations_report(self: Tab): Tab
	self:call_method(Log.StopViolationsReport)
	return self
end

local function enable_runtime(self: Tab): Tab
	self:call_method(Runtime.Enable)
	return self
end

local function disable_runtime(self: Tab): Tab
	self:call_method(Runtime.Disable)
	return self
end

local function enable_debugger(self: Tab): Tab
	self:call_method(Debugger.Enable, {})
	return self
end

local function disable_debugger(self: Tab): Tab
	self:call_method(Debugger.Disable)
	return self
end

local function get_script_source(self: Tab, script_id: string): string
	return self:call_method(Debugger.GetScriptSource, { script_id = script_id }).script_source
end

local function enable_profiler(self: Tab): Tab
	self:call_method(Profiler.Enable)
	return self
end

local function disable_profiler(self: Tab): Tab
	self:call_method(Profiler.Disable)
	return self
end

local function start_js_coverage(self: Tab): Tab
	self:call_method(Profiler.StartPreciseCoverage, { call_count = true, detailed = true })
	return self
end

local function stop_js_coverage(self: Tab): Tab
	self:call_method(Profiler.StopPreciseCoverage)
	return self
end

local function take_js_coverage(self: Tab): { Profiler.ScriptCoverage }
	return self:call_method(Profiler.TakePreciseCoverage).result
end

local function enable_fetch(self: Tab, patterns: { Fetch.RequestPattern }?, handle_auth_requests: boolean?): Tab
	self:call_method(Fetch.Enable, { patterns = patterns, handle_auth_requests = handle_auth_requests })
	return self
end

local function disable_fetch(self: Tab): Tab
	self:call_method(Fetch.Disable)
	return self
end

local function enable_request_interception(self: Tab, interceptor: types.RequestInterceptor)
	self.request_interceptor = interceptor
end

local function authenticate(self: Tab, username: string?, password: string?): Tab
	self.auth_handler = {
		response = "ProvideCredentials",
		username = username,
		password = password,
	}
	return self
end

local function expose_function(self: Tab, name: string, fn: (data: any) -> ())
	self.page_bindings[name] = fn

	local expression = [[
		(function addPageBinding(bindingName) {
            const binding = window[bindingName];
            window[bindingName] = (...args) => {
              const me = window[bindingName];
              let callbacks = me.callbacks;
              if (!callbacks) {
                callbacks = new Map();
                me.callbacks = callbacks;
              }
              const seq = (me.lastSeq || 0) + 1;
              me.lastSeq = seq;
              const promise = new Promise((resolve, reject) => callbacks.set(seq, {resolve, reject}));
              binding(JSON.stringify({ name: bindingName, seq, args }));
              return promise;
            };
    	})()
	]] -- https://github.com/puppeteer/puppeteer/blob/97c9fe2520723d45a5a86da06b888ae888d400be/src/common/helper.ts#L183

	self:call_method(Runtime.AddBinding, { name = name })
	self:call_method(Page.AddScriptToEvaluateOnNewDocument, { source = expression })
end

local function remove_function(self: Tab, name: string)
	self.page_bindings[name] = nil
end

local function bypass_user_agent(self: Tab)
	local object = self:evaluate("window.navigator.userAgent", true)
	local user_agent = object.value :: string?

	if user_agent == nil then
		return
	end

	user_agent = user_agent:gsub("HeadlessChrome/", "Chrome/")

	local regex = Regex.new([[\(([^)]+)\)]])
	user_agent = regex:replace(user_agent, "(Windows NT 10.0; Win64; x64)")

	self:set_user_agent(user_agent)
end

local function bypass_web_driver(self: Tab)
	self:call_method(Page.AddScriptToEvaluateOnNewDocument, {
		source = 'Object.defineProperty(navigator, "webdriver", { get: () => undefined });',
	})
end

local function bypass_chrome(self: Tab)
	self:call_method(Page.AddScriptToEvaluateOnNewDocument, {
		source = "window.chrome = { runtime: {} };",
	})
end

local function bypass_permissions(self: Tab)
	local source = [[
		const originalQuery = window.navigator.permissions.query;
        window.navigator.permissions.__proto__.query = (parameters) =>
        parameters.name === "notifications"
            ? Promise.resolve({state: Notification.permission})
            : originalQuery(parameters);
	]]

	self:call_method(Page.AddScriptToEvaluateOnNewDocument, {
		source = source,
	})
end

local function bypass_plugins(self: Tab)
	local source = [[
		Object.defineProperty(navigator, "plugins", {
			get: () => [
            	{ filename: "internal-pdf-viewer" },
            	{ filename: "adsfkjlkjhalkh" },
            	{ filename: "internal-nacl-plugin" },
          	],
		});
	]]

	self:call_method(Page.AddScriptToEvaluateOnNewDocument, {
		source = source,
	})
end

local function bypass_webgl_vendor(self: Tab)
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

	self:call_method(Page.AddScriptToEvaluateOnNewDocument, {
		source = source,
	})
end

local function enable_stealth_mode(self: Tab)
	bypass_user_agent(self)
	bypass_web_driver(self)
	bypass_chrome(self)
	bypass_permissions(self)
	bypass_plugins(self)
	bypass_webgl_vendor(self)
end

local function close(self: Tab)
	optional_slow_motion_sleep(self, 50)
	self:call_method(Target.CloseTarget, { target_id = self.target_id })
end

local function handle_tab_level_events(self: Tab)
	self:add_event_listener(Page.LifecycleEvent, function(event)
		if event.name == "networkAlmostIdle" then
			self.navigating = false
		elseif event.name == "init" then
			self.navigating = true
		end
	end)

	self:add_event_listener(Runtime.BindingCalled, function(binding)
		local name = binding.name
		local payload = binding.payload

		local fn = self.page_bindings[name]
		fn(serde.decode("json", payload))
	end)

	self:add_event_listener(Fetch.RequestPaused, function(params)
		local interceptor = self.request_interceptor
		if interceptor == nil then
			self:call_method(Fetch.ContinueRequest, { request_id = params.request_id })
			return
		end

		local decision = interceptor(self.transport, self.session_id, params)

		if decision.action == "Continue" then
			if (decision :: any).request_id ~= nil then
				self:call_method(Fetch.ContinueRequest, decision :: any)
			else
				self:call_method(Fetch.ContinueRequest, { request_id = params.request_id })
			end
		elseif decision.action == "Fulfill" then
			self:call_method(Fetch.FulfillRequest, decision)
		elseif decision.action == "Fail" then
			self:call_method(Fetch.FailRequest, decision)
		end
	end)

	self:add_event_listener(Fetch.AuthRequired, function(params)
		local response = self.auth_handler
		if response == nil then
			return
		end

		local request_id = params.request_id
		self:call_method(Fetch.ContinueWithAuth, {
			request_id = request_id,
			auth_challenge_response = response,
		})
	end)
end

local function new(target_info: Target.TargetInfo, transport: Transport.Transport): Tab
	local target_id = target_info.target_id
	local session_id = transport:call_method_on_browser(Target.AttachToTarget, { target_id = target_id }).session_id

	local tab = {
		target_id = target_id,
		transport = transport,
		session_id = session_id,
		navigating = false,
		target_info = target_info,
		request_interceptor = nil,
		auth_handler = nil,
		default_timeout = 20,
		page_bindings = {},
		slow_motion_multiplier = 0,
		get_target_id = get_target_id,
		update_target_info = update_target_info,
		get_url = get_url,
		set_default_timeout = set_default_timeout,
		set_slow_motion_multiplier = set_slow_motion_multiplier,
		call_method = call_method,
		add_event_listener = add_event_listener,
		get_target_info = get_target_info,
		get_browser_context_id = get_browser_context_id,
		set_user_agent = set_user_agent,
		set_extra_http_headers = set_extra_http_headers,
		set_file_chooser_dialog_interception = set_file_chooser_dialog_interception,
		handle_file_chooser = handle_file_chooser,
		bring_to_front = bring_to_front,
		reload = reload,
		stop_loading = stop_loading,
		navigate_to = navigate_to,
		wait_until_navigated = wait_until_navigated,
		wait_for_redirect = wait_for_redirect,
		get_bounds = get_bounds,
		set_bounds = set_bounds,
		set_transparent_background_color = set_transparent_background_color,
		set_background_color = set_background_color,
		evaluate = evaluate,
		get_title = get_title,
		set_cookies = set_cookies,
		get_cookies = get_cookies,
		delete_cookies = delete_cookies,
		set_storage = set_storage,
		get_storage = get_storage,
		remove_storage = remove_storage,
		capture_screenshot = capture_screenshot,
		print_to_pdf = print_to_pdf,
		start_screencast = start_screencast,
		stop_screencast = stop_screencast,
		ack_screencast = ack_screencast,
		get_dialog = get_dialog,
		get_document = get_document,
		get_content = get_content,
		describe_node = describe_node,
		run_query_selector_on_node = run_query_selector_on_node,
		run_query_selector_all_on_node = run_query_selector_all_on_node,
		find_element = find_element,
		find_element_by_xpath = find_element_by_xpath,
		find_elements = find_elements,
		find_elements_by_xpath = find_elements_by_xpath,
		wait_for_element = wait_for_element,
		wait_for_xpath = wait_for_xpath,
		wait_for_elements = wait_for_elements,
		wait_for_elements_by_xpath = wait_for_elements_by_xpath,
		move_mouse_to_point = move_mouse_to_point,
		click_point = click_point,
		insert_text = insert_text,
		type_text = type_text,
		press_key_with_modifiers = press_key_with_modifiers,
		press_key = press_key,
		enable_log = enable_log,
		disable_log = disable_log,
		start_violations_report = start_violations_report,
		stop_violations_report = stop_violations_report,
		enable_runtime = enable_runtime,
		disable_runtime = disable_runtime,
		enable_debugger = enable_debugger,
		disable_debugger = disable_debugger,
		get_script_source = get_script_source,
		enable_profiler = enable_profiler,
		disable_profiler = disable_profiler,
		start_js_coverage = start_js_coverage,
		stop_js_coverage = stop_js_coverage,
		take_js_coverage = take_js_coverage,
		enable_fetch = enable_fetch,
		disable_fetch = disable_fetch,
		enable_request_interception = enable_request_interception,
		authenticate = authenticate,
		expose_function = expose_function,
		remove_function = remove_function,
		enable_stealth_mode = enable_stealth_mode,
		close = close,
	}

	tab:call_method(Page.Enable)
	tab:call_method(Page.SetLifecycleEventsEnabled, { enabled = true })

	handle_tab_level_events(tab)

	return tab
end

return { new = new }
