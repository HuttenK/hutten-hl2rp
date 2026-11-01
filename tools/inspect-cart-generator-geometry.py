"""Read-only geometric checks/plots against locally extracted user-requested assets.

Input: .runtime/equipment-model-actions-20261009/models/index.json, produced by
the narrow GMA/VPK asset inspection. No game launch or addon edits are involved.
"""
import hashlib
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / ".runtime/equipment-model-actions-20261009"
INDEX = json.loads((OUT / "models/index.json").read_text(encoding="utf-8"))


def vertices(stem):
    entry = next(r for r in INDEX if r["path"].endswith(stem + ".vvd"))
    data = Path(entry["extracted"]).read_bytes()
    count = struct.unpack_from("<i", data, 16)[0]
    offset = struct.unpack_from("<i", data, 56)[0]
    return [struct.unpack_from("<3f", data, offset + i * 48 + 16) for i in range(count)]


def model(stem):
    return next(r for r in INDEX if r["path"].endswith(stem + ".mdl"))


def plot(stem, points, rectangles, markers, limits, title):
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1500" height="670">',
           '<rect width="1500" height="670" fill="#edf1f5"/>',
           f'<text x="24" y="32" font-family="Arial" font-size="20">{title}</text>']
    for column, (a, b) in enumerate(((0, 2), (1, 2), (0, 1))):
        low, high = limits
        scale = min(420 / (high[a] - low[a]), 480 / (high[b] - low[b]))
        def project(p):
            return column * 500 + 55 + (p[a] - low[a]) * scale, 580 - (p[b] - low[b]) * scale
        svg.append(f'<text x="{column*500+30}" y="62" font-family="Arial" font-size="16">{"XYZ"[a]} / {"XYZ"[b]} - model-space units</text>')
        for tick in range(math.ceil(low[a] / 10) * 10, int(high[a]) + 1, 10):
            pos = list(low);pos[a] = tick;x, _ = project(pos)
            svg.append(f'<path d="M{x},84 V585" stroke="#cbd2d9"/><text x="{x}" y="605" font-size="12">{tick}</text>')
        for tick in range(math.ceil(low[b] / 10) * 10, int(high[b]) + 1, 10):
            pos = list(low);pos[b] = tick;_, y = project(pos)
            svg.append(f'<path d="M{column*500+40},{y} H{column*500+480}" stroke="#cbd2d9"/><text x="{column*500+10}" y="{y}" font-size="12">{tick}</text>')
        for p in points:
            x, y = project(p)
            svg.append(f'<circle cx="{x}" cy="{y}" r="1.5" fill="#234f6b" fill-opacity=".6"/>')
        for lo, hi, color in rectangles:
            x, y = project(lo);xx, yy = project(hi)
            svg.append(f'<rect x="{min(x,xx)}" y="{min(y,yy)}" width="{max(abs(xx-x),1)}" height="{max(abs(yy-y),1)}" fill="{color}" fill-opacity=".07" stroke="{color}" stroke-width="1.7"/>')
        for p, name, color in markers:
            x, y = project(p)
            svg.append(f'<circle cx="{x}" cy="{y}" r="4.5" fill="{color}"/><text x="{x+7}" y="{y-6}" font-size="12" font-family="Arial" fill="{color}">{name}</text>')
    svg.append('<text x="24" y="646" font-family="Arial" font-size="15">Blue: actual VVD vertices. Overlays: runtime calibration. Offline geometry view; not an engine screenshot.</text></svg>')
    (OUT / (stem + "-calibration.svg")).write_text("".join(svg), encoding="utf-8")


cart = vertices("pushcart02a")
gen = vertices("mobile_generator")
assert abs(min(p[2] for p in cart) + 34) < .01
assert any(abs(p[2] + 16.25) < .01 for p in cart)
slots = []
for i in range(8):
    x, y = ((-16,-11), (10,-11), (-16,11), (10,11))[i % 4]
    z = -16.2 + (i // 4) * 22
    lo, hi = (x-10.5, y-10.5, z), (x+10.5, y+10.5, z+22)
    assert lo[0] >= -36.5 and hi[0] <= 32 and hi[1] < 22 and lo[1] > -22
    for old_lo, old_hi, _ in slots:
        assert any(hi[k] <= old_lo[k] or lo[k] >= old_hi[k] for k in range(3))
    slots.append((lo, hi, "#a96400"))
# The requested grip crossbar is straight from y=-12 to y=12. Its four-sided
# profile has a center near x=36.5/z=12.85; existing hand wrap remains on it.
handle = [p for p in cart if abs(abs(p[1])-12) < .01 and p[2] > 11]
assert min(p[0] for p in handle) < 36.3 < max(p[0] for p in handle)
assert min(p[2] for p in handle) < 12.7 < max(p[2] for p in handle)
plot("pushcart02a", cart, slots,
     [((36.3, 9, 12.7), "R grip", "#d0383a"), ((36.3, -9, 12.7), "L grip", "#d0383a"),
      ((54, 0, -34), "Pusher feet", "#166946")],
     ((-43, -27, -38), (72, 27, 59)), "Cart: 2 x 2 stacks, 2 high; existing crates, deck contact and hand IK targets")

plate = ((4.3, -2.28125, 17.42), (10.3, 1.28125, 17.42), "#a96400")
socket = (-9.58, -19.23, 5.35)
socket_distance = min(math.dist(socket, p) for p in gen)
assert socket_distance < .8
assert plate[0][0] > 4.1063  # avoids the filler cap's outer edge
assert plate[1][0] < 11.082 and plate[0][1] > -6.605 and plate[1][1] < 5.71
plot("mobile_generator", gen, [plate], [(socket, "Cable socket", "#d0383a")],
     ((-17, -25, -14), (17, 23, 24)), "Generator: instrument plate on tank roof, socket on front panel")

evidence = {
    "sourceModels": [{k: model(s)[k] for k in ("path", "source", "title", "sha256", "hullMin", "hullMax")}
                     for s in ("pushcart02a", "mobile_generator")],
    "cart": {"modelOffsetFromLegacy": [0, 0, -34.5], "wheelBottom": -34,
             "deckTopMesh": -16.25, "deckTopCargo": -16.2, "grips": [[36.3, 9, 12.7], [36.3, -9, 12.7]],
             "crates": slots, "nativeHeaderMaxZ": model("pushcart02a")["hullMax"][2],
             "actualVisibleMaxZ": max(p[2] for p in cart), "collision": "calibrated eight convex hulls"},
    "generator": {"socket": socket, "distanceToNearestSocketMeshVertex": socket_distance,
                  "plate": plate, "oldFloor": -17.07115, "newFloor": -9.945116},
    "checks": "PASS: crate non-overlap/deck footprint; grips inside bar profile; plate clear of cap; socket within 0.8 of mesh",
    "limitations": "No engine physics, material rendering or multiplayer animation validation. Third-party assets remain in installed addons."
}
(OUT / "cart-generator-geometry.json").write_text(json.dumps(evidence, indent=2), encoding="utf-8")
print(evidence["checks"])
