# chrome.luau

A port of [rust-headless-chrome](https://github.com/rust-headless-chrome/rust-headless-chrome) to Luau built for Lune

## Quick Start

```luau
local fs = require("@lune/fs")
local chrome = require("@pkg/chrome")

local browser = chrome.Browser.new()
local tab = browser:newTab()

-- Navigate to wikipedia
tab:navigateTo("https://www.wikipedia.org"):waitUntilNavigated()

-- Wait for network/javascript/dom to make the search-box available
-- and click it.
tab:waitForElement("input#searchInput"):click()

-- Type in a query and press `Enter`
tab:typeText("WebKit"):pressKey("Enter"):waitUntilNavigated()

-- We should end up on the WebKit-page once navigated
local element = tab:waitForElement("#firstHeading")
assert(tab:getUrl():sub(-6) == "WebKit")

-- Take a screenshot of the entire browser window
local jpeg = tab:captureScreenshot({ format = "jpeg", fromSurface = true })
-- Save the screenshot to disc
fs.writeFile("screenshot.jpeg", jpeg)

-- Take a screenshot of just the WebKit-Infobox
local png = tab:waitForElement("#mw-content-text > div > table.infobox.vevent"):captureScreenshot({ format = "png" })
-- Save the screenshot to disc
fs.writeFile("screenshot.png", png)

-- Run JavaScript in the page
local result = element:callJsFunction([[
    function getIdTwice () {
        // `this` is always the element that you called `callJsFunction` on
        const id = this.id;
        return id + id;
    }
]])

assert(result.value == "firstHeadingfirstHeading")
```
