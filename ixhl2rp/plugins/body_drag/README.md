# One-handed body dragging

Press **E** while looking at a living player's fallover body or a critical player and choose **ВЗЯТЬ ЛЕВОЙ РУКОЙ**. While dragging, E opens the release option; `/BodyRelease` also releases immediately.

The grip trails actual movement, smoothly rotating behind forward travel and in front of backward travel. The left arm follows the ragdoll grip; the right arm keeps the weapon animation. Shooting, aiming and weapon switching remain available. Reloading is blocked, including ARC9 automatic reloads. Hold R still raises/lowers the weapon. Finish a reload before starting a drag.

The server pulls one physics bone with bounded speed. Walls, excessive separation, teleports, vehicles, death, recovery, character changes and disconnects release the grip. Only carrier/body collision is suppressed, and it is restored on release. No Workshop files are modified.

ARC9 arm updates use the existing `arc9_helperbones` integration's `ixARC9PostArmPose` event after its helper repair. Dragging must not wrap `DoTPIK` itself: two independent wrappers previously kept nesting every frame, causing severe slowdown and distorted meshes. Ragdoll grip sampling occurs once per frame in `PreRender`, outside all bone-build callbacks.

## Solo testing with the existing testdummy plugin

Use a local multiplayer session with at least two player slots; no other human is needed. A real player bot cannot join singleplayer.

- `/dummycreate` (alias `/dummyadd`): create a dummy using your character's model.
- `/dummyfallover`: leave the targeted dummy ragdolled for dragging tests.
- `/dummydown`: put it in critical condition for damage-immunity tests.
- `/dummyrevive`: heal and revive the targeted dummy, or all dummies if none is targeted.
- `/dummyheal`, `/dummybring`, `/dummyremove`: existing all-dummy controls.

Restart the game session after installation to load the new plugin on both realms.

## Validation

`node tools/run-body-drag-tests.cjs` covers movement, IK limb lengths, right-arm isolation, ARC9 ordering, reload guards, server authorization, collisions, release paths, critical damage immunity, timed finishing actions and dummy commands using mocked engine boundaries. The new suites are also included in `node tools/test.cjs`.

In-game checks remain necessary for physical grip stability and animation appearance. Test forward/backward/sideways travel, corners, crouching, gun switching, an empty magazine, reload after release, revival while held, and both E-menu finishing actions. Critical damage should cause no death; ordinary fallovers are still subject to the normal health rules.
