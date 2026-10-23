"""Check elapsed production in actual Godot WASM across browser suspension and reload.

Run after Web export. No campaign replay or JavaScript replacement simulation.
"""
import http.server
import json
import os
from pathlib import Path
import socketserver
import time
import threading
import urllib.parse
import urllib.request

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]


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
    context = browser.new_context(viewport={"width": 390, "height": 844}, is_mobile=True, has_touch=True)
    page = context.new_page()
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

    tap(195, 560, 600)
    before = backup()
    other = context.new_page()
    other.set_content("<title>Other tab</title>Reading another tab")
    other.bring_to_front()
    session = context.new_cdp_session(page)
    # Headless Chromium keeps both tabs visible. Freeze the real runtime to
    # exercise suspension without assuming bring_to_front sends visibility events.
    started = time.monotonic()
    session.send("Page.setWebLifecycleState", {"state": "frozen"})
    other.wait_for_timeout(12500)
    session.send("Page.setWebLifecycleState", {"state": "active"})
    page.bring_to_front()
    page.wait_for_timeout(700)
    after = backup()
    elapsed = after["clock"]["elapsedS"] - before["clock"]["elapsedS"]
    real_elapsed = time.monotonic() - started
    assert elapsed >= 12 and abs(elapsed - real_elapsed) < 3, (elapsed, real_elapsed)
    camp = lambda state: next(e for e in state["entities"].values() if e["kind"] == "forest")
    assert camp(after)["outputs"].get("log", 0) >= camp(before)["outputs"].get("log", 0) + 2, after
    assert after["cash"] == 0 and not after["bag"], after
    print(f"PASS frozen Web runtime recovers {elapsed:.2f}s after {real_elapsed:.2f}s away, before any industry unlock", flush=True)

    # This is a real browser reload: pagehide must save the accounted state,
    # title time must stay pending, and Continue must restore only the chosen city.
    started = time.monotonic()
    page.reload()
    page.wait_for_function('!document.querySelector("#status") || document.querySelector("#status").style.display === "none"', timeout=90000)
    page.wait_for_timeout(12500)
    tap(195, 628)
    tap(326, 146, 600)
    resumed = backup()
    real_elapsed = time.monotonic() - started
    elapsed = resumed["clock"]["elapsedS"] - after["clock"]["elapsedS"]
    assert resumed["world"]["seed"] == before["world"]["seed"], resumed
    assert elapsed >= 12 and abs(elapsed - real_elapsed) < 4, (elapsed, real_elapsed)
    assert camp(resumed)["outputs"].get("log", 0) >= camp(after)["outputs"].get("log", 0) + 2, resumed
    assert resumed["cash"] == 0 and not resumed["bag"], resumed
    print(f"PASS reload/Continue recovers {elapsed:.2f}s after {real_elapsed:.2f}s, with no phantom collection or cash", flush=True)
    page.screenshot(path="/tmp/rust-city-background-restored.png")
    if public_url:
        errors = [error for error in errors if error != "Unable to load a worklet's module."]
    assert not errors, errors
    print("PASS actual exported Web background recovery and reload without engine errors", flush=True)
    browser.close()
server.shutdown()
