# 🎬 FPGA-PC 연동 실시간 AV 스트리밍 및 멀티채널 오케스트라 시스템
> **Basys3 FPGA Board & Python AV/Serial Multi-threaded Integration Project**

본 프로젝트는 Basys3 FPGA 보드의 VGA 디스플레이 출력 신호를 FW171 오디오/비디오 캡처보드를 통해 PC로 우회 수신하고, 이와 동시에 5개 악기 세션의 오케스트라 화음 사운드를 UART 분할 패킷 상태 머신(FSM)으로 조립하여 하나의 통합 Pygame GUI 제어판 상에 동시 출력하는 실시간 임베디드 멀티미디어 통합 시스템입니다.

---

## 🛠️ 시스템 아키텍처 및 통신 프로토콜 (Principle)

### 1. AV 멀티스레딩 및 그래픽 파이프라인
* **비디오 스트리밍:** Basys3 보드의 VGA 출력이 VGA-HDMI 컨버터를 거쳐 FW171 캡처보드(UVC 장치)로 입력됩니다. PC 단의 `OpenCV` 엔진이 640x480 해상도로 프레임을 디코딩한 후, `Pygame` 그래픽 엔진을 통해 가변 GUI 창에 실시간으로 렌더링합니다.
* **가변 해상도 스케일링:** `pygame.RESIZABLE` 속성 및 `VIDEORESIZE` 이벤트를 감지하여 사용자가 창의 크기를 조절하거나 전체화면(최대화) 버튼을 누르면, 화면 비율(4:3)을 유지하면서 하드웨어 가속 기반 선형 스케일링(`pygame.transform.scale`)을 적용해 화면을 가득 채웁니다.

### 2. UART 분할 패킷 상태 머신 (FSM)
단일 바이트(8-bit)만 송수신 가능한 UART 규격 하에서 5개 악기의 2비트 음계 데이터(총 10비트)를 전송하기 위해 3-Byte 프레임 구조의 순서 기반 FSM 프로토콜을 직접 설계했습니다.
* **FSM 상태 흐름:** `STATE_IDLE` ➔ `STATE_PHASE1` ➔ `STATE_PHASE2`
* **프레임 동기화 보호막:** 노이즈 등으로 패킷 누락이 발생해 데이터 싱크가 깨지는 것을 방지하기 위해 **강제 동기화 룰**을 적용했습니다. 어떤 상태에 있든 `0xFF`(Start Token) 바이트가 감지되는 즉시 시스템 상태를 `STATE_PHASE1`으로 강제 리셋하여 다음 정상 패킷부터 싱크를 100% 즉시 복구합니다.

### 3. 분할 패킷 비트 포맷 명세
* **Start Token (1바이트):** `8'hFF`
* **Data Phase 1 (1바이트):** `0[MSB 고정]` + `0[비어있음]` + `트럼펫(2bit)` + `드럼(2bit)` + `피아노(2bit)`
* **Data Phase 2 (1바이트):** `0[MSB 고정]` + `0000[비어있음]` + `바이올린(2bit)` + `클라리넷(2bit)`

* **음계 2비트 맵:** `2'b00`(소리 없음), `2'b01`(도 / 킥), `2'b10`(레 / 스네어), `2'b11`(미 / 하이햇)

### 4. 하드웨어 스펙 (FPGA RTL 사양)
* **시스템 마스터 클럭:** 100MHz (`sys_clk_pin`, W5 핀 매핑)
* **통신 속도:** 115,200 bps / **리셋 논리:** Active High 비동기 리셋 (`posedge rst`, U18 중앙 버튼 매핑)
* **하드웨어 핀 인터페이스:** 상위 로직(시퀀서 등)에서 전송 데이터와 `tx_valid` 1틱 신호를 주면, 직렬 전송 완료 직후 하드웨어 단에서 **`tx_done` 완료 응답 1틱 신호를 출력**하는 단일 송신기 전담 구조로 모듈화되었습니다.

---

## 🕹️ 시스템 디스플레이 및 오디오 할당 레이아웃 (Application)

| 악기 라인 | 가상 오디오 채널 | 1음 (도 / 킥) | 2음 (레 / 스네어) | 3음 (미 / 하이햇) |
| :--- | :---: | :---: | :---: | :---: |
| **피아노 (Piano)** | Ch 0 | piano_do.wav | piano_re.wav | piano_mi.wav |
| **트럼펫 (Trumpet)** | Ch 1 | Trumpet_do.wav | Trumpet_re.wav | Trumpet_mi.wav |
| **드럼 (Drum)** | Ch 2 | drum_kick.wav | drum_snare.wav | drum_symbal.wav |
| **클라리넷 (Clarinet)** | Ch 4 | Clarinet_do.wav | Clarinet_re.wav | Clarinet_mi.wav |
| **바이올린 (Violin)** | Ch 5 | Violin_do.wav | Violin_re.wav | Violin_mi.wav |

---

## 🚀 개발 환경 셋업 및 실행 가이드

### 1. 필수 라이브러리 설치 (Python 가상환경)
프로젝트 실행을 위해 가상환경(`.venv`) 터미널 환경에 비디오 디코딩, 가속 행렬 연산, 오디오 믹서, 시리얼 포트 제어를 위한 패키지를 설치합니다.
```bash
pip install opencv-python numpy pygame pyserial