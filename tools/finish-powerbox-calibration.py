from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
p=ROOT/'tools/build-facility-guide.cjs';s=p.read_text(encoding='utf-8')
s=s.replace('start the existing screwdriver repair (Electronics 3) or sabotage (Electronics 4)',
 'open the three-contact repair minigame (Electronics 3) or sabotage minigame (Electronics 4)')
s=s.replace('The lamp is mounted on the internal gauge face and is visible when the door is open.',
 'Press Space or the contact button in the marked zone three times; Escape cancels. Powerbox work needs no spare parts or card and preserves your screwdriver. Stay near the open box with the required tool and skill. The original soft green/red glow is mounted on the internal gauge face and is visible when the door is open.')
cable='<h3>Cable attachment</h3><p>Click the exact spot on the target prop. The attachment follows that prop and persists after reload. Cables hang with slack and stop above map floors. Disconnect and reconnect old cables to select a new attachment point.</p>'
s=s.replace(cable,'')
s=s.replace('<h3>Battery: leave it alone</h3>',cable+'<h3>Battery: leave it alone</h3>')
# Keep the older overview from contradicting the implemented powerbox minigame.
s=s.replace('Fuseboxes keep their existing skill/tool repair rules.', 'Fuseboxes use the same three-contact minigame with Electronics 3 for repair or 4 for sabotage; no spare parts are required.')
s=s.replace('Use the box’s existing repair action','Open the door; E on the inner panel')
s=s.replace('Screwdriver + blackout electrical-skill rules / currently 30 sec. No facility parts kit.',
 'Either screwdriver + Electronics 3 (repair) / 4 (sabotage). Three contacts, 90-second timeout. No card or parts kit.')
p.write_text(s,encoding='utf-8')
s=(ROOT/'tools/package-skills-powerbox.py').read_text(encoding='utf-8')
s=s.replace('skills-powerbox','powerbox-calibration').replace('Skills-Powerbox','Powerbox-Calibration-Cables')
s=s.replace('docs/powerbox-interaction-manifest.json','docs/skills-powerbox-manifest.json').replace('< 415','< 422')
(ROOT/'tools/package-powerbox-calibration.py').write_text(s,encoding='utf-8')
print('Guide and package setup updated.')
