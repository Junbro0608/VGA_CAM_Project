# LAB02_QQVGA_ColorBar_test

SW 기반 컬러 바운더리(초록 박스) 오버레이 구현 기록.

![Day2 블록 다이어그램](./images/day2_greenbar_blockdiagram.jpg)

## 요약

- `Img_externalBar`를 `Tile_filter`로 확장: 기존 고정 검정 테두리는 그대로 유지하고, `sw[2:0]` 스위치 입력으로 하단 3분할 컬럼마다 초록색 바운더리를 개별 on/off 하도록 구현
- 초록 바운더리는 검정 테두리와 겹치지 않게 그 안쪽에 별도로 그려짐 (1px → 이후 2px로 두께 확장)
- `sw[0]` / `sw[1]` / `sw[2]`가 각각 컬럼1 / 컬럼2 / 컬럼3의 초록 박스를 독립적으로 제어 (동시에 여러 개 켜도 각자 표시됨)
- 디버그 중 발견한 버그: 초록 박스 영역에서 R 채널이 원본 이미지 값을 그대로 통과시켜 원본 색과 섞여 보임 → 초록 박스일 때 R 채널도 0으로 고정해 순수 초록색이 나오도록 수정
- Vivado 합성 시 `Marron.mem` 파일이 프로젝트 소스로 등록되어 있지 않아 이미지 전체가 검게 나오는 이슈 발견 → Design Sources에 `Marron.mem` 추가로 해결

## 모듈 구조

| 모듈 | 역할 |
|---|---|
| `vga_decoder` | VGA 타이밍 생성, `de` / `x` / `y` 출력 |
| `ImgROM` | 106x120 이미지 데이터 저장 |
| `ImgRomReader` | `x/y` 기준 표시 영역 판정 + ROM 데이터 → RGB 변환 |
| `Tile_filter` | 검정 테두리(고정) + 초록 바운더리(`sw[2:0]` 선택) 오버레이 → 최종 RGB 출력 |

데이터 흐름: `vga_decoder` → `ImgRomReader` (+ `ImgROM`) → `Tile_filter` (+ `sw[2:0]`)

## 초록 바운더리 좌표 (컬럼별, 검정 테두리 바로 안쪽 기준)

| 컬럼 | 스위치 | X 범위 | Y 범위 | 두께 |
|---|---|---|---|---|
| 컬럼1 | `sw[0]` | 1 ~ 34 | 81 ~ 118 | 2px |
| 컬럼2 | `sw[1]` | 36 ~ 69 | 81 ~ 118 | 2px |
| 컬럼3 | `sw[2]` | 71 ~ 104 | 81 ~ 118 | 2px |

## 트러블슈팅

| 이슈 | 원인 | 해결 |
|---|---|---|
| 원본 이미지가 전체 검정으로 출력 | `Marron.mem`이 Vivado 프로젝트 Design Sources에 미등록 → 합성 시 `$readmemh` 실패 | Add Sources로 `Marron.mem`을 Design Sources에 등록 |
| 초록 박스 영역이 원본 이미지와 색이 섞여 보임 | `o_r`이 `is_green` 조건을 반영하지 않고 원본 R값을 그대로 통과 | `is_green`일 때 `o_r`도 0으로 고정 |
| 초록 박스 두께 조절 필요 (1px→2px) | 단일 좌표(`==`) 비교라 두께가 1px로 고정 | `GREEN_THICK` 파라미터 추가, 좌/우/상/하 밴드를 범위 비교로 변경 |

## 검증

<video src="./videos/day2_greenbar_video.mp4" controls width="480"></video>

`sw[0]`, `sw[1]`, `sw[2]`를 각각 켰을 때 해당 컬럼에만 초록 바운더리(2px)가 검정 테두리 안쪽에 겹치지 않고 표시됨을 확인.
