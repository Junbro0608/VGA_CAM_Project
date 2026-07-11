import pygame
import time
import serial

# 1. 오디오 믹서 초기화
pygame.mixer.init()

# 2. UART 시리얼 포트 설정
try:
    ser = serial.Serial(
        port='COM3',        # 연결된 가상 COM 포트 번호에 맞게 변경
        baudrate=115200,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=0.001       # 논블로킹 초고속 시리얼 스캔
    )
    print("🔌 오케스트라 분할 패킷 수신 엔진 구동 성공!")
except Exception as e:
    print(f"❌ 시리얼 포트 연결 실패: {e}")
    ser = None

# ====================================================
# [오디오 채널 및 음원 로드] (5개 악기 축소 매핑)
# ====================================================
ch_piano    = pygame.mixer.Channel(0)
ch_trumpet  = pygame.mixer.Channel(1)
ch_drum     = pygame.mixer.Channel(2)
ch_clarinet = pygame.mixer.Channel(4)
ch_violin   = pygame.mixer.Channel(5)

ch_piano.set_volume(1.0)
ch_trumpet.set_volume(0.35)
ch_drum.set_volume(0.5)
ch_clarinet.set_volume(0.8)
ch_violin.set_volume(0.65)

# 가공된 WAV 파일 메모리 로드
sound_piano_do = pygame.mixer.Sound("piano_do.wav")
sound_piano_re = pygame.mixer.Sound("piano_re.wav")
sound_piano_mi = pygame.mixer.Sound("piano_mi.wav")

sound_trumpet_do = pygame.mixer.Sound("Trumpet_do.wav")
sound_trumpet_re = pygame.mixer.Sound("Trumpet_re.wav")
sound_trumpet_mi = pygame.mixer.Sound("Trumpet_mi.wav")

sound_drum_kick   = pygame.mixer.Sound("drum_kick.wav")
sound_drum_snare  = pygame.mixer.Sound("drum_snare.wav")
sound_drum_symbal = pygame.mixer.Sound("drum_symbal.wav")

sound_clarinet_do = pygame.mixer.Sound("Clarinet_do.wav")
sound_clarinet_re = pygame.mixer.Sound("Clarinet_re.wav")
sound_clarinet_mi = pygame.mixer.Sound("Clarinet_mi.wav")

sound_violin_do = pygame.mixer.Sound("Violin_do.wav")
sound_violin_re = pygame.mixer.Sound("Violin_re.wav")
sound_violin_mi = pygame.mixer.Sound("Violin_mi.wav")

# ====================================================
# [파이썬 소프트웨어 FSM 상태 정의]
# ====================================================
STATE_IDLE   = 0   # Start 토큰(8'hFF) 대기 상태
STATE_PHASE1 = 1   # 1바이트 데이터 수신 대기 상태 (피아노, 트럼펫, 드럼)
STATE_PHASE2 = 2   # 2바이트 데이터 수신 대기 상태 (클라리넷, 바이올린)

current_state = STATE_IDLE

# 합주용 임시 버퍼 공간 변수
phase1_data = 0x00
phase2_data = 0x00

# 개별 악기 사운드 트리거 서브루틴
def play_note(channel, note_code, sound_do, sound_re, sound_mi):
    if note_code == 1: channel.play(sound_do)
    elif note_code == 2: channel.play(sound_re)
    elif note_code == 3: channel.play(sound_mi)

print("========================================================")
print(" 🎻 5개 악기 동시 화음 연동 통신 시스템 구동 중...     ")
print("  - FSM 프로토콜: Start(0xFF) -> Phase1 -> Phase2      ")
print("  - 데이터 수신 완료 후 5개 악기가 일제히 동시 출력됩니다. ")
print("========================================================")

while True:
    try:
        if ser is not None and ser.in_waiting > 0:
            # 시리얼 버퍼에서 1바이트 읽기
            rx_byte = ser.read(1)[0]
            
            # [강제 싱크 예외처리] 어느 상태에 있든 0xFF가 들어오면 Start로 간주하고 강제 리셋
            if rx_byte == 0xFF:
                current_state = STATE_PHASE1
                continue
                
            # --- FSM 상태 머신 변이 처리 ---
            if current_state == STATE_IDLE:
                # 0xFF 토큰이 오기 전까지는 모든 데이터를 무시하고 대기
                continue
                
            elif current_state == STATE_PHASE1:
                phase1_data = rx_byte
                current_state = STATE_PHASE2  # 순서에 따라 곧바로 다음 페이즈로 이동
                
            elif current_state == STATE_PHASE2:
                phase2_data = rx_byte
                
                # ====================================================
                # [최종 화음 분석 및 출력 단계] 프레임이 완벽히 끝나는 시점
                # ====================================================
                # Phase 1 분할 디코딩: 피아노, 트럼펫, 드럼 추출
                note_piano   = phase1_data & 0x03
                note_drum    = (phase1_data >> 2) & 0x03
                note_trumpet = (phase1_data >> 4) & 0x03
                
                # Phase 2 분할 디코딩: 클라리넷, 바이올린 추출
                note_clarinet = phase2_data & 0x03
                note_violin   = (phase2_data >> 2) & 0x03
                
                # 5개 채널에 디지털 오디오 동시 인젝션 수행 (지연 최소화)
                play_note(ch_piano, note_piano, sound_piano_do, sound_piano_re, sound_piano_mi)
                play_note(ch_trumpet, note_trumpet, sound_trumpet_do, sound_trumpet_re, sound_trumpet_mi)
                play_note(ch_drum, note_drum, sound_drum_kick, sound_drum_snare, sound_drum_symbal)
                play_note(ch_clarinet, note_clarinet, sound_clarinet_do, sound_clarinet_re, sound_clarinet_mi)
                play_note(ch_violin, note_violin, sound_violin_do, sound_violin_re, sound_violin_mi)
                
                print(f"🎵 [동시 합주 완료] P:{note_piano} T:{note_trumpet} D:{note_drum} C:{note_clarinet} V:{note_violin}")
                
                # 연주가 완료되었으므로 다시 다음 곡의 Start 신호를 받기 위해 대기방으로 복귀
                current_state = STATE_IDLE

        time.sleep(0.0005) # 시리얼 스캔 응답성을 최대로 끌어올리기 위한 마이크로 타임 조절

    except KeyboardInterrupt:
        print("\n사용자에 의해 프로그램을 종료합니다.")
        break
    except Exception as e:
        print(f"\n시스템 루프 에러: {e}")
        break

if ser is not None:
    ser.close()
pygame.mixer.quit()