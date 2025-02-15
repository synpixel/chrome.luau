local task = require("@lune/task")

export type Wait = {
	timeout: number,
	sleep: number,
	pause_until: <T>(self: Wait, predicate: () -> T) -> T,
}

local DEFAULT_TIMEOUT = 10
local DEFAULT_SLEEP = 0.1

local None = table.freeze({}) :: any

local function pause_until<T>(self: Wait, predicate: () -> T): T
	local start = os.clock()

	while true do
		local value = predicate()
		if value ~= None then
			return value
		end

		if os.clock() - start > self.timeout then
			error("Wait.pause_until timed out")
		end

		task.wait(self.sleep)
	end
end

local function new(timeout: number, sleep: number): Wait
	return {
		timeout = timeout,
		sleep = sleep,
		pause_until = pause_until,
	}
end

local function with_timeout(timeout: number): Wait
	return new(timeout, DEFAULT_SLEEP)
end

local function with_sleep(sleep: number): Wait
	return new(DEFAULT_TIMEOUT, sleep)
end

local function forever(): Wait
	return new(math.huge, DEFAULT_SLEEP)
end

return {
	None = None,
	new = new,
	with_timeout = with_timeout,
	with_sleep = with_sleep,
	forever = forever,
}
