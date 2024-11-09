local process = require("@lune/process")
local fs = require("@lune/fs")
local net = require("@lune/net")
local serde = require("@lune/serde")
local tempfile = require("./utils/tempfile")

--- Represents the way in which Chrome is run. By default it will search for a Chrome
--- binary on the system, use an available port for debugging, and start in headless mode.
--- @interface LaunchOptions
--- .headless boolean? -- Determines whether to run headless version of the browser. Defaults to true.
--- .sandbox boolean? -- Determines whether to run the browser with a sandbox.
--- .devtools boolean? -- Automatically open devtools for tabs. Forces headless to be false.
--- .enableGpu boolean? -- Determines whether to enable GPU or not. Default to false.
--- .enableLogging boolean? -- Determines whether to run the browser with logging enabled (this can cause unwanted new shell window in Windows 10 and above).
--- .windowSize { width: number, height: number }? -- Launch the browser with a specific window width and height.
--- .port number? -- Launch the browser with a specific debugging port.
--- .ignoreCertificateErrors boolean? -- Determines whether SSL certificates should be verified. This is unsafe and can lead to MiTM attacks. This is unsafe and can lead to MiTM attacks. Make sure you understand the risks.
--- .path string? -- Path for Chrome or Chromium. If unspecified, the create will try to automatically detect a suitable binary.
--- .userDataDir string? -- User Data (Profile) to use.
--- .extensions { string }? -- A list of Chrome extensions to load. An extension should be a path to a folder containing the extension code. CRX files cannot be used directly and must be first extracted. Note that Chrome does not support loading extensions in headless-mode.
--- .args { string }? -- Additional arguments to pass to the browser instance. The list of Chromium flags can be found: <http://peter.sh/experiments/chromium-command-line-switches/>.
--- .ignoreDefaultArgs { string }? -- Ignore a default given flag.
--- .disableDefaultArgs boolean? -- Disable default arguments.
--- .idleBrowserTimeout number? -- How long to keep the WebSocket to the browser for after not receiving any events from it. Defaults to 30 seconds.
--- .processEnvs { [string]: string }? -- Environment variables to set for the Chromium process.
--- .proxyServer string? -- Setup the proxy server for headless chrome instance
--- @within ChromeProcess
export type LaunchOptions = {
	headless: boolean?,
	sandbox: boolean?,
	devtools: boolean?,
	enableGpu: boolean?,
	enableLogging: boolean?,
	windowSize: { width: number, height: number }?,
	port: number?,
	ignoreCertificateErrors: boolean?,
	path: string?,
	userDataDir: string?,
	extensions: { string }?,
	args: { string }?,
	ignoreDefaultArgs: { string }?,
	disableDefaultArgs: boolean?,
	-- fetcher_options
	idleBrowserTimeout: number?,
	processEnvs: { [string]: string }?,
	proxyServer: string?,
}

--- @class ChromeProcess
export type ChromeProcess = { websocketUrl: string }

local DEFAULT_ARGS = table.freeze({
	"--disable-background-networking",
	"--enable-features=NetworkService,NetworkServiceInProcess",
	"--disable-background-timer-throttling",
	"--disable-backgrounding-occluded-windows",
	"--disable-breakpad",
	"--disable-client-side-phishing-detection",
	"--disable-component-extensions-with-background-pages",
	"--disable-default-apps",
	"--disable-dev-shm-usage",
	"--disable-extensions",
	-- BlinkGenPropertyTrees disabled due to crbug.com/937609
	"--disable-features=TranslateUI,BlinkGenPropertyTrees",
	"--disable-hang-monitor",
	"--disable-ipc-flooding-protection",
	"--disable-popup-blocking",
	"--disable-prompt-on-repost",
	"--disable-renderer-backgrounding",
	"--disable-sync",
	"--force-color-profile=srgb",
	"--metrics-recording-only",
	"--no-first-run",
	"--enable-automation",
	"--password-store=basic",
	"--use-mock-keychain",
})

local function which(binaryName: string): string?
	local path = process.env.PATH
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

-- This does not work as `net.serve` won't throw
local function portIsAvailable(port: number): boolean
	local available, handle = pcall(net.serve, port, function()
		return nil :: any
	end)

	if available then
		handle.stop()
	end

	return available
end

local function getAvailablePort(): number
	local ports = {}

	for port = 8000, 9000 do
		table.insert(ports, port)
	end

	for index, port in ports do
		table.remove(ports, index)
		table.insert(ports, math.random(1, #ports), port)
	end

	for _, port in ports do
		if portIsAvailable(port) then
			return port
		end
	end

	error("Failed to find an available port")
end

local function startProcess(launchOptions: LaunchOptions): process.SpawnResult
	assert(launchOptions.port ~= nil, "Port is required")

	local args = {
		`--remote-debugging-port={launchOptions.port}`,
		"--verbose",
		"--log-level=0",
		"--no-first-run",
	}

	if launchOptions.userDataDir ~= nil then
		table.insert(args, `--user-data-dir={launchOptions.userDataDir}`)
	else
		local userDataDir = tempfile("chrome-luau-profile")
		table.insert(args, `--user-data-dir={userDataDir}`)
	end

	if launchOptions.disableDefaultArgs ~= true then
		local defaults = table.clone(DEFAULT_ARGS)

		if launchOptions.ignoreDefaultArgs ~= nil then
			for _, arg in launchOptions.ignoreDefaultArgs do
				local index = table.find(defaults, arg)
				table.remove(defaults, index)
			end
		end

		for _, arg in defaults do
			table.insert(args, arg)
		end
	end

	if launchOptions.args ~= nil then
		for _, arg in launchOptions.args do
			table.insert(args, arg)
		end
	end

	if launchOptions.windowSize ~= nil then
		table.insert(args, `--window-size={launchOptions.windowSize.width},{launchOptions.windowSize.height}`)
	end

	if launchOptions.headless and launchOptions.devtools == false then
		table.insert(args, "--headless")
	elseif launchOptions.devtools then
		table.insert(args, "--auto-open-devtools-for-tabs")
	end

	if launchOptions.ignoreCertificateErrors then
		table.insert(args, "--ignore-certificate-errors")
	end

	if launchOptions.enableLogging then
		table.insert(args, "--enable-logging")
	end

	if launchOptions.enableGpu then
		table.insert(args, "--enable-gpu")
	end

	if launchOptions.proxyServer ~= nil then
		table.insert(args, `--proxy-server={launchOptions.proxyServer}`)
	end

	if launchOptions.sandbox == false then
		table.insert(args, "--no-sandbox")
		table.insert(args, "--disable-setuid-sandbox")
	end

	if launchOptions.extensions ~= nil then
		for _, extension in launchOptions.extensions do
			table.insert(args, `--load-extension={extension}`)
		end
	end

	assert(launchOptions.path ~= nil, "Path is required")

	local result = process.spawn(launchOptions.path, args, {
		env = launchOptions.processEnvs,
		shell = true,
		stdio = "none",
	})

	return result
end

local function fetchWebsocketUrl(port: number): string
	local response = net.request(`http://localhost:{port}/json/version`)
	assert(response.ok, `{response.statusCode} {response.statusMessage}`)

	local version = serde.decode("json", response.body) :: { webSocketDebuggerUrl: string }
	return version.webSocketDebuggerUrl
end

local function new(partialLaunchOptions: LaunchOptions?): ChromeProcess
	local launchOptions: LaunchOptions = {
		headless = true,
		sandbox = false,
		devtools = false,
	}

	if partialLaunchOptions ~= nil then
		for key, value in partialLaunchOptions do
			launchOptions[key] = value
		end
	end

	if launchOptions.path == nil then
		-- TODO: fetch
		launchOptions.path = defaultExecutable()
	end

	if launchOptions.port == nil then
		launchOptions.port = getAvailablePort()
	end

	startProcess(launchOptions)

	local websocketUrl = fetchWebsocketUrl(launchOptions.port :: number)

	return { websocketUrl = websocketUrl }
end

return { new = new }
