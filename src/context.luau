local types = require("./types")

export type Context = types.Context

local function get_id(self: Context): string
	return self.id
end

local function get_tabs(self: Context): { types.Tab }
	local tabs = {}

	for _, tab in self.browser:get_tabs() do
		if tab:get_browser_context_id() == self.id then
			table.insert(tabs, tab)
		end
	end

	return tabs
end

local function new_tab(self: Context): types.Tab
	return self.browser:new_tab_with_options({
		url = "about:blank",
		browser_context_id = self.id,
	})
end

local function new(browser: types.Browser, context_id: string): Context
	return {
		id = context_id,
		browser = browser,
		get_id = get_id,
		get_tabs = get_tabs,
		new_tab = new_tab,
	}
end

return { new = new }
