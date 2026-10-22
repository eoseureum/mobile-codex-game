"""Exercise real multi-touch against exported Godot WASM, without a product test API."""
import http.server, io, json, socketserver, threading
from pathlib import Path
from PIL import Image
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[1]
class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(root / 'build/web'), **kwargs)
    def log_message(self, *args):
        pass

server = socketserver.TCPServer(('127.0.0.1', 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True,
        args=['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'])
    page = browser.new_page(viewport={'width': 390, 'height': 844}, is_mobile=True, has_touch=True)
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.on('console', lambda m: errors.append(m.text) if 'SCRIPT ERROR' in m.text or m.text.startswith('ERROR:') else None)
    page.goto(f'http://127.0.0.1:{server.server_address[1]}/index.html')
    page.wait_for_function('!document.querySelector("#status") || document.querySelector("#status").style.display === "none"', timeout=90000)
    page.wait_for_timeout(1200)
    cdp = page.context.new_cdp_session(page)
    def touches(kind, points):
        cdp.send('Input.dispatchTouchEvent', {'type': kind, 'touchPoints': [
            {'x': x, 'y': y, 'id': i} for i, x, y in points]})
        page.wait_for_timeout(50)
    def tree_bounds(center):
        frame = Image.open(io.BytesIO(page.screenshot())).convert('RGB')
        palette = {(84, 121, 77), (127, 163, 87), (162, 189, 107), (62, 98, 70)}
        pixels = [(x, y) for y in range(int(center[1]-65), int(center[1]+65))
                  for x in range(int(center[0]-60), int(center[0]+60)) if frame.getpixel((x, y)) in palette]
        assert pixels, 'the starter tree must remain visible'
        box = (min(x for x,y in pixels), min(y for x,y in pixels), max(x for x,y in pixels), max(y for x,y in pixels))
        return ((box[0]+box[2])/2, (box[1]+box[3])/2, box[2]-box[0]+1, box[3]-box[1]+1)
    before = tree_bounds((195,397))
    touches('touchStart', [(0,125,397), (1,265,397)])
    for n in range(1,9):
        touches('touchMove', [(0,125-35*n/8,397), (1,265+35*n/8,397)])
    spread = tree_bounds((195,397))
    assert abs(spread[3]/before[3]-1.5)<0.15, (before,spread)
    assert abs(spread[0]-(195+(before[0]-195)*1.5))<=3 and abs(spread[1]-(397+(before[1]-397)*1.5))<=3, (before,spread)
    for n in range(1,6):
        touches('touchMove', [(0,90+20*n/5,397+25*n/5), (1,300+20*n/5,397+25*n/5)])
    shifted = tree_bounds((215,422))
    assert abs(shifted[0]-spread[0]-20)<=3 and abs(shifted[1]-spread[1]-25)<=3, (spread,shifted)
    touches('touchEnd', [])
    page.screenshot(path='/tmp/rust-pinch-spread.png')
    touches('touchStart', [(0,110,422),(1,320,422)])
    for n in range(1,9):
        touches('touchMove', [(0,110+35*n/8,422),(1,320-35*n/8,422)])
    touches('touchEnd', [])
    small = tree_bounds((215,422))
    assert abs(small[3]-before[3])<=3, (before,small)
    assert page.evaluate('window.visualViewport.scale')==1, 'pinching must scale the map, not the browser page'
    touches('touchStart', [(0,195,350)])
    for n in range(1,6):
        touches('touchMove', [(0,195+30*n/5,350+25*n/5)])
    touches('touchEnd', [])
    moved = tree_bounds((245,447))
    assert abs(moved[0]-small[0]-30)<=3 and abs(moved[1]-small[1]-25)<=3, (small,moved)
    page.screenshot(path='/tmp/rust-pinch-pan.png')
    page.touchscreen.tap(48,792)
    page.wait_for_timeout(400)
    with page.expect_download() as download:
        page.touchscreen.tap(195,605)
    state=json.loads(Path(download.value.path()).read_text())['state']
    assert state['cash']==2250 and not state['entities'], 'gestures must never build or spend money'
    page.touchscreen.tap(340,792)
    page.wait_for_timeout(300)
    collapsed = page.screenshot(clip={'x':20,'y':540,'width':350,'height':200})
    page.touchscreen.tap(moved[0],moved[1])
    page.wait_for_timeout(400)
    assert collapsed!=page.screenshot(clip={'x':20,'y':540,'width':350,'height':200}), 'single tap must still open the tile card'
    page.screenshot(path='/tmp/rust-pinch-tap.png')
    assert not errors,errors
    print('PASS real WASM pinch scale, midpoint anchoring, two-finger pan, pinch in, page scale, single drag, no accidental spending and single tap',flush=True)
    print('TREE_BOUNDS',before,spread,shifted,small,moved,flush=True)
    browser.close()
server.shutdown()
