local process = require("@lune/process")
local net = require("@lune/net")
local serde = require("@lune/serde")
local defaultExecutable = require("./utils/default-executable")

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
	-- TODO: tempfile
	local userDataDir = launchOptions.userDataDir
	local userDataDirOption = if userDataDir ~= nil then `--user-data-dir={userDataDir}` else ""

	local args = {
		`--remote-debugging-port={launchOptions.port}`,
		"--verbose",
		"--log-level=0",
		"--no-first-run",
		userDataDirOption,
	}

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

local function getWebsocketUrl(port: number): string
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

	local websocketUrl = getWebsocketUrl(launchOptions.port :: number)

	return { websocketUrl = websocketUrl }
end

return { new = new }
