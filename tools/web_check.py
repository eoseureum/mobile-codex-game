"""Run after exporting Web. Checks the actual Godot WASM, not a JavaScript substitute."""
import http.server,socketserver,threading,json,os,subprocess,io
from PIL import Image
from pathlib import Path
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
catalog=json.loads((root/'data/catalog.json').read_text())
subprocess.run([os.environ.get('GODOT_BIN','godot'),'--headless','--path',str(root),'--script','tools/prepare_opening_check.gd'],check=True)
subprocess.run([os.environ.get('GODOT_BIN','godot'),'--headless','--path',str(root),'--script','tools/prepare_conveyor_check.gd'],check=True)
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
 page.screenshot(path='/tmp/rust-first-camp.png')
 page.wait_for_timeout(700)
 page.touchscreen.tap(340,792);page.wait_for_timeout(300)
 motion_before=page.screenshot(clip={'x':168,'y':366,'width':54,'height':62})
 page.wait_for_timeout(500)
 assert motion_before!=page.screenshot(clip={'x':168,'y':366,'width':54,'height':62}), 'logging machinery must visibly move'
 print('PASS paid touch construction and production machinery animation',flush=True)
 page.wait_for_timeout(4500)
 saved=backup()
 assert len(saved['state']['entities'])==1 and saved['state']['world']['width']==128
 assert saved['state']['cash']>=catalog['resources']['log']['price'] and saved['state']['totals']['produced'].get('log',0)>0
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
  chooser.value.set_files(str(root/'build/fixtures'/name))
  # FileReader and the Godot frame can lag under CPU load. Wait for the real
  # canvas dialog before sending its confirmation key.
  for _ in range(120):
   pixel=Image.open(io.BytesIO(page.screenshot(clip={'x':195,'y':330,'width':1,'height':1}))).convert('RGB').getpixel((0,0))
   if pixel==(64,64,64):break
   page.wait_for_timeout(100)
  else:raise AssertionError('backup replacement dialog did not appear')
  page.keyboard.press('Enter');page.wait_for_timeout(650)
 import_paid_fixture('opening-ready.json')
 page.touchscreen.tap(196,397);page.wait_for_timeout(400)
 page.screenshot(path='/tmp/rust-opening-ready.png')
 page.touchscreen.tap(326,397);page.wait_for_timeout(650)
 page.screenshot(path='/tmp/rust-opening-sawmill.png')
 line=backup()['state']
 assert len(line['entities'])==3 and any(e['kind']=='sawmill' and e['x']==64 for e in line['entities'].values()),line
 assert any(e['kind']=='belt' and e['x']==63 for e in line['entities'].values())
 assert line['cash']==line['totals']['earned']-catalog['facilities']['sawmill']['cost']-catalog['facilities']['belt']['cost']
 print('PASS ghost preview builds a paid sawmill and physical conveyor',flush=True)
 page.touchscreen.tap(340,792);page.wait_for_timeout(250)
 import_paid_fixture('warehouse-ready.json')
 page.touchscreen.tap(326,397);page.wait_for_timeout(350)
 page.screenshot(path='/tmp/rust-opening-shipping-ready.png')
 page.touchscreen.tap(300,696);page.wait_for_timeout(650)
 shipping=backup()['state']
 assert len(shipping['entities'])==5 and any(e['kind']=='warehouse' and e['x']==66 for e in shipping['entities'].values()),shipping
 assert shipping['cash']==shipping['totals']['earned']-catalog['facilities']['sawmill']['cost']-catalog['facilities']['warehouse']['cost']-2*catalog['facilities']['belt']['cost']
 print('PASS contextual shipping expansion completes the paid factory line',flush=True)
 import_paid_fixture('conveyor-flow.json')
 page.touchscreen.tap(196,397);page.wait_for_timeout(400)
 page.screenshot(path='/tmp/rust-conveyor-flow.png')
 moving=page.screenshot(clip={'x':95,'y':315,'width':220,'height':115})
 samples=[]
 for _ in range(12):
  page.wait_for_timeout(137)
  samples.append(page.screenshot(clip={'x':95,'y':315,'width':220,'height':115}))
 assert any(frame!=moving for frame in samples), 'resource sprites must visibly move across a full transport cadence'
 merged=backup()['state']
 destination=next(e for e in merged['entities'].values() if e['x']==68 and e['y']==66)
 assert destination['inventory'].get('log',0)>0 and destination['inventory'].get('coal',0)>0,destination
 import_paid_fixture('conveyor-jam.json')
 page.touchscreen.tap(196,397);page.wait_for_timeout(400)
 page.screenshot(path='/tmp/rust-conveyor-jam.png')
 jammed=backup()['state']
 loaded=[e for e in jammed['entities'].values() if e['kind']=='belt' and e['y']==66]
 assert any(e['queue'] for e in loaded) and all(len(e['queue'])<=4 for e in loaded),loaded
 print('PASS mixed-resource conveyor merge, visible item motion and blocked cargo',flush=True)
 import_paid_fixture('opening-ready.json')
 page.touchscreen.tap(196,397);page.wait_for_timeout(400)
 page.touchscreen.tap(271,648);page.wait_for_timeout(500)
 rotated=backup()['state']
 assert rotated['entities']['e1']['direction']==2,rotated['entities']['e1']
 page.touchscreen.tap(340,792);page.wait_for_timeout(300)
 page.touchscreen.tap(196,397);page.wait_for_timeout(350)
 page.touchscreen.tap(333,648);page.wait_for_timeout(500)
 removed=backup()['state']
 assert not removed['entities'] and removed['factory']['pioneerForestId']=='',removed
 assert removed['cash']==2250+removed['totals']['earned'],removed
 print('PASS one-touch rotation and demolition, exact refund and valid exported save',flush=True)
 errors += [m for m in messages if 'SCRIPT ERROR' in m or m.startswith('ERROR:')]
 print('CONSOLE',messages[-30:])
 assert not errors,errors
 browser.close()
server.shutdown()
