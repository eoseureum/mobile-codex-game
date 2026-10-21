# Rust City

작은 자동 벌목장에서 시작해 로켓을 발사하는 공장 운영 게임. Godot 4.5 / GDScript / Compatibility 렌더러를 사용하며, 아이폰 Safari에서 실행할 수 있는 단일 스레드 Web 빌드를 제공합니다.

## 개발과 실행

1. 이 저장소를 내려받고 **Godot 4.5**에서 `project.godot`을 엽니다.
2. F6 또는 F5로 실행합니다. 시작 장면은 `scenes/Main.tscn`입니다.
3. 지도는 드래그로 이동하고 오른쪽 플로팅 버튼으로 확대·축소합니다. 시설을 누르면 조작 카드가 열리고, 카드 윗부분을 드래그해 높이를 바꿀 수 있습니다. 하단 메뉴의 지도 버튼을 누르면 카드가 접힙니다.

통나무 생산, 가공, 운송, 판매는 자동입니다. 시작 자금은 ₩500이며 추가 제재소는 ₩1,500입니다. 생산 속도·운영 수익·매니저를 별도로 개선하고, 주문 출하와 도시 건설을 거쳐 산업·전력·우주 산업을 확장합니다. 미해금 항목은 `?`로 표시합니다.

## Web 빌드

Godot 4.5의 Export Templates를 설치한 뒤 프로젝트 폴더에서 실행합니다.

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script tests/test_runner.gd
godot --headless --path . -- --ui-check
godot --headless --path . --script tests/test_ui_layout.gd
mkdir -p build/web
touch build/.gdignore
godot --headless --path . --export-release Web build/web/index.html
python3 -m http.server 8000 --directory build/web
```

`http://localhost:8000`에서 플레이합니다. WebGL 2를 지원하는 브라우저가 필요합니다. `file://`로 직접 열 수 없습니다. 물리적인 아이폰 Safari 검증은 별도로 필요합니다.

PR마다 GitHub Actions가 실제 Godot 엔진으로 검사하고 `rust-city-web` 빌드 파일을 첨부합니다. 검토 후 `main`에 병합하면 기존 GitHub Pages 워크플로가 웹 게임을 배포합니다. 저장소의 **Settings → Pages → Source**는 **GitHub Actions**여야 합니다. 개발·웹 배포에는 맥이 필요하지 않습니다.

## 저장과 이전

기기마다 자동 저장합니다. 관리 화면에서 JSON 백업을 내보내거나 가져올 수 있습니다. 기존 웹 게임의 **현재 공장 모드 백업(currencyVersion 2)**도 가져올 수 있습니다. 이전 클리커·채집 모드 백업은 지원하지 않습니다. 기존 Safari 저장소를 자동으로 읽지 않으므로 원래 게임에서 백업을 내보낸 뒤 여기서 가져오세요.

방치 생산은 산업 발전 후 해금되며 최대 2시간입니다. 새 웹 주소로 옮기거나 브라우저 데이터를 지우기 전에 백업을 보관하세요.

## 구조와 검증

- `scripts/core/`: 고정 0.25초 생산·물류·전력 시뮬레이션 및 저장 검증.
- `scripts/ui/`: 지도, 모바일 패널과 조작. 생산마다 버튼을 재생성하지 않습니다.
- `data/catalog.json`: 기존 게임의 가격·레시피·성장 수치를 보존한 데이터.
- `tests/reference_campaign.json`: 실제 비용을 지불하며 로켓까지 진행한 기존 웹 게임의 조작 기록. GDScript 결과와 돈·생산·판매·납품을 비교합니다.
- `tools/web_check.py`: Web 빌드 후 Playwright와 Chromium으로 실제 Godot WASM 실행을 확인합니다.

산림부터 로켓까지의 시뮬레이션은 JavaScript 래퍼 없이 GDScript로 실행됩니다. 도트 지형·시설·고양이·메뉴 아이콘은 `scripts/ui/pixel_art.gd`의 32px 원본 픽셀 작업으로 생성되며, 외부 이미지나 유료 생성 서비스를 사용하지 않습니다. 지형과 스프라이트는 최근접 필터로 표시하고 한국어 UI는 가독성을 위해 부드러운 글꼴을 사용합니다.

한국어 폰트 라이선스는 `assets/fonts/OFL.txt`에 있습니다.
