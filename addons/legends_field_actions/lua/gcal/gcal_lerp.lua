GCAL = GCAL or {}
GCAL.Lerp = {}

-- Basic Linear
function GCAL.Lerp.Linear(t, b, c, d)
    return c * t / d + b
end

-- Quadratic
function GCAL.Lerp.InQuad(t, b, c, d)
    t = t / d
    return c * t * t + b
end

function GCAL.Lerp.OutQuad(t, b, c, d)
    t = t / d
    return -c * t * (t - 2) + b
end

function GCAL.Lerp.InOutQuad(t, b, c, d)
    t = t / (d / 2)
    if t < 1 then return c / 2 * t * t + b end
    t = t - 1
    return -c / 2 * (t * (t - 2) - 1) + b
end

-- Cubic
function GCAL.Lerp.InCubic(t, b, c, d)
    t = t / d
    return c * t * t * t + b
end

function GCAL.Lerp.OutCubic(t, b, c, d)
    t = t / d - 1
    return c * (t * t * t + 1) + b
end

function GCAL.Lerp.InOutCubic(t, b, c, d)
    t = t / (d / 2)
    if t < 1 then return c / 2 * t * t * t + b end
    t = t - 2
    return c / 2 * (t * t * t + 2) + b
end

-- Elastic
function GCAL.Lerp.OutElastic(t, b, c, d, a, p)
    if t == 0 then return b end
    t = t / d
    if t == 1 then return b + c end
    if not p then p = d * 0.3 end
    local s
    if not a or a < math.abs(c) then
        a = c
        s = p / 4
    else
        s = p / (2 * math.pi) * math.asin(c / a)
    end
    return a * 2 ^ (-10 * t) * math.sin((t * d - s) * (2 * math.pi) / p) + c + b
end

-- Legacy Power-based Lerp (for compatibility)
function GCAL.Lerp.Legacy(t, a, b, powa)
    return a + (b - a) * t ^ powa
end

-- Helper to get lerp function by name
function GCAL.Lerp.Get(name)
    return GCAL.Lerp[name] or GCAL.Lerp.OutQuad
end
