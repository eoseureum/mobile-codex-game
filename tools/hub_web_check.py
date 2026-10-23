"""Prove central-hub controls with touch events in the actual Godot Web export.

Run after Web export. No campaign replay or JavaScript replacement simulation.
"""
import http.server
import json
import os
from pathlib import Path
import socketserver
import subprocess
import threading
import urllib.parse
import urllib.request

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
subprocess.run([os.environ.get("GODOT_BIN", "godot"), "--headless", "--path", str(ROOT),
                "--script", "tests/test_sales_hub_ui.gd", "--", "--web-fixture"], check=True)


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT / "build/web"), **kwargs)

    def log_message(self, *_args):
        pass


server = socketserver.TCPServer(("127.0.0.1", 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path="/usr/bin/chromium", headless=True,
        args=["--no-sandbox", "--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
    page = browser.new_page(viewport={"width": 390, "height": 844}, is_mobile=True, has_touch=True)
    errors = []
    page.on("pageerror", lambda e: errors.append(str(e)))
    page.on("console", lambda m: errors.append(m.text) if "SCRIPT ERROR" in m.text or m.text.startswith("ERROR:") else None)
    public_url = os.environ.get("RUST_CITY_TEST_URL")
    if public_url:
        origin = urllib.parse.urlsplit(public_url)
        if origin.scheme != "https":
            raise ValueError("Public checks require HTTPS")
        def fetch(route):
            url = route.request.url
            if origin.query:
                url += ("&" if "?" in url else "?") + urllib.parse.urlencode({"verify_build": origin.query})
            request = urllib.request.Request(url, headers={"Accept-Encoding": "identity"})
            with urllib.request.urlopen(request, timeout=90) as response:
                headers = {key: value for key, value in response.headers.items()
                           if key.lower() not in ["transfer-encoding", "connection"]}
                route.fulfill(status=response.status, headers=headers, body=response.read())
        page.context.route(f"https://{origin.netloc}/**", fetch)
    page.goto(public_url or f"http://127.0.0.1:{server.server_address[1]}/index.html")
    page.wait_for_function('!document.querySelector("#status") || document.querySelector("#status").style.display === "none"', timeout=90000)
    page.wait_for_timeout(1200)

    def tap(x, y, delay=300):
        page.touchscreen.tap(x, y)
        page.wait_for_timeout(delay)

    def backup():
        tap(48, 792)
        with page.expect_download() as download:
            tap(195, 605)
        state = json.loads(Path(download.value.path()).read_text())["state"]
        tap(340, 792)
        return state

    def import_fixture(name):
        tap(48, 792)
        with page.expect_file_chooser() as chooser:
            tap(195, 660)
        chooser.value.set_files(str(ROOT / "build/fixtures" / name))
        # A backup becomes a separate city; no existing world is replaced.
        page.wait_for_timeout(1000)

    page.screenshot(path="/tmp/rust-city-start-screen-390.png")
    for width, height in [(320, 568), (844, 320), (390, 844)]:
        page.set_viewport_size({"width": width, "height": height})
        page.wait_for_timeout(400)
        page.screenshot(path=f"/tmp/rust-city-start-screen-{width}.png")
    tap(195, 560, 600)
    start = backup()
    assert start["cash"] == 0 and len(start["entities"]) == 2, start
    hub = next(e for e in start["entities"].values() if e.get("salesHub"))
    assert hub["salesHub"] and hub["investedCash"] == 0, hub
    page.screenshot(path="/tmp/rust-city-hub-opening.png")
    tap(97, 397)
    page.screenshot(path="/tmp/rust-city-hub-camp.png")
    for _ in range(12):
        page.wait_for_timeout(2000)
        before_collect = backup()
        camp = next(e for e in before_collect["entities"].values() if e["kind"] == "forest")
        if camp["outputs"].get("log", 0) > 0:
            break
    assert before_collect["cash"] == 0 and camp["outputs"].get("log", 0) > 0, before_collect
    tap(97, 397)
    tap(310, 605)
    collected = backup()
    assert collected["bag"].get("log", 0) > 0 and collected["cash"] == 0, collected
    print("PASS prebuilt camp, retained production and fixed collection control", flush=True)
    tap(340, 48)
    page.screenshot(path="/tmp/rust-city-hub-bag.png")
    tap(320, 674)
    tap(324, 640)
    sold = backup()
    assert sold["cash"] >= 35 and sold["bag"].get("log", 0) == 0, sold
    assert any(r["type"] == "first_sale" for r in sold["records"]), sold
    print("PASS bag focus, hub-only sell-all touch and exact physical inventory removal", flush=True)

    import_fixture("hub-ready.json")
    tap(97, 397)
    tap(310, 605)
    tap(292, 397)
    tap(324, 640)
    tap(97, 397)
    tap(312, 710, 650)
    automated = backup()
    assert automated["entities"]["e3"]["kind"] == "belt" and automated["entities"]["e4"]["kind"] == "belt", automated
    assert automated["entities"]["e3"]["x"] == 63 and automated["entities"]["e4"]["x"] == 64, automated
    assert automated["cash"] >= 25, automated
    print("PASS 150-cash touch shortcut constructs the two physical conveyors to hub perimeter", flush=True)

    import_fixture("hub-inline.json")
    before_inline = backup()
    tap(97, 397)
    tap(312, 710, 500)
    page.screenshot(path="/tmp/rust-city-recipe-preview.png")
    page.screenshot(path="/tmp/rust-city-hub-recipe.png")
    for width, height in [(320, 568), (844, 320)]:
        page.set_viewport_size({"width": width, "height": height})
        page.wait_for_timeout(500)
        page.screenshot(path=f"/tmp/rust-city-recipe-preview-{width}.png")
    page.set_viewport_size({"width": 390, "height": 844})
    page.wait_for_timeout(500)
    page.keyboard.press("Escape")
    page.wait_for_timeout(300)
    canceled = backup()
    assert canceled["entities"]["e4"]["kind"] == "belt", canceled
    tap(97, 397)
    tap(312, 710, 500)
    page.keyboard.press("Enter")
    page.wait_for_timeout(500)
    inserted = backup()
    assert inserted["entities"]["e4"]["kind"] == "sawmill", inserted
    assert inserted["entities"]["e4"]["direction"] == before_inline["entities"]["e4"]["direction"], inserted
    assert inserted["entities"]["e4"]["investedCash"] == 775, inserted
    for _ in range(12):
        page.wait_for_timeout(2000)
        flowing = backup()
        if flowing["totals"]["sold"].get("plank", 0) > 0:
            break
    assert flowing["totals"]["sold"].get("plank", 0) > 0, flowing
    print("PASS first recipe preview cancels atomically, installs one 700-cash inline sawmill and retains automatic sales", flush=True)

    import_fixture("hub-stacks.json")
    # Six stacks: the first hub page has four actions, the next has two.
    tap(292, 397)
    page.screenshot(path="/tmp/rust-city-hub-stacks-390.png")
    tap(335, 694)
    page.screenshot(path="/tmp/rust-city-hub-page-two.png")
    tap(170, 632)
    stack_sale = backup()
    assert stack_sale["bag"].get("copper", 0) == 0 and stack_sale["bag"].get("iron", 0) == 6, stack_sale
    print("PASS paginated stack sale affects only the touched resource", flush=True)
    tap(292, 397)
    # Upgrade and bag screens must stay fully usable after viewport rotation.
    for width, height in [(320, 568), (844, 320), (390, 844)]:
        page.set_viewport_size({"width": width, "height": height})
        page.wait_for_timeout(600)
        page.screenshot(path=f"/tmp/rust-city-hub-stacks-{width}.png")
    page.set_viewport_size({"width": 390, "height": 844})
    page.wait_for_timeout(500)
    import_fixture("hub-legacy.json")
    migrated = backup()
    assert migrated["factory"]["economyVersion"] == 2, migrated
    assert not any(e["kind"] == "warehouse" for e in migrated["entities"].values()), migrated
    assert migrated["bag"].get("log", 0) == 19 and migrated["bag"].get("plank", 0) == 3, migrated
    assert sum(bool(e.get("salesHub")) for e in migrated["entities"].values()) == 1, migrated
    print("PASS actual legacy backup import upgrades before play and conserves warehouse stock in personal bag", flush=True)
    tap(48, 792);tap(195, 716)
    tap(195, 560, 600)
    another = backup()
    assert another["cash"] == 0 and not another["bag"] and len(another["entities"]) == 2, another
    assert all(not e["outputs"] for e in another["entities"].values()), another
    print("PASS title New creates a separate zero-cash world with no inherited wood", flush=True)
    tap(48, 792);tap(195, 716)
    # Reload only after the real browser database contains the newly saved slot.
    page.wait_for_function("""async () => new Promise(resolve => {
        const request = indexedDB.open('/userfs');
        request.onerror = () => resolve(false);
        request.onsuccess = () => {
            const db = request.result;
            if (!db.objectStoreNames.contains('FILE_DATA')) { db.close(); resolve(false); return; }
            const cursor = db.transaction('FILE_DATA', 'readonly').objectStore('FILE_DATA').openCursor();
            cursor.onsuccess = () => {
                const item = cursor.result;
                if (!item) { db.close(); resolve(false); return; }
                if (String(item.key).endsWith('/world_6.json')) {
                    try {
                        const saved = JSON.parse(new TextDecoder().decode(item.value.contents));
                        db.close(); resolve(saved.state.cash === 0); return;
                    } catch (error) { db.close(); resolve(false); return; }
                }
                item.continue();
            };
        };
    })""", timeout=20000)
    def saved_slots():
        return page.evaluate(r"""() => new Promise((resolve, reject) => {
            const request = indexedDB.open('/userfs');
            request.onerror = () => reject(request.error);
            request.onsuccess = () => {
                const db = request.result, values = [];
                const tx = db.transaction('FILE_DATA', 'readonly');
                tx.objectStore('FILE_DATA').openCursor().onsuccess = event => {
                    const cursor = event.target.result;
                    if (!cursor) return;
                    if (/\/world_[0-9]+\.json$/.test(String(cursor.key))) {
                        const saved = JSON.parse(new TextDecoder().decode(cursor.value.contents));
                        values.push({id: String(cursor.key).split('/').pop(), cash: saved.state.cash,
                            bag: saved.state.bag, savedAtMs: saved.savedAtMs});
                    }
                    cursor.continue();
                };
                tx.oncomplete = () => { db.close(); resolve(values); };
                tx.onerror = () => { db.close(); reject(tx.error); };
            };
        })""")
    before_reload = saved_slots()
    assert len(before_reload) == 6, before_reload
    page.reload()
    page.wait_for_function('!document.querySelector("#status") || document.querySelector("#status").style.display === "none"', timeout=90000)
    page.wait_for_timeout(800)
    after_reload = saved_slots()
    assert len(after_reload) == 6, (before_reload, after_reload)
    tap(195, 628)
    page.screenshot(path="/tmp/rust-city-saved-worlds-390.png")
    # Newest world is first; choose the previous city in the second row.
    tap(326, 270, 600)
    resumed = backup()
    assert resumed["bag"].get("log", 0) == 19 and resumed["bag"].get("plank", 0) == 3, resumed
    print("PASS browser reload starts at title and Continue restores the selected older world", flush=True)
    if public_url:
        # Intercepting HTTPS through the verified session proxy can prevent
        # Chromium's AudioWorklet module loading; game/script errors stay fatal.
        errors = [error for error in errors if error != "Unable to load a worklet's module."]
    assert not errors, errors
    print("PASS actual Web hub pagination and 390/320/landscape rendering without script errors", flush=True)
    browser.close()
server.shutdown()
