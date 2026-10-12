# D-Class Clothing - SD Companion

Requires the original SectorialDistrict 4 Citizen Playermodels Pack on server and clients.
Install this folder alongside that original pack. Do not install SD-DClass-models,
the earlier full replacement build. Restart GMod to clear cached models/materials.

Use the existing bodygroup editor: Torso group 4, value 11 for the orange jacket;
Legs group 7, value 4 for orange trousers. Values are zero-based. These two existing
choices gain orange appearances; no additional bodygroups are added. Both sexes
are supported. Other bodygroup choices restore their original submaterials.
Existing gameplay permissions for changing bodygroups are unchanged.

Contains no MDL/VVD/VTX/PHY files and no original SD textures or copied material scripts. Two original material definitions resolve bags: the satchel references installed SD textures; the backpack uses a generic fabric fallback.
Version 3 preserves the installed original diffuse and matching normal maps at up
to 4096 resolution. Orange color is applied by a private runtime shader and the D
is drawn smaller from original vector geometry, sampling cloth shading through the ink. No low-resolution replacement atlas is used.
The twenty included detail/normal/specular/Phong maps are our procedural replacements.
During rendering, selected clothing regions are recolored in memory. Shoes and
unaffected regions retain their original texture. Nothing is exported.
Original models, animations and facial features remain provided by the original addon.

The missing APF diffuse uses the installed city_suit texture as a visual fallback;
this is not a reconstruction of the author's APF design. The old DX8 eye fallback
is not reconstructed. Original missing animation libraries are not supplied here.

The thumbnail is promotional artwork, not an in-game screenshot. Packaging and
offline checks passed; in-game lighting, multiplayer and ragdoll visuals require testing.
No determination of the SD author's license terms is made by this packaging.
Before publishing, confirm that the author allows independently supplied compatibility addons.

Rendering reference: https://wiki.facepunch.com/gmod/render.PushRenderTarget
