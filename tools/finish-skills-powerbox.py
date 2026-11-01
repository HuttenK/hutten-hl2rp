from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
guide=ROOT/'tools/build-facility-guide.cjs'
text=guide.read_text(encoding='utf-8')
text=text.replace('The lamp goes out when its zone has no power, including remote isolation.',
 'Both screwdriver items (<code>tool_screw</code> and <code>wm_screwdriver</code>) work. Check Electronics and all other skills in <b>TAB → Личность</b>, beside the medical overview. The skills column shows levels, XP progress and bonuses; hover for descriptions. The lamp is mounted on the internal gauge face and is visible when the door is open. It goes out when its zone has no power, including remote isolation.')
text=text.replace('<code>facility_spares</code>, <code>wm_screwdriver</code>.', '<code>facility_spares</code>, <code>tool_screw</code> or <code>wm_screwdriver</code>.')
guide.write_text(text,encoding='utf-8')
package=(ROOT/'tools/package-powerbox-interaction.py').read_text(encoding='utf-8')
package=package.replace('powerbox-interaction','skills-powerbox').replace('Powerbox-Interaction','Skills-Powerbox')
package=package.replace('docs/powerbox-blackout-manifest.json','docs/powerbox-interaction-manifest.json')
package=package.replace('< 410','< 415')
(ROOT/'tools/package-skills-powerbox.py').write_text(package,encoding='utf-8')
print('Updated guide source and packaging script.')
