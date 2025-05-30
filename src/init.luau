local ChromeProcess = require("@self/chrome-process")
local Browser = require("@self/browser")
local Context = require("@self/context")
local Tab = require("@self/tab")
local Wait = require("@self/utils/wait")
local Method = require("@self/protocol/method")
local Event = require("@self/protocol/event")

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
