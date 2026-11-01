from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
p=ROOT/'tools/build-facility-guide.cjs'
s=p.read_text(encoding='utf-8')
s=s.replace('It goes out when its zone has no power, including remote isolation.',
 'It turns red when the box is offline or damaged, including remote isolation, and green only when powered and intact.')
s=s.replace('A connected generator can restore the lamp during a mains failure, but cannot bypass isolation.',
 'A connected generator can return an intact box’s lamp to green during a mains failure, but cannot bypass isolation.')
p.write_text(s,encoding='utf-8')
s=(ROOT/'tools/package-powerbox-calibration.py').read_text(encoding='utf-8')
s=s.replace('powerbox-calibration','powerbox-indicator').replace('Powerbox-Calibration-Cables','Powerbox-Indicator')
s=s.replace('docs/skills-powerbox-manifest.json','docs/powerbox-calibration-manifest.json')
s=s.replace('HL2RP-Powerbox-Indicator-20261008.zip','HL2RP-Powerbox-Five-Stage-20261008.zip').replace('< 422','< 424')
(ROOT/'tools/package-powerbox-indicator.py').write_text(s,encoding='utf-8')
