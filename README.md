# The Quiet Field

Godot 4.5 / GDScript로 만든 터치 기반 2D 탑다운 탐색 프로토타입입니다.
iPhone Safari를 목표로 하며 데스크톱 마우스도 지원합니다.

- 화면을 한 번 터치하거나 왼쪽 클릭하면 해당 위치를 향해 이동합니다.
- 이동 중 다른 곳을 누르면 목적지가 바뀝니다. 두 번째 손가락은 무시합니다.
- 돌 타일은 통과할 수 없습니다. 막힌 목적지는 잠시 후 정지합니다.
  자동 길찾기는 없으므로 장애물 옆을 눌러 돌아가세요.
- 카메라는 플레이어를 중앙에 유지합니다. 화면 방향을 바꿔도 조작할 수 있습니다.

Godot **4.5 stable**로 `project.godot`을 열고 F6 대신 F5로 메인 장면을 실행하세요.
렌더러는 Compatibility입니다. 별도 플러그인이나 외부 에셋은 필요하지 않습니다.

## 구조

| 파일 | 역할 |
| --- | --- |
| `scenes/Main.tscn`, `scripts/main.gd` | 입력 좌표 변환, 화면 방향 대응, 목적지 표시 |
| `scenes/Player.tscn`, `scripts/player.gd` | CharacterBody2D 이동·충돌, Camera2D |
| `scenes/World.tscn`, `scripts/tile_map.gd` | 40×28 TileMapLayer와 TileSet 충돌 |
| `scenes/HUD.tscn` | 입력을 가리지 않는 화면 안내 |
| `assets/tiles.svg` | 직접 만든 48px 타일 아틀라스 |

가로 기준 뷰포트는 960×540, 세로 기준은 540×960입니다. 화면 비율이 달라지면
보이는 영역을 늘려 도형 비율과 플레이어 중앙 위치를 유지합니다.

## 검증과 Web Export

아래 `godot`은 4.5 실행 파일이어야 합니다. 같은 버전의 공식 Export Templates를
설치한 뒤 실행하세요. 사용자 데이터 폴더가 제한된 환경에서는 쓰기 가능한 경로로
`XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`을 설정하세요.

```sh
godot --version
godot --headless --path . --editor --quit
godot --headless --path . --script tests/test_game.gd
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
python3 -m http.server 8060 --directory build/web
```

`http://localhost:8060`에서 실행하세요. 파일을 직접 여는 `file://` 방식은 지원하지
않습니다. iPhone에서 테스트할 때는 WebAssembly와 WebGL 2를 지원하는 Safari로
HTTPS 호스팅 주소를 여세요. Web Export는 단일 스레드이며 COOP/COEP 헤더가
필요하지 않습니다. 기본 HTML 셸의 안전한 뷰포트를 사용하며 전체 화면은 요청하지 않습니다.

브라우저 스모크 테스트는 별도 터미널에서 실행할 수 있습니다.

```sh
python3 -m pip install -r tests/requirements.txt
python3 tests/browser_smoke.py --chromium /usr/bin/chromium
```

Chromium 경로는 설치 위치에 맞게 바꾸세요. 생성된 화면 캡처는
`build/screenshots/`에 저장됩니다. 이 테스트의 모바일 모드는 실제 Safari 검증을
대신하지 않습니다. [검증 결과와 한계](docs/validation.md)를 참고하세요.

PR 검증 워크플로는 임포트·통합 테스트·Web Export 후 `web-preview` 아티팩트를
업로드합니다. 기존 배포 워크플로는 main에 반영된 뒤에만 GitHub Pages로 배포합니다.
