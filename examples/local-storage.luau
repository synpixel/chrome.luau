local chrome = require("../src")

local browser = chrome.Browser.new()
local tab = browser:new_tab()

tab:navigate_to("https://www.wikipedia.org"):wait_until_navigated()

local item = tab:get_storage("translationHash") :: string
print(item)
