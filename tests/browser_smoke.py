"""Exercise the exported game, without adding test hooks to production scripts.

Requires playwright and Pillow; serve build/web over localhost first.
"""

import argparse
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageChops
from playwright.sync_api import sync_playwright


def capture(page):
    return Image.open(BytesIO(page.screenshot())).convert("RGB")


def assert_centered(image):
    x, y = image.width // 2, image.height // 2
    sample = image.crop((x - 8, y - 8, x + 8, y + 8))
    pixels = [sample.getpixel((px, py)) for py in range(16) for px in range(16)]
    assert any(r > 190 and g > 220 and b > 190 for r, g, b in pixels), (
        "Explorer must remain visible at screen center"
    )


def assert_world_moved(before, after):
    # Exclude title, player, destination marker and bottom instruction panel.
    box = (20, before.height // 3, before.width // 3, 2 * before.height // 3)
    diff = ImageChops.difference(before.crop(box), after.crop(box))
    assert sum(diff.tobytes()) > 1000, "Input must move the world under the camera"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:8060")
    parser.add_argument("--chromium", default="/usr/bin/chromium")
    parser.add_argument("--output", default="build/screenshots")
    args = parser.parse_args()
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=args.chromium,
            args=["--no-sandbox", "--enable-unsafe-swiftshader"],
        )
        print("Chromium", browser.version)
        for name, width, height, mobile in [
            ("desktop", 960, 540, False),
            ("iphone-portrait", 390, 844, True),
            ("small-portrait", 320, 568, True),
        ]:
            context = browser.new_context(
                viewport={"width": width, "height": height},
                device_scale_factor=1,
                is_mobile=mobile,
                has_touch=mobile,
            )
            page = context.new_page()
            errors = []
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.on("console", lambda msg: errors.append(msg.text) if msg.type == "error" else None)
            page.goto(args.url)
            page.wait_for_function("!document.getElementById('status')", timeout=60000)
            page.wait_for_timeout(1000)
            before = capture(page)
            assert before.size == (width, height)
            assert_centered(before)
            assert page.locator("canvas").bounding_box() == {
                "x": 0, "y": 0, "width": width, "height": height
            }, "Canvas must fill viewport"
            # First interaction along the open horizontal path.
            target = (width // 2 + width // 5, height // 2)
            if mobile:
                page.touchscreen.tap(*target)
            else:
                page.mouse.click(*target)
            page.wait_for_timeout(1800)
            after = capture(page)
            assert_centered(after)
            assert_world_moved(before, after)
            after.save(output / f"{name}.png")
            # Repeated input after camera movement must still work.
            target = (width // 2, height // 2 + height // 8)
            if mobile:
                page.touchscreen.tap(*target)
            else:
                page.mouse.click(*target)
            page.wait_for_timeout(1500)
            assert_centered(capture(page))
            if mobile:
                page.set_viewport_size({"width": height, "height": width})
                page.wait_for_timeout(1000)
                rotated = capture(page)
                assert rotated.size == (height, width)
                assert_centered(rotated)
                page.touchscreen.tap(height // 2 + 60, width // 2)
                page.wait_for_timeout(1200)
                assert_centered(capture(page))
                page.screenshot(path=str(output / f"{name}-rotated.png"))
            assert page.evaluate("!crossOriginIsolated"), "Smoke test should work without COOP/COEP headers"
            assert not errors, errors
            print(f"PASS {name}: render, input, camera, canvas fit" + (", rotate and tap" if mobile else ""))
            context.close()
        browser.close()


if __name__ == "__main__":
    main()
