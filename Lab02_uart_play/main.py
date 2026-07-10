import pygame
import keyboard
import time
import serial  # UART 통신을 위한 라이브러리 추가

# 1. 오디오 믹서 초기화
pygame.mixer.init()

# 2. UART 시리얼 포트 설정 (Basys3 보드의 COM 포트 번호 입력)
try:
    ser = serial.Serial(
        port='COM5',        # 윈도우 장치관리자에서 확인한 포트로 변경 (예: COM3, COM4)
        baudrate=115200,    # Verilog의 BAUD_RATE와 일치
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=0.001       # 논블로킹(Non-blocking) 스캔을 위해 매우 짧게 설정
    )
    print("🔌 Basys3 UART 시리얼 포트 연결 성공!")
except Exception as e:
    print(f"❌ 시리얼 포트 연결 실패: {e}\n(키보드 디버깅 모드로만 작동합니다.)")
    ser = None

# ====================================================
# [오디오 채널 및 볼륨 할당]
# ====================================================
ch_piano    = pygame.mixer.Channel(0)
ch_trumpet  = pygame.mixer.Channel(1)
ch_drum     = pygame.mixer.Channel(2)
ch_cymbal   = pygame.mixer.Channel(3)
ch_clarinet = pygame.mixer.Channel(4)
ch_violin   = pygame.mixer.Channel(5)

ch_piano.set_volume(1.0)
ch_trumpet.set_volume(0.35)
ch_drum.set_volume(0.5)
ch_cymbal.set_volume(0.5)
ch_clarinet.set_volume(0.8)
ch_violin.set_volume(0.65)

# 음원 파일 적재
sound_piano_do = pygame.mixer.Sound("piano_do.wav")
sound_piano_re = pygame.mixer.Sound("piano_re.wav")
sound_piano_mi = pygame.mixer.Sound("piano_mi.wav")

sound_trumpet_do = pygame.mixer.Sound("Trumpet_do.wav")
sound_trumpet_re = pygame.mixer.Sound("Trumpet_re.wav")
sound_trumpet_mi = pygame.mixer.Sound("Trumpet_mi.wav")

sound_drum_kick   = pygame.mixer.Sound("drum_kick.wav")
sound_drum_snare  = pygame.mixer.Sound("drum_snare.wav")
sound_drum_symbal = pygame.mixer.Sound("drum_symbal.wav")

sound_cymbal_crash = pygame.mixer.Sound("cymbal_crash.wav")
sound_cymbal_stick = pygame.mixer.Sound("cymbal_stick.wav")
sound_cymbal_choke = pygame.mixer.Sound("cymbal_choke.wav")

sound_clarinet_do = pygame.mixer.Sound("Clarinet_do.wav")
sound_clarinet_re = pygame.mixer.Sound("Clarinet_re.wav")
sound_clarinet_mi = pygame.mixer.Sound("Clarinet_mi.wav")

sound_violin_do = pygame.mixer.Sound("Violin_do.wav")
sound_violin_re = pygame.mixer.Sound("Violin_re.wav")
sound_violin_mi = pygame.mixer.Sound("Violin_mi.wav")

# 키보드 테스트용 플래그 변수
is_active_q, is_active_w, is_active_e = False, False, False
is_active_a, is_active_s, is_active_d = False, False, False
is_active_z, is_active_x, is_active_c = False, False, False
is_active_i, is_active_o, is_active_p = False, False, False
is_active_k, is_active_l, is_active_semi = False, False, False
is_active_comma, is_active_period, is_active_slash = False, False, False

# ====================================================
# [핵심 수신 처리 로직] 악기 코드와 음계 코드를 받아 실행하는 함수
# ====================================================
def play_instrument_sound(inst_code, note_code):
    if note_code == 0:  # 2'b00: 소리 없음
        return

    # 1. 피아노 (3'b000)
    if inst_code == 0:
        if note_code == 1: ch_piano.play(sound_piano_do); print("⚙️ [FPGA] 피아노 - 도")
        elif note_code == 2: ch_piano.play(sound_piano_re); print("⚙️ [FPGA] 피아노 - 레")
        elif note_code == 3: ch_piano.play(sound_piano_mi); print("⚙️ [FPGA] 피아노 - 미")
    
    # 2. 트럼펫 (3'b001)
    elif inst_code == 1:
        if note_code == 1: ch_trumpet.play(sound_trumpet_do); print("⚙️ [FPGA] 트럼펫 - 도")
        elif note_code == 2: ch_trumpet.play(sound_trumpet_re); print("⚙️ [FPGA] 트럼펫 - 레")
        elif note_code == 3: ch_trumpet.play(sound_trumpet_mi); print("⚙️ [FPGA] 트럼펫 - 미")
        
    # 3. 드럼 (3'b010)
    elif inst_code == 2:
        if note_code == 1: ch_drum.play(sound_drum_kick); print("⚙️ [FPGA] 드럼 - 킥")
        elif note_code == 2: ch_drum.play(sound_drum_snare); print("⚙️ [FPGA] 드럼 - 스네어")
        elif note_code == 3: ch_drum.play(sound_drum_symbal); print("⚙️ [FPGA] 드럼 - 하이햇")
        
    # 4. 심벌즈 (3'b011)
    elif inst_code == 3:
        if note_code == 1: ch_cymbal.play(sound_cymbal_crash); print("⚙️ [FPGA] 심벌즈 - 크래시")
        elif note_code == 2: ch_cymbal.play(sound_cymbal_stick); print("⚙️ [FPGA] 심벌즈 - 스틱")
        elif note_code == 3: ch_cymbal.play(sound_cymbal_choke); print("⚙️ [FPGA] 심벌즈 - 초크")
        
    # 5. 클라리넷 (3'b100)
    elif inst_code == 4:
        if note_code == 1: ch_clarinet.play(sound_clarinet_do); print("⚙️ [FPGA] 클라리넷 - 도")
        elif note_code == 2: ch_clarinet.play(sound_clarinet_re); print("⚙️ [FPGA] 클라리넷 - 레")
        elif note_code == 3: ch_clarinet.play(sound_clarinet_mi); print("⚙️ [FPGA] 클라리넷 - 미")
        
    # 6. 바이올린 (3'b101)
    elif inst_code == 5:
        if note_code == 1: ch_violin.play(sound_violin_do); print("⚙️ [FPGA] 바이올린 - 도")
        elif note_code == 2: ch_violin.play(sound_violin_re); print("⚙️ [FPGA] 바이올린 - 레")
        elif note_code == 3: ch_violin.play(sound_violin_mi); print("⚙️ [FPGA] 바이올린 - 미")

print("========================================================")
print(" 🔌 Basys3 UART 통신 연동 오케스트라 시스템 구동 중... ")
print("  - 보드의 SW[4:2]로 악기 선택, SW[1:0]으로 음계 선택   ")
print("  - BTN_R(오른쪽 버튼)을 누르면 PC로 데이터 송신          ")
print("  - 기존 PC 키보드 연주 모드도 병렬 유지됩니다.          ")
print("========================================================")

while True:
    try:
        if keyboard.is_pressed('esc'):
            print("\n프로그램을 안전하게 종료합니다.")
            break

        # ----------------------------------------------------
        # [로직 A] UART 시리얼 데이터 수신 처리
        # ----------------------------------------------------
        if ser is not None and ser.in_waiting > 0:
            rx_packet = ser.read(1)[0]  # 1바이트 수신
            
            # 비트 마스킹 분할 연산
            note_byte = rx_packet & 0x03          # 하위 2비트 추출 (sw[1:0])
            inst_byte = (rx_packet >> 2) & 0x07   # 중간 3비트 추출 (sw[4:2])
            
            # 매핑 사운드 재생 호출
            play_instrument_sound(inst_byte, note_byte)

        # ----------------------------------------------------
        # [로직 B] PC 키보드 연주 감지 (기존 코드 유지)
        # ----------------------------------------------------
        if keyboard.is_pressed('q'):
            if not is_active_q: ch_piano.play(sound_piano_do); is_active_q = True
        else: is_active_q = False
        if keyboard.is_pressed('w'):
            if not is_active_w: ch_piano.play(sound_piano_re); is_active_w = True
        else: is_active_w = False
        if keyboard.is_pressed('e'):
            if not is_active_e: ch_piano.play(sound_piano_mi); is_active_e = True
        else: is_active_e = False

        if keyboard.is_pressed('a'):
            if not is_active_a: ch_trumpet.play(sound_trumpet_do); is_active_a = True
        else: is_active_a = False
        if keyboard.is_pressed('s'):
            if not is_active_s: ch_trumpet.play(sound_trumpet_re); is_active_s = True
        else: is_active_s = False
        if keyboard.is_pressed('d'):
            if not is_active_d: ch_trumpet.play(sound_trumpet_mi); is_active_d = True
        else: is_active_d = False

        if keyboard.is_pressed('z'):
            if not is_active_z: ch_drum.play(sound_drum_kick); is_active_z = True
        else: is_active_z = False
        if keyboard.is_pressed('x'):
            if not is_active_x: ch_drum.play(sound_drum_snare); is_active_x = True
        else: is_active_x = False
        if keyboard.is_pressed('c'):
            if not is_active_c: ch_drum.play(sound_drum_symbal); is_active_c = True
        else: is_active_c = False

        if keyboard.is_pressed('i'):
            if not is_active_i: ch_cymbal.play(sound_cymbal_crash); is_active_i = True
        else: is_active_i = False
        if keyboard.is_pressed('o'):
            if not is_active_o: ch_cymbal.play(sound_cymbal_stick); is_active_o = True
        else: is_active_o = False
        if keyboard.is_pressed('p'):
            if not is_active_p: ch_cymbal.play(sound_cymbal_choke); is_active_p = True
        else: is_active_p = False

        if keyboard.is_pressed('k'):
            if not is_active_k: ch_clarinet.play(sound_clarinet_do); is_active_k = True
        else: is_active_k = False
        if keyboard.is_pressed('l'):
            if not is_active_l: ch_clarinet.play(sound_clarinet_re); is_active_l = True
        else: is_active_l = False
        if keyboard.is_pressed(';'):
            if not is_active_semi: ch_clarinet.play(sound_clarinet_mi); is_active_semi = True
        else: is_active_semi = False

        if keyboard.is_pressed(','):
            if not is_active_comma: ch_violin.play(sound_violin_do); is_active_comma = True
        else: is_active_comma = False
        if keyboard.is_pressed('.'):
            if not is_active_period: ch_violin.play(sound_violin_re); is_active_period = True
        else: is_active_period = False
        if keyboard.is_pressed('/'):
            if not is_active_slash: ch_violin.play(sound_violin_mi); is_active_slash = True
        else: is_active_slash = False

        time.sleep(0.001)  # UART 수신 반응 속도를 극대화하기 위해 1ms 딜레이 단축

    except Exception as e:
        print(f"\n루프 오류 발생: {e}")
        break

if ser is not None:
    ser.close()
pygame.mixer.quit()