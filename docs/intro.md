# Introduction

This package is a port of [rust-headless-chrome](https://github.com/rust-headless-chrome/rust-headless-chrome) to Luau, built for Lune.

## Installation

### pesde

```sh
pesde add synpixel/chrome
```

## Quick Start

```luau
local fs = require("@lune/fs")
local chrome = require("@pkg/chrome")

local browser = chrome.Browser.new()
local tab = browser:new_tab()

-- Navigate to wikipedia
tab:navigate_to("https://www.wikipedia.org"):wait_until_navigated()

-- Wait for network/javascript/dom to make the search-box available
-- and click it.
tab:wait_for_element("input#searchInput"):click()

-- Type in a query and press `Enter`
tab:type_text("WebKit"):press_key("Enter"):wait_until_redirect()

-- We should end up on the WebKit-page once navigated
local element = tab:wait_for_element("#firstHeading")
assert(tab:get_url():sub(-6) == "WebKit")

-- Take a screenshot of the entire browser window
local jpeg = tab:capture_screenshot({ format = "jpeg", from_surface = true })
-- Save the screenshot to disc
fs.writeFile("screenshot.jpeg", jpeg)

-- Take a screenshot of just the WebKit-Infobox
local png = tab:wait_for_element("#mw-content-text > div > table.infobox.vevent"):capture_screenshot({ format = "png" })
-- Save the screenshot to disc
fs.writeFile("screenshot.png", png)

-- Run JavaScript in the page
local result = element:call_js_function([[
    function getIdTwice () {
        // `this` is always the element that you called `call_js_function` on
        const id = this.id;
        return id + id;
    }
]])

assert(result.value == "firstHeadingfirstHeading")
```
