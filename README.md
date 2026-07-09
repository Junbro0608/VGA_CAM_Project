# VGA Image Pipeline (SystemVerilog)

FPGA VGA 출력단에서 ROM 이미지에 바운딩 박스/구분선을 오버레이하는 모듈 구현 기록.

---

## Day 1 — 106x120 이미지 바운딩 박스 & 구분선

### 목표

`ImgROM`에 저장된 106x120 이미지(Marron.mem) 위에 검은색(디버그 시 빨간색) 테두리와 내부 구분선을 오버레이한다. 레이아웃은 상단 메인 이미지 + 하단 3분할 썸네일 구조.

### 레이아웃 사양

- 전체 이미지: 106(W) x 120(H)
- 상단 메인 영역: y = 0 ~ 79 (80px, 전체 폭)
- 가로 구분선: y = 80 (1px)
- 하단 3분할 영역: y = 81 ~ 119
  - 컬럼1: x = 0 ~ 34 (35px)
  - 세로 구분선 1: x = 35 (1px)
  - 컬럼2: x = 36 ~ 69 (34px)
  - 세로 구분선 2: x = 70 (1px)
  - 컬럼3: x = 71 ~ 105 (35px)
- 검산: 35+1+34+1+35 = 106 ✓ / 80+1+39 = 120 ✓

### 모듈 구조

```
VGA_Decoder → x_pixel, y_pixel, de
        │
        ▼
ImgROM (106x120, clk 동기 read) ──imgPxlData──▶ ImgRomReader ──(r,g,b)──▶ Img_externalBar ──▶ port_red/green/blue
        ▲                                          │
        └──────────────── addr ───────────────────┘
```

### 최종 코드

**ImgROM** — 106x120 이미지 저장, 레지스터드 출력(BRAM 추론)

```systemverilog
module ImgROM (
    input  logic                       clk,
    input  logic [$clog2(106*120)-1:0] addr,
    output logic [               15:0] data
);
    logic [15:0] mem[0:106*120-1];

    initial begin
        $readmemh("Marron.mem", mem);
    end

    always_ff @(posedge clk)
        data <= mem[addr];

endmodule
```

**ImgRomReader** — 106x120 표시 영역 판정 및 RGB444 변환

```systemverilog
module ImgRomReader (
    input  logic                       de,
    input  logic [                9:0] x_pixel,
    input  logic [                9:0] y_pixel,
    output logic [$clog2(106*120)-1:0] addr,
    input  logic [               15:0] imgPxlData,
    output logic [                3:0] port_red,
    output logic [                3:0] port_green,
    output logic [                3:0] port_blue
);
    logic displayArea;

    assign displayArea = de && (x_pixel < 106) && (y_pixel < 120);

    assign addr = displayArea ? (106 * y_pixel + x_pixel) : '0;

    assign {port_red, port_green, port_blue} =
        displayArea ? {imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]} : '0;

endmodule
```

**Img_externalBar** — 외곽 테두리 + 내부 구분선 오버레이 (106x120 영역 내로 제한)

```systemverilog
module Img_externalBar #(
    parameter int H_BORDER_Y   = 80,   // 가로 border 시작 row
    parameter int V_BORDER1_X  = 35,   // 세로 border 1 시작 column
    parameter int V_BORDER2_X  = 70,   // 세로 border 2 시작 column
    parameter int BORDER_THICK = 1     // border 두께(px)
)(
    input  logic [3:0] i_r,
    input  logic [3:0] i_g,
    input  logic [3:0] i_b,

    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,

    output logic [3:0] o_r,
    output logic [3:0] o_g,
    output logic [3:0] o_b
);

    logic display_area;
    logic is_outer_border;
    logic is_h_border;
    logic is_v_border;
    logic is_border;

    // 106x120 이미지 영역 안에서만 border 적용
    assign display_area = (x_pixel < 106) && (y_pixel < 120);

    // 이미지 외곽 테두리(사진 프레임)
    assign is_outer_border = (x_pixel == 0) || (x_pixel == 105) ||
                              (y_pixel == 0) || (y_pixel == 119);

    // 가로 구분선 (상단/하단 경계)
    assign is_h_border = (y_pixel >= H_BORDER_Y) &&
                          (y_pixel <  H_BORDER_Y + BORDER_THICK);

    // 세로 구분선 (하단 3분할, 가로선 아래에서만)
    assign is_v_border = (y_pixel >= H_BORDER_Y + BORDER_THICK) &&
                          (((x_pixel >= V_BORDER1_X) && (x_pixel < V_BORDER1_X + BORDER_THICK)) ||
                           ((x_pixel >= V_BORDER2_X) && (x_pixel < V_BORDER2_X + BORDER_THICK)));

    assign is_border = display_area && (is_outer_border || is_h_border || is_v_border);

    assign o_r = is_border ? 4'hF : i_r;   // 디버그: 빨간색 (정식: 4'h0)
    assign o_g = is_border ? 4'h0 : i_g;
    assign o_b = is_border ? 4'h0 : i_b;

endmodule
```

**VGA_top** — 통합 인스턴스화

```systemverilog
module VGA_top (
    input  logic       clk,
    input  logic       reset,
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue
);

    logic [                9:0] x_pixel;
    logic [                9:0] y_pixel;
    logic                       de;

    logic [$clog2(106*120)-1:0] addr;
    logic [               15:0] imgPxlData;

    logic [                3:0] qqvga_red;
    logic [                3:0] qqvga_green;
    logic [                3:0] qqvga_blue;

    VGA_Decoder U_VGA_DECODER (
        .clk    (clk),
        .reset  (reset),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .de     (de)
    );

    ImgRomReader U_ROMREADER (
        .de        (de),
        .x_pixel   (x_pixel),
        .y_pixel   (y_pixel),
        .addr      (addr),
        .imgPxlData(imgPxlData),
        .port_red  (qqvga_red),
        .port_green(qqvga_green),
        .port_blue (qqvga_blue)
    );

    ImgROM U_IMGROM (
        .clk (clk),
        .addr(addr),
        .data(imgPxlData)
    );

    Img_externalBar #(
        .H_BORDER_Y   (80),
        .V_BORDER1_X  (35),
        .V_BORDER2_X  (70),
        .BORDER_THICK (1)
    ) U_EXTERNALBAR (
        .i_r(qqvga_red),
        .i_g(qqvga_green),
        .i_b(qqvga_blue),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .o_r(port_red),
        .o_g(port_green),
        .o_b(port_blue)
    );

endmodule
```

### 트러블슈팅

| 이슈 | 원인 | 해결 |
|---|---|---|
| 빨간 선이 화면 전체(가로/세로)로 뻗어나감 | border 판정 로직에 106x120 영역 제한(`display_area`)이 없었음 | 모든 border 신호를 `display_area`와 AND |
| 외곽 테두리가 없음 | 내부 구분선만 구현, 이미지 프레임 로직 누락 | `is_outer_border` (x=0,105 / y=0,119) 추가 |
| ROM이 BRAM으로 안 잡힐 우려 | `ImgROM`이 조합 로직(비동기 read)이었음 | `clk` 추가 + `always_ff` 레지스터드 read |
| `de` 미반영 | blanking 구간 처리 로직 누락 | `displayArea` 계산에 `de` AND 추가 |

### 검증

- `o_r/o_g/o_b`를 검정 대신 빨간색(`4'hF, 0, 0`)으로 임시 출력해 바운딩 박스/구분선 위치 육안 확인
- 확인 후 정식 출력은 `4'h0`(검정)으로 복원 예정
