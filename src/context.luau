local types = require("./types")

export type Context = types.Context

local function getId(self: Context): string
	return self.id
end

local function getTabs(self: Context): { types.Tab }
	local tabs = {}

	for _, tab in self.browser:getTabs() do
		if tab:getBrowserContextId() == self.id then
			table.insert(tabs, tab)
		end
	end

	return tabs
end

local function newTab(self: Context): types.Tab
	return self.browser:newTabWithOptions({
		url = "about:blank",
		browserContextId = self.id,
	})
end

local function new(browser: types.Browser, contextId: string): Context
	return {
		id = contextId,
		browser = browser,
		getId = getId,
		getTabs = getTabs,
		newTab = newTab,
	}
end

return { new = new }
