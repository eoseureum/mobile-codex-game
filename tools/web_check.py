"""Run after exporting Web. Checks the actual Godot WASM, not a JavaScript substitute."""
import http.server,socketserver,threading,json,os,subprocess
from pathlib import Path
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
subprocess.run([os.environ.get('GODOT_BIN','godot'),'--headless','--path',str(root),'--script','tools/prepare_opening_check.gd'],check=True)
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
 print('PASS actual single-threaded Godot Web boot',flush=True)
 def backup():
  page.touchscreen.tap(48,792);page.wait_for_timeout(400)
  with page.expect_download() as download:
   page.touchscreen.tap(195,605)
  return json.loads(Path(download.value.path()).read_text())
 empty=backup()['state']
 assert empty['cash']==2250 and not empty['entities'] and not empty['totals']['produced'],empty
 print('PASS empty city and exact first-camp budget',flush=True)
 page.touchscreen.tap(340,792);page.wait_for_timeout(300)
 page.touchscreen.tap(196,397);page.wait_for_timeout(400)
 page.touchscreen.tap(280,688);page.wait_for_timeout(400)
 page.screenshot(path='/tmp/rust-empty-confirm.png')
 page.touchscreen.tap(158,491);page.wait_for_timeout(700)
 page.touchscreen.tap(340,792);page.wait_for_timeout(300)
 motion_before=page.screenshot(clip={'x':168,'y':366,'width':54,'height':62})
 page.wait_for_timeout(500)
 assert motion_before!=page.screenshot(clip={'x':168,'y':366,'width':54,'height':62}), 'logging machinery must visibly move'
 print('PASS paid touch construction and production machinery animation',flush=True)
 page.wait_for_timeout(4500)
 saved=backup()
 assert len(saved['state']['entities'])==1 and saved['state']['world']['width']==128
 assert saved['state']['cash']>=50 and saved['state']['totals']['produced'].get('log',0)>0
 assert saved['state']['totals']['earned']==saved['state']['cash']
 assert saved['state']['entities']['e1']['investedCash']==2250
 assert any(s.get('entityId')=='e1' for s in saved['state']['recentSales'])
 print('PASS automatic sale of actual starter logs and reconciled cash',flush=True)
 page.wait_for_timeout(10000);page.reload()
 page.wait_for_function('!document.querySelector("#status") || document.querySelector("#status").style.display === "none"',timeout=90000)
 page.wait_for_timeout(1500);page.wait_for_timeout(400)
 reloaded=backup()
 assert reloaded['state']['clock']['elapsedS']>=8,reloaded['state']['clock']
 assert reloaded['state']['cash']>=saved['state']['cash']
 print('PASS Web persistent save survives reload')
 page.touchscreen.tap(340,792);page.wait_for_timeout(300)
 page.set_viewport_size({'width':960,'height':540});page.wait_for_timeout(800);page.screenshot(path='/tmp/rust-godot-landscape.png')
 print('PASS landscape/portrait render')
 page.set_viewport_size({'width':390,'height':844});page.wait_for_timeout(500)
 def import_paid_fixture(name):
  page.touchscreen.tap(48,792);page.wait_for_timeout(350)
  with page.expect_file_chooser() as chooser:
   page.touchscreen.tap(195,660)
  chooser.value.set_files(str(root/'build/fixtures'/name));page.wait_for_timeout(400)
  page.keyboard.press('Enter');page.wait_for_timeout(650)
 import_paid_fixture('opening-ready.json')
 page.touchscreen.tap(196,397);page.wait_for_timeout(400)
 page.screenshot(path='/tmp/rust-opening-ready.png')
 page.touchscreen.tap(326,397);page.wait_for_timeout(300);page.keyboard.press('Enter');page.wait_for_timeout(650)
 page.screenshot(path='/tmp/rust-opening-sawmill.png')
 line=backup()['state']
 assert len(line['entities'])==3 and any(e['kind']=='sawmill' and e['x']==64 for e in line['entities'].values()),line
 assert any(e['kind']=='belt' and e['x']==63 for e in line['entities'].values())
 assert line['cash']==line['totals']['earned']-1600
 print('PASS ghost preview builds a paid sawmill and physical conveyor',flush=True)
 page.touchscreen.tap(340,792);page.wait_for_timeout(250)
 import_paid_fixture('warehouse-ready.json')
 page.touchscreen.tap(326,397);page.wait_for_timeout(350)
 page.screenshot(path='/tmp/rust-opening-shipping-ready.png')
 page.touchscreen.tap(300,696);page.wait_for_timeout(300);page.keyboard.press('Enter');page.wait_for_timeout(650)
 shipping=backup()['state']
 assert len(shipping['entities'])==5 and any(e['kind']=='warehouse' and e['x']==66 for e in shipping['entities'].values()),shipping
 assert shipping['cash']==shipping['totals']['earned']-2150
 print('PASS contextual shipping expansion completes the paid factory line',flush=True)
 errors += [m for m in messages if 'SCRIPT ERROR' in m or m.startswith('ERROR:')]
 print('CONSOLE',messages[-30:])
 assert not errors,errors
 browser.close()
server.shutdown()
