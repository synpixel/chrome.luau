local fs = require("@lune/fs")
local chrome = require("../src")

local browser = chrome.Browser.new()
local tab = browser:newTab()

local jpeg = tab:navigateTo("https://www.wikipedia.org")
	:waitUntilNavigated()
	:captureScreenshot({ format = "jpeg", quality = 75, fromSurface = true })
fs.writeFile("screenshot.jpg", jpeg)

local png = tab:navigateTo("https://en.wikipedia.org/wiki/WebKit")
	:waitUntilNavigated()
	:waitForElement("#mw-content-text > div > table.infobox.vevent")
	:captureScreenshot({ format = "png" })
fs.writeFile("screenshot.png", png)

print("Screenshots successfully created.")
