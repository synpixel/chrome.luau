local process = require("@lune/process")
local fs = require("@lune/fs")
local chrome = require("../src")

local WEBSOCKET_URL = assert(process.args[1], "Must provide websocket url")
local FILE_PATH = assert(process.args[2], "Must provide path/to/file/index.html")

local browser = chrome.Browser.connect(WEBSOCKET_URL)
local tab = browser:newTab()

local wikidata = tab:navigateTo("https://www.wikipedia.org"):waitUntilNavigated():printToPdf()
fs.writeFile("wiki.pdf", wikidata)
print("PDF successfully created from internet web page.")

local localPdf = tab:navigateTo(FILE_PATH):waitUntilNavigated():printToPdf()
fs.writeFile("rust.pdf", localPdf)
print("PDF successfully created from local web page.")
