local process = require("@lune/process")
local fs = require("@lune/fs")
local net = require("@lune/net")
local serde = require("@lune/serde")
local tempfile = require("./utils/tempfile")
local casing = require("./utils/casing")

--[=[
	Represents the way in which Chrome is run. By default it will search for a Chrome
	binary on the system, use an available port for debugging, and start in headless mode.

	@interface LaunchOptions
	.headless boolean? -- Determines whether to run headless version of the browser. Defaults to true.
	.sandbox boolean? -- Determines whether to run the browser with a sandbox.
	.devtools boolean? -- Automatically open devtools for tabs. Forces headless to be false.
	.enable_gpu boolean? -- Determines whether to enable GPU or not. Default to false.
	.enable_logging boolean? -- Determines whether to run the browser with logging enabled (this can cause unwanted new shell window in Windows 10 and above).
	.window_size { width: number, height: number }? -- Launch the browser with a specific window width and height.
	.port number? -- Launch the browser with a specific debugging port.
	.ignore_certificate_errors boolean? -- Determines whether SSL certificates should be verified. This is unsafe and can lead to MiTM attacks. This is unsafe and can lead to MiTM attacks. Make sure you understand the risks.
	.path string? -- Path for Chrome or Chromium. If unspecified, the create will try to automatically detect a suitable binary.
	.user_data_dir string? -- User Data (Profile) to use. If unspecified, a new temp directory is created and used on every launch.
	.extensions { string }? -- A list of Chrome extensions to load. An extension should be a path to a folder containing the extension code. CRX files cannot be used directly and must be first extracted. Note that Chrome does not support loading extensions in headless-mode.
	.args { string }? -- Additional arguments to pass to the browser instance. The list of Chromium flags can be found: <http://peter.sh/experiments/chromium-command-line-switches/>.
	.ignore_default_args { string }? -- Ignore a default given flag.
	.disable_default_args boolean? -- Disable default arguments.
	.idle_browser_timeout number? -- How long to keep the WebSocket to the browser for after not receiving any events from it. Defaults to 30 seconds.
	.process_envs { [string]: string }? -- Environment variables to set for the Chromium process.
	.proxy_server string? -- Setup the proxy server for headless chrome instance
	@within ChromeProcess
]=]
export type LaunchOptions = {
	headless: boolean?,
	sandbox: boolean?,
	devtools: boolean?,
	enable_gpu: boolean?,
	enable_logging: boolean?,
	window_size: { width: number, height: number }?,
	port: number?,
	ignore_certificate_errors: boolean?,
	path: string?,
	user_data_dir: string?,
	extensions: { string }?,
	args: { string }?,
	ignore_default_args: { string }?,
	disable_default_args: boolean?,
	-- fetcher_options
	idle_browser_timeout: number?,
	process_envs: { [string]: string }?,
	proxy_server: string?,
}

--- @class ChromeProcess
export type ChromeProcess = { websocket_url: string }

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

local function which(binary_name: string): string?
	local path = process.env.PATH
	if path == nil then
		return nil
	end

	for _, dir in path:split(";") do
		if fs.isDir(dir) == false then
			continue
		end

		for _, file in fs.readDir(dir) do
			if (process.os == "windows" and file:match(`{binary_name}.exe`) ~= nil) or file == binary_name then
				return `{dir}/{file}`
			end
		end
	end

	return nil
end

local function default_executable(): string
	local env_path = process.env.CHROME
	if env_path ~= nil and fs.isFile(env_path) then
		return env_path
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
local function port_is_available(port: number): boolean
	local available, handle = pcall(net.serve, port, function()
		return nil :: any
	end)

	if available then
		handle.stop()
	end

	return available
end

local function get_available_port(): number
	local ports = {}

	for port = 8000, 9000 do
		table.insert(ports, port)
	end

	for index, port in ports do
		table.remove(ports, index)
		table.insert(ports, math.random(1, #ports), port)
	end

	for _, port in ports do
		if port_is_available(port) then
			return port
		end
	end

	error("Failed to find an available port")
end

local function start_process(launch_options: LaunchOptions): process.SpawnResult
	assert(launch_options.port ~= nil, "Port is required")

	local args = {
		`--remote-debugging-port={launch_options.port}`,
		"--verbose",
		"--log-level=0",
		"--no-first-run",
	}

	if launch_options.user_data_dir ~= nil then
		table.insert(args, `--user-data-dir={launch_options.user_data_dir}`)
	else
		local user_data_dir = tempfile("chrome-luau-profile")
		table.insert(args, `--user-data-dir={user_data_dir}`)
	end

	if launch_options.disable_default_args ~= true then
		local defaults = table.clone(DEFAULT_ARGS)

		if launch_options.ignore_default_args ~= nil then
			for _, arg in launch_options.ignore_default_args do
				local index = table.find(defaults, arg)
				table.remove(defaults, index)
			end
		end

		for _, arg in defaults do
			table.insert(args, arg)
		end
	end

	if launch_options.args ~= nil then
		for _, arg in launch_options.args do
			table.insert(args, arg)
		end
	end

	if launch_options.window_size ~= nil then
		table.insert(args, `--window-size={launch_options.window_size.width},{launch_options.window_size.height}`)
	end

	if launch_options.headless and launch_options.devtools == false then
		table.insert(args, "--headless")
	elseif launch_options.devtools then
		table.insert(args, "--auto-open-devtools-for-tabs")
	end

	if launch_options.ignore_certificate_errors then
		table.insert(args, "--ignore-certificate-errors")
	end

	if launch_options.enable_logging then
		table.insert(args, "--enable-logging")
	end

	if launch_options.enable_gpu then
		table.insert(args, "--enable-gpu")
	end

	if launch_options.proxy_server ~= nil then
		table.insert(args, `--proxy-server={launch_options.proxy_server}`)
	end

	if launch_options.sandbox == false then
		table.insert(args, "--no-sandbox")
		table.insert(args, "--disable-setuid-sandbox")
	end

	if launch_options.extensions ~= nil then
		for _, extension in launch_options.extensions do
			table.insert(args, `--load-extension={extension}`)
		end
	end

	assert(launch_options.path ~= nil, "Path is required")

	local result = process.spawn(launch_options.path, args, {
		env = launch_options.process_envs,
		shell = true,
		stdio = "none",
	})

	return result
end

local function fetch_websocket_url(port: number): string
	local response = net.request(`http://localhost:{port}/json/version`)
	assert(response.ok, `{response.statusCode} {response.statusMessage}`)

	local version = serde.decode("json", response.body)
	version = casing.camel_to_snake(version)

	return version.web_socket_debugger_url
end

local function new(partial_launch_options: LaunchOptions?): ChromeProcess
	local launch_options: LaunchOptions = {
		headless = true,
		sandbox = false,
		devtools = false,
	}

	if partial_launch_options ~= nil then
		for key, value in partial_launch_options do
			launch_options[key] = value
		end
	end

	if launch_options.path == nil then
		-- TODO: fetch
		launch_options.path = default_executable()
	end

	if launch_options.port == nil then
		launch_options.port = get_available_port()
	end

	start_process(launch_options)

	local websocket_url = fetch_websocket_url(launch_options.port :: number)

	return { websocket_url = websocket_url }
end

return { new = new }
