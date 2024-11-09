local chrome = require("../src")

local browser = chrome.Browser.new()
local tab = browser:newTab()

tab:navigateTo("https://www.wikipedia.org"):waitUntilNavigated()

local item = tab:getStorage("translationHash") :: string
print(item)
