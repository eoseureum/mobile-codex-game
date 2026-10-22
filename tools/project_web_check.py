"""Check warehouse-funded city construction in the real Godot Web export.

Optional RUST_CITY_TEST_URL checks a deployed build with the same fixture.
"""
import http.server
import io
import json
import os
from pathlib import Path
import socketserver
import subprocess
import threading
import urllib.request

from PIL import Image
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[1]
subprocess.run([os.environ.get("GODOT_BIN", "godot"), "--headless", "--path", str(root),
                "--script", "tests/test_project_stock.gd", "--", "--web-fixture"], check=True)


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(root / "build/web"), **kwargs)

    def log_message(self, *args):
        pass


server = socketserver.TCPServer(("127.0.0.1", 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
public_url = os.environ.get("RUST_CITY_TEST_URL")
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path="/usr/bin/chromium", headless=True,
        args=["--no-sandbox", "--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
    page = browser.new_page(viewport={"width": 390, "height": 844}, is_mobile=True, has_touch=True)
    if public_url:
        # Fetch through the configured, certificate-verified session proxy.
        def fetch(route):
            with urllib.request.urlopen(urllib.request.Request(route.request.url, headers={"Accept-Encoding": "identity"}), timeout=90) as response:
                headers = {k: v for k, v in response.headers.items() if k.lower() not in ["transfer-encoding", "connection"]}
                route.fulfill(status=response.status, headers=headers, body=response.read())
        page.context.route("https://eoseureum.github.io/**", fetch)
    errors = []
    page.on("pageerror", lambda e: errors.append(str(e)))
    page.on("console", lambda m: errors.append(m.text) if "SCRIPT ERROR" in m.text or m.text.startswith("ERROR:") else None)
    page.goto(public_url or f"http://127.0.0.1:{server.server_address[1]}/index.html")
    page.wait_for_function('!document.querySelector("#status") || document.querySelector("#status").style.display === "none"', timeout=90000)
    page.wait_for_timeout(1200)
    page.touchscreen.tap(48, 792)
    page.wait_for_timeout(300)
    with page.expect_file_chooser() as chooser:
        page.touchscreen.tap(195, 660)
    chooser.value.set_files(str(root / "build/fixtures/city-project.json"))
    for _ in range(120):
        pixel = Image.open(io.BytesIO(page.screenshot(clip={"x": 195, "y": 330, "width": 1, "height": 1}))).convert("RGB").getpixel((0, 0))
        if pixel == (64, 64, 64):
            break
        page.wait_for_timeout(100)
    else:
        raise AssertionError("Import dialog did not appear")
    page.keyboard.press("Enter")
    page.wait_for_timeout(500)

    def backup():
        page.touchscreen.tap(48, 792)
        page.wait_for_timeout(250)
        with page.expect_download() as download:
            page.touchscreen.tap(195, 605)
        state = json.loads(Path(download.value.path()).read_text())["state"]
        page.touchscreen.tap(340, 792)
        page.wait_for_timeout(250)
        return state

    state = backup()
    project = next(e for e in state["entities"].values() if e["kind"] == "cabin")
    assert project["project"]["materials"] == {"plank": 24}, project
    assert all(not e["inventory"] for e in state["entities"].values() if e["kind"] == "warehouse"), state
    # Asset loading and import catch-up can finish the 15-second project before
    # the first backup. Check simulated time rather than browser wall time.
    expected_remaining = max(0, 15 - state["clock"]["elapsedS"])
    assert project["project"]["remainingS"] == expected_remaining, project
    assert project["project"]["complete"] == (expected_remaining == 0), project
    assert len(state["entities"]) == 3, "Construction must not require a new source or belt"
    page.touchscreen.tap(196, 397)
    page.wait_for_timeout(300)
    page.screenshot(path="/tmp/rust-city-project-construction.png")
    print("PASS Web warehouse allocation and construction timer without conveyors", flush=True)
    page.wait_for_timeout(16000)
    state = backup()
    assert state["entities"][project["id"]]["project"]["complete"], state
    assert any(r["type"] == "complete_cabin" for r in state["records"]), state
    assert all(not e["inventory"] for e in state["entities"].values() if e["kind"] == "warehouse"), state
    print("PASS Web completion, city record and exact one-time material consumption", flush=True)
    if public_url:
        errors = [e for e in errors if e != "Unable to load a worklet's module."]
    assert not errors, errors
    browser.close()
server.shutdown()
