local chrome = require("../src")

local browser = chrome.Browser.new({ headless = false })
local tab = browser:newTab()

tab:navigateTo("https://www.google.com"):waitUntilNavigated()

tab:addEventListener(chrome.Event.PageLifecycleEvent, function(lifecycle)
	if lifecycle.name == "DOMContentLoaded" then
		print(tab:getUrl())
	end
end)
