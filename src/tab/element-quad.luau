local types = require("../types")

export type ElementQuad = types.ElementQuad

local function height(self: ElementQuad): number
	return self.bottom_left.y - self.top_left.y
end

local function width(self: ElementQuad): number
	return self.top_right.x - self.top_left.x
end

local function aspect_ratio(self: ElementQuad): number
	return self:width() / self:height()
end

local function most_left(self: ElementQuad): number
	return math.min(self.top_right.x, self.top_left.x, self.bottom_right.x, self.bottom_left.x)
end

local function most_right(self: ElementQuad): number
	return math.max(self.top_right.x, self.top_left.x, self.bottom_right.x, self.bottom_left.x)
end

local function most_top(self: ElementQuad): number
	return math.min(self.top_right.y, self.top_left.y, self.bottom_right.y, self.bottom_left.y)
end

local function most_bottom(self: ElementQuad): number
	return math.max(self.top_right.y, self.top_left.y, self.bottom_right.y, self.bottom_left.y)
end

local function strictly_above(self: ElementQuad, other: ElementQuad): boolean
	return self:most_bottom() < other:most_top()
end

local function above(self: ElementQuad, other: ElementQuad): boolean
	return self:most_bottom() <= other:most_top()
end

local function strictly_below(self: ElementQuad, other: ElementQuad): boolean
	return self:most_top() > other:most_bottom()
end

local function below(self: ElementQuad, other: ElementQuad): boolean
	return self:most_top() >= other:most_bottom()
end

local function strictly_left_of(self: ElementQuad, other: ElementQuad): boolean
	return self:most_right() < other:most_left()
end

local function left_of(self: ElementQuad, other: ElementQuad): boolean
	return self:most_right() <= other:most_left()
end

local function strictly_right_of(self: ElementQuad, other: ElementQuad): boolean
	return self:most_left() > other:most_right()
end

local function right_of(self: ElementQuad, other: ElementQuad): boolean
	return self:most_left() >= other:most_right()
end

local function within_horizontal_bounds_of(self: ElementQuad, other: ElementQuad): boolean
	return self:most_left() >= other:most_left() and self:most_right() <= other:most_right()
end

local function within_vertical_bounds_of(self: ElementQuad, other: ElementQuad): boolean
	return self:most_top() >= other:most_top() and self:most_bottom() <= other:most_bottom()
end

local function within_bounds_of(self: ElementQuad, other: ElementQuad): boolean
	return self:within_horizontal_bounds_of(other) and self:within_vertical_bounds_of(other)
end

--- @within ElementQuad
local function from_raw_points(raw_quad: { number }): ElementQuad
	return {
		top_left = { x = raw_quad[1], y = raw_quad[2] },
		top_right = { x = raw_quad[3], y = raw_quad[4] },
		bottom_right = { x = raw_quad[5], y = raw_quad[6] },
		bottom_left = { x = raw_quad[7], y = raw_quad[8] },
		height = height,
		width = width,
		aspect_ratio = aspect_ratio,
		most_left = most_left,
		most_right = most_right,
		most_top = most_top,
		most_bottom = most_bottom,
		strictly_above = strictly_above,
		above = above,
		strictly_below = strictly_below,
		below = below,
		strictly_left_of = strictly_left_of,
		left_of = left_of,
		strictly_right_of = strictly_right_of,
		right_of = right_of,
		within_horizontal_bounds_of = within_horizontal_bounds_of,
		within_vertical_bounds_of = within_vertical_bounds_of,
		within_bounds_of = within_bounds_of,
	}
end

return { from_raw_points = from_raw_points }
