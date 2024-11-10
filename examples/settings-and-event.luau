local chrome = require("../src")
local Page = chrome.protocol.Page

local browser = chrome.Browser.new({ headless = false })
local tab = browser:newTab()

tab:navigateTo("https://www.google.com"):waitUntilNavigated()

tab:addEventListener(Page.LifecycleEvent, function(lifecycle)
	if lifecycle.name == "DOMContentLoaded" then
		print(tab:getUrl())
	end
end)
