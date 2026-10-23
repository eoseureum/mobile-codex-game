# Rust City

작은 벌목장에서 시작해 로켓을 발사하는 공장 운영 게임. Godot 4.5 / GDScript / Compatibility 렌더러로 만들며, 아이폰 Safari에서 실행하는 단일 스레드 Web 빌드입니다.

[웹에서 플레이](https://eoseureum.github.io/mobile-codex-game/)

## 플레이

자원이 흩어진 128×128 타일 월드에서 시작합니다. 중앙에는 3×3 판매소가 있고, 시작 자금 ₩2,250으로 나무 위에 첫 벌목장을 지을 수 있습니다.

- **초반:** 벌목장이 6초마다 통나무를 생산합니다. 시설의 수거 버튼으로 가방에 담고, 중앙 판매소를 눌러 한 종류 또는 가방 전체를 판매합니다. 생산만으로는 돈이 생기지 않습니다.
- **자동화:** 첫 벌목장과 판매소를 컨베이어 두 칸으로 연결하는 데 ₩150이 듭니다. 판매소에 도착한 아이템은 가방을 거치지 않고 자동 판매됩니다. 마지막 컨베이어를 ₩700에 제재소로 바꾸면 연결을 유지하며 판자를 생산합니다.
- **건설:** 모든 건물과 도시 연구 건물은 돈만 필요합니다. 가공 시설을 처음 설치할 때 생산식·주기·전력을 확인하고 설치 또는 취소합니다. 이후에는 바로 설치하며, 별도 생산식 버튼으로 미리 확인할 수 있습니다.
- **산업:** 시설의 입력 재료와 발전 연료, 로켓 부품은 실제 컨베이어로 공급합니다. 창고·보관 정책·주문 출하는 없습니다. 시설 속도와 판매소 단가·처리량을 점진적으로 개선합니다.
- **지도:** 드래그와 두 손가락 확대·축소를 지원합니다. 자원은 정리해 빈칸으로 만들 수 있고 회수품은 가방으로 들어갑니다. 시설 관리 카드는 접거나 높이를 바꿀 수 있습니다. 미해금 항목은 ?로 표시합니다.

## 개발과 Web 빌드

Godot 4.5에서 `project.godot`을 열어 F5로 실행합니다. Export Templates를 설치한 뒤 다음 명령을 사용합니다.

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script tests/test_sales_hub.gd
godot --headless --path . --script tests/test_sales_hub_ui.gd
godot --headless --path . --script tests/test_world.gd
godot --headless --path . -- --ui-check
mkdir -p build/web
touch build/.gdignore
godot --headless --path . --export-release Web build/web/index.html
python3 -m http.server 8000 --directory build/web
```

`http://localhost:8000`에서 플레이합니다. WebGL 2가 필요하며 file://로 직접 열 수 없습니다. `tools/hub_web_check.py`는 Playwright·Chromium으로 실제 모바일 크기 Web 빌드의 수거·판매·자동화·생산식 확인과 저장 이전을 검사합니다. 물리적인 아이폰 Safari 검증은 별도로 필요합니다.

PR에서는 Godot 검사와 Web 내보내기를 진행하고, main 병합 후 GitHub Pages에 배포합니다. 전체 로켓 캠페인 검사는 필요한 경우에만 workflow_dispatch의 선택 항목으로 실행합니다. 해당 기존 캠페인은 창고 제거 전의 역사적 회귀 기준이며, 새 경제의 전체 플레이 시간 측정은 자동으로 반복하지 않습니다.

## 저장과 이전

기기별 브라우저에 자동 저장하며 관리 화면에서 JSON 백업을 내보내거나 가져올 수 있습니다. 현재 공장 모드 백업(currencyVersion 2)을 지원하고, 이전 클리커 백업은 지원하지 않습니다.

기존 도시를 불러오면 창고 재고·운송 중인 주문 화물·미완성 도시 공사 자재가 가방으로 옮겨집니다. 창고와 기존 판매소는 제거하고 통상 철거 환급을 지급합니다. 중앙 판매소 부지와 겹치는 시설은 내용물과 업그레이드를 보존해 가까운 빈칸으로 옮깁니다. 기존 컨베이어 끝은 새 판매소로 다시 연결할 수 있습니다. 작은 지도 도시도 큰 월드로 자동 이전합니다. 진행도와 로켓 재료는 보존됩니다.

한국어 폰트 라이선스는 `assets/fonts/OFL.txt`에 있습니다.
