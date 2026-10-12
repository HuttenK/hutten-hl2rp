-- Helix includes libs before items/entities, and sh_plugin only afterwards.
-- Entity files need these constants and capture both tables during inclusion.
-- Keep the table identities stable across reloads; sh_kinematics fills Kin later.
ix.PushCart = ix.PushCart or {}

local PushCart = ix.PushCart
PushCart.Kin = PushCart.Kin or {}
PushCart.MODEL = "models/props_junk/pushcart02a.mdl"
PushCart.MODEL_Z_OFFSET = -34.5
-- Use the visible crate dimensions for selection on both realms. Model bounds
-- refer to the full-sized stock mesh, not the scaled cargo container.
PushCart.CRATE_MINS = Vector(-10.5, -10.5, 0)
PushCart.CRATE_MAXS = Vector(10.5, 10.5, 22)
