local ChromeProcess = require("./src/chrome-process")
local Browser = require("./src/browser")
local Context = require("./src/context")
local Tab = require("./src/tab")
local Wait = require("./src/utils/wait")
local Method = require("./src/protocol/method")
local Event = require("./src/protocol/event")

export type LaunchOptions = ChromeProcess.LaunchOptions
export type Browser = Browser.Browser
export type Context = Context.Context
export type Tab = Tab.Tab
export type Element = Tab.Element
export type ElementQuad = Tab.ElementQuad
export type BoxModel = Tab.BoxModel

return {
	Browser = Browser,
	Wait = Wait,
	Method = Method,
	Event = Event,
}
