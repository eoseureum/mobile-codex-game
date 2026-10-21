"""Run after exporting Web. Checks the actual Godot WASM, not a JavaScript substitute."""
import http.server,socketserver,threading,json
from pathlib import Path
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
class Handler(http.server.SimpleHTTPRequestHandler):
 def __init__(self,*a,**kw):super().__init__(*a,directory=str(root/'build/web'),**kw)
 def log_message(self,*a):pass
server=socketserver.TCPServer(('127.0.0.1',0),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
 page=browser.new_page(viewport={'width':390,'height':844},is_mobile=True,has_touch=True)
 errors=[];messages=[];page.on('pageerror',lambda e:errors.append(str(e)));page.on('console',lambda m:messages.append(m.text))
 page.goto(f'http://127.0.0.1:{server.server_address[1]}/index.html');page.wait_for_function('!document.querySelector("#status") || document.querySelector("#status").style.display === "none"',timeout=90000)
 page.wait_for_timeout(2500);page.screenshot(path='/tmp/rust-godot-portrait.png')
 assert not errors,errors
 assert page.locator('#canvas').is_visible()
 motion_before=page.screenshot(clip={'x':36,'y':366,'width':54,'height':62})
 page.wait_for_timeout(500);page.screenshot(path='/tmp/rust-motion-next.png')
 assert motion_before!=page.screenshot(clip={'x':36,'y':366,'width':54,'height':62}), 'logging machinery must visibly move'
 print('PASS actual production machinery animation')
 print('PASS actual single-threaded Godot Web boot')
 page.touchscreen.tap(196,397);page.wait_for_timeout(500);page.screenshot(path='/tmp/rust-pixel-facility.png')
 page.touchscreen.tap(340,792);page.wait_for_timeout(300)
 page.touchscreen.tap(268,792);page.wait_for_timeout(300)
 page.touchscreen.tap(214,526);page.wait_for_timeout(200)
 page.touchscreen.tap(195,526);page.touchscreen.tap(260,526);page.wait_for_timeout(400)
 page.screenshot(path='/tmp/rust-world-route-preview.png')
 page.touchscreen.tap(310,557);page.wait_for_timeout(400)
 page.screenshot(path='/tmp/rust-world-route-committed.png')
 page.touchscreen.tap(48,792);page.wait_for_timeout(600);page.screenshot(path='/tmp/rust-godot-settings.png')
 with page.expect_download() as download:
  page.touchscreen.tap(195,555)
 saved=json.loads(Path(download.value.path()).read_text())
 assert saved['state']['cash']>=300 and len(saved['state']['entities'])==7 and saved['state']['world']['width']==128
 assert saved['state']['totals']['produced'].get('log',0)>0
 assert any(e['kind']=='belt' and e['x']==65 and e['y']==66 for e in saved['state']['entities'].values())
 print('PASS two-tap conveyor preview, confirmation and actual factory backup export')
 page.wait_for_timeout(10000);page.reload()
 page.wait_for_function('!document.querySelector("#status") || document.querySelector("#status").style.display === "none"',timeout=90000)
 page.wait_for_timeout(1500);page.touchscreen.tap(48,792);page.wait_for_timeout(400)
 with page.expect_download() as download:
  page.touchscreen.tap(195,555)
 reloaded=json.loads(Path(download.value.path()).read_text())
 assert reloaded['state']['clock']['elapsedS']>=8,reloaded['state']['clock']
 assert reloaded['state']['cash']>=saved['state']['cash']
 print('PASS Web persistent save survives reload')
 page.touchscreen.tap(340,792);page.wait_for_timeout(300)
 page.set_viewport_size({'width':960,'height':540});page.wait_for_timeout(800);page.screenshot(path='/tmp/rust-godot-landscape.png')
 print('PASS landscape/portrait render')
 errors += [m for m in messages if 'SCRIPT ERROR' in m or m.startswith('ERROR:')]
 print('CONSOLE',messages[-30:])
 assert not errors,errors
 browser.close()
server.shutdown()
