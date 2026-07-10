# LAB3_QQVGA_Textfilter_test

Tile_filter 뒤에 텍스트(악기/노트 라벨) 오버레이 기능을 추가한 기록.

![도레미 라벨 결과](./images/day2_text_0.jpg) ![kick/snare/hi-hat 라벨 결과](./images/day2_text_1.jpg)

## 요약

- 하단 3분할 컬럼 안에 스위치로 고른 라벨(도/레/미, kick/snare/hi-hat)을 표시하는 `TextFilter` 모듈 신규 구현
- 실시간 폰트 렌더링 대신, 라벨 문자열을 Python(Pillow)으로 미리 비트맵 이미지로 그려서 ROM(`TextRom.mem`)에 저장하는 방식 채택 (한글 자모 조합 로직 없이 `ImgROM`과 같은 패턴 재사용)
- `sw_text[2:0]`로 라벨 세트를 선택: `sw_text[0]`=도레미, `sw_text[1]`=kick/snare/hi-hat (심벌 세트는 불필요해져 제외, 최종 2세트 6개 라벨만 사용)
- 데이터 흐름: `Tile_filter` 출력(o_r/g/b) → `TextFilter` 입력, `TextFilter`가 좌표+`sw_text`로 ROM 주소를 계산해 `Text_Rom`에서 픽셀을 읽어와 검정 글자로 오버레이

## 모듈 구조

| 모듈 | 역할 |
|---|---|
| `Text_Rom` | 라벨 비트맵 저장 (1bit/px), `addr` 입력 → `data` 출력 |
| `TextFilter` | 좌표/스위치로 라벨 영역·주소 계산, `Text_Rom` 데이터로 글자 오버레이 → 최종 RGB 출력 |

데이터 흐름: `ImgRomReader`(+`ImgROM`) → `Tile_filter`(+`sw`) → `TextFilter`(+`sw_text`, `Text_Rom`) → 최종 `port_red/green/blue`

## 라벨 사양

| label_idx | 텍스트 | 트리거 |
|---|---|---|  
| 0,1,2 | 도, 레, 미 | `sw_text[0]` |
| 3,4,5 | kick, snare, hi-hat | `sw_text[1]` |

- 라벨 비트맵 크기: 30(W) x 16(H)px, 1bit/px (글자=1, 배경=0)
- ROM 총 크기: 6 x 30 x 16 = 2880 워드
- 주소 계산: `addr = label_idx*(30*16) + rel_y*30 + rel_x`
- 컬럼별 라벨 시작 좌표 (Tile_filter 초록 박스 테두리와 안 겹치도록 여유 공간에 배치): 컬럼1 x=3, 컬럼2 x=38, 컬럼3 x=73 / 공통 y=92

## 트러블슈팅

| 이슈 | 원인 | 해결 |
|---|---|---|
| DRC multiple driver 에러 | `TextFilter`의 `addr`/`data` 포트 방향이 반대로 선언됨 (addr가 input, data가 output) | `addr`는 output, `data`는 input으로 방향 수정 |
| 여전한 multiple driver 에러 | `VGA_top`에서 `addr` 신호명이 `ImgROM`용과 `TextROM`용에 중복 선언되어 하나의 net으로 합쳐짐 | `img_addr` / `text_addr`로 신호명 분리 |
| 글자가 전혀 안 뜸 | `Text_Rom`의 `mem`이 비트 폭 표시 없이 선언(`logic mem[...]`)돼 있어 Vivado가 `$readmem`을 "invalid memory name"으로 무시, RAM이 레지스터로 해체됨 | `logic [0:0] mem[...]`로 명시적 폭 지정 |
| 초록 박스와 글자가 겹쳐 보임 / 영단어("crash", "choke" 등) 잘림 | 라벨 폭(32px)이 초록 박스 안쪽 여유 공간(30px)보다 넓음 | 라벨 폭 30px로 축소, 노트 표기(C4/D4/E4) 제거, 폰트 크기 축소 |
| 글자가 노이즈처럼 깨짐 | `TextFilter`의 `LABEL_W`가 32로 남아있어 실제 mem 데이터 간격(30 기준)과 주소 계산이 어긋남 | `LABEL_W`를 30으로 일치시킴 |
| 심벌 세트 불필요 | 요구사항 변경으로 크래시/스틱/초크 라벨 제외 | 라벨을 6개(도레미+드럼)로 축소, ROM 재생성, `set_idx`를 1비트로 단순화 |

## 검증

- `sw_text[0]`/`sw_text[1]`로 라벨 세트를 전환했을 때 해당 3칸에 올바른 라벨이 초록 박스와 겹치지 않고 표시됨을 확인