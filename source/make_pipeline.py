import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
TEMPLATE = HERE / 'first-last-template.vpipeline'
pipe = json.loads(TEMPLATE.read_text())
pipe['id'] = 'silver-u7-mountain-road-entrance'

def stage(name):
    return next(s for s in pipe['stages'] if s['id'] == name)

stage('load-image')['id'] = 'load-first-image'
stage('load-first-image')['config']['url'] = [str(HERE / 'first-empty-road.png')]
stage('first-frame')['iports'][0]['src'] = 'load-first-image'

last_loader = {
    'id': 'load-last-image',
    'type': 'load-image',
    'iports': [],
    'config': {'url': [str(HERE / 'last-silver-u7.jpg')]},
}
pipe['stages'].insert(3, last_loader)
stage('last-frame')['iports'][0]['src'] = 'load-last-image'
stage('last-frame')['config'] = {'width': 960, 'height': 544, 'fit': 'crop', 'algorithm': 'lanczos'}

stage('text-prompt')['config']['text'] = (
    'One continuous photorealistic premium automotive commercial shot, about five seconds. '
    'The first supplied frame is the exact empty mountain road at the beginning. '
    'The last supplied frame is the exact final composition and the identity anchor for a '
    'moonlight-silver Yangwang U7 sedan. The same silver U7 drives into view from the distant '
    'left-hand bend, follows the curved lane toward the low camera, and grows naturally in '
    'frame until it reaches the precise front-three-quarter position and scale of the last '
    'frame. The wheels visibly rotate, the body stays rigid and proportionally correct, '
    'reflections and shadows follow the sunny mountain-road lighting. The camera has the '
    'same tilted low tracking angle as both reference frames, with a smooth restrained '
    'commercial camera move. Match the final supplied frame closely: U7 headlamps, hood, '
    'side profile, silver paint, front plate, wheels, mountain, curved lane markings and '
    'white building. Preserve the mountain and road geometry through the shot. '
    'No cuts, no teleporting or morphing car, no changing badges, no extra wheels, '
    'no other vehicles, no people, no captions, no computer interface. '
    'Audio: subtle tire sound on asphalt and restrained electric vehicle ambience; no music or speech.'
)
stage('generate-video')['config'].update({'frames': 124, 'fps': 24, 'steps': 6, 'seed': 47})
stage('save-video')['config']['output_url'] = str(HERE / 'u7-entrance-test.mp4')

(HERE / 'u7-entrance.vpipeline').write_text(json.dumps(pipe, ensure_ascii=False, indent=2) + '\n')
(HERE / 'prompt.txt').write_text(stage('text-prompt')['config']['text'] + '\n')
print(HERE / 'u7-entrance.vpipeline')
