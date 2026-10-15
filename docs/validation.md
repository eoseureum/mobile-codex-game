# 검증 결과 — 2026-10-15

## 환경

- Linux, Godot `4.5.stable.official.876b29033`.
- 공식 4.5 stable Linux 실행 파일 및 Export Templates 사용.
  두 다운로드 파일의 SHA-512를 공식 `SHA512-SUMS.txt`와 대조해 일치 확인.
- Chromium `154.0.8037.57`, Playwright, 소프트웨어 WebGL 렌더러.
- 사용자 데이터와 에디터 캐시는 저장소 밖의 쓰기 가능한 XDG 경로 사용.

## 실행한 검사

| 검사 | 결과 |
| --- | --- |
| `godot --headless --path . --editor --quit` | 종료 코드 0, 파싱·리소스 오류와 경고 없음 |
| `godot --headless --path . --script tests/test_game.gd` | 20 checks, 0 failures |
| `godot --headless --path . --export-release Web build/web/index.html` | 종료 코드 0, 오류·경고 없음 |
| Web 출력 | HTML, JS, WASM, PCK 생성; `web_nothreads_release.zip` 사용 |
| Chromium 960×540 | 렌더링, 클릭 이동, 재입력, 추적 카메라, 화면 맞춤 통과 |
| Chromium 터치 390×844 | 터치 이동, 재입력, 844×390 회전 후 터치 통과 |
| Chromium 터치 320×568 | 터치 이동, 재입력, 568×320 회전 후 터치 통과 |
| 일반 HTTP localhost 서버 | COOP/COEP 없이 `crossOriginIsolated=false`에서 실행 통과 |
| 브라우저 오류 | 세 시나리오 모두 JavaScript 예외·console error 없음 |
| `git diff --check` | 통과 |

통합 테스트는 실제 장면을 로드해 CharacterBody2D 이동, 프레임당 이동 거리의 배수가
아닌 목적지에서 정확한 정지, 목적지 변경, 카메라 이동 후 좌표 변환, 우클릭 무시,
터치, 두 번째 손가락 무시, 벽 충돌, 막혔을 때 정지, 충돌 후 재이동,
가로·세로 화면 변경과 포커스 해제 시 정지를 검사합니다.

브라우저 검사는 실제 release Web Export를 HTTP로 제공하고 입력을 보냅니다.
스크린샷의 중앙 플레이어와 배경 변화도 검사하며 테스트 전용 API는 게임에 추가하지
않았습니다. `build/screenshots/`의 데스크톱·세로 화면을 직접 확인했습니다.

초기 실패와 수정:

- 빈 프로젝트에서 Player 부재로 테스트 실패를 확인한 뒤 기능을 구현했습니다.
- 헤드리스 입력 테스트의 뷰포트 좌표가 물리 창 좌표로 재변환되는 문제를 확인하고
  `Viewport.push_input(event, true)`로 실제 노드 입력 경로에 전달하도록 수정했습니다.
- 검토 중 목적지 표시가 맵 뒤에 그려지는 순서를 수정했습니다.
- 최종 코드로 임포트·통합 테스트·Web Export·브라우저 검사를 다시 실행해 모두 통과했습니다.

## 검증하지 못한 부분과 범위

- **실제 iPhone Safari는 실행하지 못했습니다.** 위 터치 검사는 Chromium 모바일
  에뮬레이션이며 iOS Safari/WebKit의 호환성이나 성능을 입증하지 않습니다.
- 실제 기기의 노치·주소창 크기 변경, 백그라운드 복귀, 저메모리 상황, 장시간
  성능은 추가 확인이 필요합니다. Safari에서 HTTPS 주소로 터치·회전·충돌을 확인하세요.
- 새 GitHub Actions 워크플로는 로컬에서 동일한 Godot 명령을 검증했습니다.
  호스팅된 CI 결과는 PR의 Checks에서 별도로 확인해야 합니다.
- 이 변경으로 사이트를 배포하거나 main에 병합하지 않습니다. 배포 설정 자체와
  GitHub Pages 주소의 실행은 검증하지 않았습니다.
- 목적지를 향한 직선 이동과 충돌을 구현했으며 자동 경로 탐색은 제공하지 않습니다.
