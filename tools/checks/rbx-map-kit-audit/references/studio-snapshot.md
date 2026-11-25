# Capture Studio seam pairs

In the Studio Command Bar, set `pairs` to the exact Attachment instance paths for the current assembly. Resolve real objects in Explorer first. Include known rotated corners, mirrored modules, and sloped joins when present. Run the command in the intended place and copy the JSON from Output to `joins.json`. The command reads instance transforms and prints the result.

```lua
local HttpService = game:GetService("HttpService")

local pairs = {
    {
        id = "straight-to-corner",
        a = workspace.TestKit.Straight.RightSeam,
        b = workspace.TestKit.Corner.EntrySeam,
    },
}

local function xyz(vector)
    return { vector.X, vector.Y, vector.Z }
end

local function snapshot(attachment)
    assert(attachment:IsA("Attachment"), "Expected an Attachment")
    local frame = attachment.WorldCFrame
    return {
        path = attachment:GetFullName(),
        position = xyz(frame.Position),
        forward = xyz(frame.LookVector),
        up = xyz(frame.UpVector),
    }
end

local result = {
    max_gap_studs = 0.02,
    max_facing_deg = 1,
    max_twist_deg = 1,
    pairs = {},
}

for _, pair in ipairs(pairs) do
    table.insert(result.pairs, {
        id = pair.id,
        a = snapshot(pair.a),
        b = snapshot(pair.b),
    })
end
print(HttpService:JSONEncode(result))
```

These sample tolerances are starting values. Use the asset's actual design tolerances. For decorative overlaps or intentional gaps, choose matching logical seam reference points. The distance is between those points. It does not estimate wall thickness or collision penetration.
