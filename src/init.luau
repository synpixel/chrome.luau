local ChromeProcess = require("./chrome-process")
local Browser = require("./browser")
local Tab = require("./tab")
local Wait = require("./utils/wait")

export type LaunchOptions = ChromeProcess.LaunchOptions
export type Browser = Browser.Browser
export type Tab = Tab.Tab
export type Element = Tab.Element
export type ElementQuad = Tab.ElementQuad
export type BoxModel = Tab.BoxModel

return {
	Browser = Browser,
	Wait = Wait,
}
