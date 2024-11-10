local chrome = require("../src")

local browser = chrome.Browser.new()

local function query(input: string)
	local tab = browser:newTab()

	tab:navigateTo("https://en.wikipedia.org"):waitUntilNavigated():waitForElement("input#searchInput"):click()
	tab:typeText(input):pressKey("Enter"):waitUntilNavigated()

	local shortDescription = tab:waitForElement("div.shortdescription")
	print(`Result for {input}: {shortDescription:getInnerText()}`)

	tab:close()
end

query("Google Chrome")
query("WebKit")
query("Skibidi Toilet")

browser:close()
