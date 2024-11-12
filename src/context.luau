local types = require("./types")

--- Equivalent to a new incognito window
--- @class Context
export type Context = types.Context

--- The BrowserContextId associated with this context
--- @within Context
local function getId(self: Context): string
	return self.id
end

--- Any tabs created in this context
--- @within Context
local function getTabs(self: Context): { types.Tab }
	local tabs = {}

	for _, tab in self.browser:getTabs() do
		if tab:getBrowserContextId() == self.id then
			table.insert(tabs, tab)
		end
	end

	return tabs
end

--- Opens a new tab in this context. It will not share cookies or a cache with the default
--- browsing context or any other contexts created
--- @within Context
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
