local chrome = require("../src")

local browser = chrome.Browser.new({
	-- The searchbar won't appear if the resolution is too low
	windowSize = { width = 1600, height = 768 },
})

local function query(input: string)
	local tab = browser:newTab()

	tab:navigateTo("https://en.wikipedia.org"):waitUntilNavigated():waitForElement("input#searchInput"):click()
	tab:typeText(input):pressKey("Enter"):waitUntilRedirect()

	local shortDescription = tab:findElement("div.shortdescription")
	if shortDescription == nil then
		print("No shortdescription-node found on page")
		return
	end

	print(`Result for {input}: {shortDescription:getInnerText()}`)

	tab:close()
end

query("Google Chrome")
query("WebKit")
query("Skibidi Toilet")

browser:close()
