local process = require("@lune/process")
local fs = require("@lune/fs")

local function which(binaryName: string): string?
	local path = process.env.path
	if path == nil then
		return nil
	end

	for dir in path:gmatch("(.-);") do
		if fs.isDir(dir) == false then
			continue
		end

		for _, file in fs.readDir(dir) do
			if (process.os == "windows" and file:match(`{binaryName}.exe`) ~= nil) or file == binaryName then
				return `{dir}/{file}`
			end
		end
	end

	return nil
end

local function defaultExecutable(): string
	local envPath = process.env.CHROME
	if envPath ~= nil and fs.isFile(envPath) then
		return envPath
	end

	for _, app in
		{
			"google-chrome-stable",
			"google-chrome-beta",
			"google-chrome-dev",
			"google-chrome-unstable",
			"chromium",
			"chromium-browser",
			"microsoft-edge-stable",
			"microsoft-edge-beta",
			"microsoft-edge-dev",
			"chrome",
			"chrome-browser",
			"msedge",
			"microsoft-edge",
		}
	do
		local path = which(app)
		if path ~= nil then
			return path
		end
	end

	if process.os == "macos" then
		for _, path in
			{
				"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
				"/Applications/Google Chrome Beta.app/Contents/MacOS/Google Chrome Beta",
				"/Applications/Google Chrome Dev.app/Contents/MacOS/Google Chrome Dev",
				"/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary",
				"/Applications/Chromium.app/Contents/MacOS/Chromium",
				"/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
				"/Applications/Microsoft Edge Beta.app/Contents/MacOS/Microsoft Edge Beta",
				"/Applications/Microsoft Edge Dev.app/Contents/MacOS/Microsoft Edge Dev",
				"/Applications/Microsoft Edge Canary.app/Contents/MacOS/Microsoft Edge Canary",
			}
		do
			if fs.isFile(path) then
				return path
			end
		end
	end

	if process.os == "windows" then
		-- TODO: windows registry

		local path = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
		if fs.isFile(path) then
			return path
		end
	end

	error("Could not auto detect a chrome executable")
end

return defaultExecutable
