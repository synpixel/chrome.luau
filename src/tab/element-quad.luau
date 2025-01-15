local types = require("../types")

export type ElementQuad = types.ElementQuad

local function height(self: ElementQuad): number
	return self.bottomLeft.y - self.topLeft.y
end

local function width(self: ElementQuad): number
	return self.topRight.x - self.topLeft.x
end

local function aspectRatio(self: ElementQuad): number
	return self:width() / self:height()
end

local function mostLeft(self: ElementQuad): number
	return math.min(self.topRight.x, self.topLeft.x, self.bottomRight.x, self.bottomLeft.x)
end

local function mostRight(self: ElementQuad): number
	return math.max(self.topRight.x, self.topLeft.x, self.bottomRight.x, self.bottomLeft.x)
end

local function mostTop(self: ElementQuad): number
	return math.min(self.topRight.y, self.topLeft.y, self.bottomRight.y, self.bottomLeft.y)
end

local function mostBottom(self: ElementQuad): number
	return math.max(self.topRight.y, self.topLeft.y, self.bottomRight.y, self.bottomLeft.y)
end

local function strictlyAbove(self: ElementQuad, other: ElementQuad): boolean
	return self:mostBottom() < other:mostTop()
end

local function above(self: ElementQuad, other: ElementQuad): boolean
	return self:mostBottom() <= other:mostTop()
end

local function strictlyBelow(self: ElementQuad, other: ElementQuad): boolean
	return self:mostTop() > other:mostBottom()
end

local function below(self: ElementQuad, other: ElementQuad): boolean
	return self:mostTop() >= other:mostBottom()
end

local function strictlyLeftOf(self: ElementQuad, other: ElementQuad): boolean
	return self:mostRight() < other:mostLeft()
end

local function leftOf(self: ElementQuad, other: ElementQuad): boolean
	return self:mostRight() <= other:mostLeft()
end

local function strictlyRightOf(self: ElementQuad, other: ElementQuad): boolean
	return self:mostLeft() > other:mostRight()
end

local function rightOf(self: ElementQuad, other: ElementQuad): boolean
	return self:mostLeft() >= other:mostRight()
end

local function withinHorizontalBoundsOf(self: ElementQuad, other: ElementQuad): boolean
	return self:mostLeft() >= other:mostLeft() and self:mostRight() <= other:mostRight()
end

local function withinVerticalBoundsOf(self: ElementQuad, other: ElementQuad): boolean
	return self:mostTop() >= other:mostTop() and self:mostBottom() <= other:mostBottom()
end

local function withinBoundsOf(self: ElementQuad, other: ElementQuad): boolean
	return self:withinHorizontalBoundsOf(other) and self:withinVerticalBoundsOf(other)
end

--- @within ElementQuad
local function fromRawPoints(rawQuad: { number }): ElementQuad
	return {
		topLeft = { x = rawQuad[1], y = rawQuad[2] },
		topRight = { x = rawQuad[3], y = rawQuad[4] },
		bottomRight = { x = rawQuad[5], y = rawQuad[6] },
		bottomLeft = { x = rawQuad[7], y = rawQuad[8] },
		height = height,
		width = width,
		aspectRatio = aspectRatio,
		mostLeft = mostLeft,
		mostRight = mostRight,
		mostTop = mostTop,
		mostBottom = mostBottom,
		strictlyAbove = strictlyAbove,
		above = above,
		strictlyBelow = strictlyBelow,
		below = below,
		strictlyLeftOf = strictlyLeftOf,
		leftOf = leftOf,
		strictlyRightOf = strictlyRightOf,
		rightOf = rightOf,
		withinHorizontalBoundsOf = withinHorizontalBoundsOf,
		withinVerticalBoundsOf = withinVerticalBoundsOf,
		withinBoundsOf = withinBoundsOf,
	}
end

return { fromRawPoints = fromRawPoints }
