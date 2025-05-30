local chrome = require("../src")

local browser = chrome.Browser.new({
	-- The searchbar won't appear if the resolution is too low
	window_size = { width = 1600, height = 768 },
})

local function query(input: string)
	local tab = browser:new_tab()

	tab:navigate_to("https://en.wikipedia.org"):wait_until_navigated():wait_for_element("input#searchInput"):click()
	tab:type_text(input):press_key("Enter"):wait_for_redirect()

	local short_description = tab:find_element("div.shortdescription")
	if short_description == nil then
		print("No shortdescription-node found on page")
		return
	end

	print(`Result for {input}: {short_description:get_inner_text()}`)

	tab:close()
end

query("Google Chrome")
query("WebKit")
query("Destroy Lonely")

browser:close()
