import pygame
import serial
import cv2
import numpy as np
import time

# ====================================================
# 1. Pygame 오디오 및 가변 그래픽 초기화
# ====================================================
pygame.init()
pygame.mixer.init()

current_width, current_height = 800, 640
screen = pygame.display.set_mode((current_width, current_height), pygame.RESIZABLE)
pygame.display.set_caption("FPGA Orchestra - UI & Mirroring Test")

try:
    font_large = pygame.font.SysFont("malgungothic", 28, bold=True)
    font_medium = pygame.font.SysFont("malgungothic", 22, bold=True)
    font_small = pygame.font.SysFont("malgungothic", 18)
except:
    font_large = pygame.font.Font(None, 36)
    font_medium = pygame.font.Font(None, 28)
    font_small = pygame.font.Font(None, 24)

# ====================================================
# 2. OpenCV 비디오 캡처 엔진 (FW171)
# ====================================================
CAMERA_INDEX = 1 
cap = cv2.VideoCapture(CAMERA_INDEX)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

if not cap.isOpened():
    print("❌ 캡처보드를 찾을 수 없습니다.")

# ====================================================
# 3. UART 시리얼 포트 설정
# ====================================================
try:
    ser = serial.Serial(
        port='COM7',        
        baudrate=115200,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=0           
    )
    print("🔌 FPGA UART 통신 연결 성공!")
except Exception as e:
    print(f"❌ 시리얼 포트 연결 실패: {e}")
    ser = None

# ====================================================
# 4. 오디오 채널 및 음원 로드
# ====================================================
ch_piano    = pygame.mixer.Channel(0)
ch_trumpet  = pygame.mixer.Channel(1)
ch_drum     = pygame.mixer.Channel(2)
ch_cymbals  = pygame.mixer.Channel(3)
ch_clarinet = pygame.mixer.Channel(4)
ch_violin   = pygame.mixer.Channel(5)

sound_piano_do = pygame.mixer.Sound("piano_do.wav"); sound_piano_re = pygame.mixer.Sound("piano_re.wav"); sound_piano_mi = pygame.mixer.Sound("piano_mi.wav")
sound_trumpet_do = pygame.mixer.Sound("Trumpet_do.wav"); sound_trumpet_re = pygame.mixer.Sound("Trumpet_re.wav"); sound_trumpet_mi = pygame.mixer.Sound("Trumpet_mi.wav")
sound_drum_kick = pygame.mixer.Sound("drum_kick.wav"); sound_drum_snare = pygame.mixer.Sound("drum_snare.wav"); sound_drum_symbal = pygame.mixer.Sound("drum_symbal.wav")
sound_cymbal_crash = pygame.mixer.Sound("cymbal_crash.wav"); sound_cymbal_stick = pygame.mixer.Sound("cymbal_stick.wav"); sound_cymbal_choke = pygame.mixer.Sound("cymbal_choke.wav")
sound_clarinet_do = pygame.mixer.Sound("Clarinet_do.wav"); sound_clarinet_re = pygame.mixer.Sound("Clarinet_re.wav"); sound_clarinet_mi = pygame.mixer.Sound("Clarinet_mi.wav")
sound_violin_do = pygame.mixer.Sound("Violin_do.wav"); sound_violin_re = pygame.mixer.Sound("Violin_re.wav"); sound_violin_mi = pygame.mixer.Sound("Violin_mi.wav")

# ====================================================
# 5. 파이썬 FSM 프로토콜 및 타이머
# ====================================================
STATE_IDLE, STATE_PHASE1, STATE_PHASE2 = 0, 1, 2
current_state = STATE_IDLE
phase1_data = 0x00
phase2_data = 0x00
status_text = "대기 중... (FPGA의 Start 패킷을 기다립니다)"

flash_timers = {
    'piano': 0, 'trumpet': 0, 'drum': 0,
    'cymbals': 0, 'clarinet': 0, 'violin': 0
}

def play_note(channel, note_code, sound_1, sound_2, sound_3):
    if note_code == 1: channel.play(sound_1)
    elif note_code == 2: channel.play(sound_2)
    elif note_code == 3: channel.play(sound_3)

clock = pygame.time.Clock()
running = True

# ====================================================
# 6. 메인 무한 루프
# ====================================================
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.VIDEORESIZE:
            current_width, current_height = event.w, event.h
            screen = pygame.display.set_mode((current_width, current_height), pygame.RESIZABLE)

    screen.fill((30, 30, 30))

    ret, frame = cap.read()
    if ret:
        # [★핵심 수정 로직] 640x480 전체를 뒤집지 않고, 실제 영상이 있는 '좌측 상단 106x120 구역'만 오려서 거울 모드 적용 후 덮어쓰기
        roi = frame[0:120, 0:106]
        frame[0:120, 0:106] = cv2.flip(roi, 1)
        
        # 메모리 꼬임(프리즈) 방지를 위한 재정렬
        frame = np.ascontiguousarray(frame) 
        
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        video_surf_raw = pygame.image.frombuffer(frame_rgb.tobytes(), (640, 480), "RGB")
        
        video_zone_height = current_height - 120
        scale_width = int(video_zone_height * (4/3))
        scale_height = int(video_zone_height)
        
        if scale_width > current_width:
            scale_width = current_width
            scale_height = int(current_width * (3/4))
            
        video_surf_scaled = pygame.transform.scale(video_surf_raw, (scale_width, scale_height))
        
        start_x = (current_width - scale_width) // 2
        start_y = 10
        
        screen.blit(video_surf_scaled, (start_x, start_y))
        
        # ----------------------------------------------------
        # 6구역 동적 그리드(Grid)
        # ----------------------------------------------------
        cell_w = scale_width // 3
        cell_h = scale_height // 2
        
        grid_map = {
            'piano':   {'rect': (start_x, start_y, cell_w, cell_h),                     'name': "피아노"},
            'trumpet': {'rect': (start_x + cell_w, start_y, cell_w, cell_h),            'name': "트럼펫"},
            'drum':    {'rect': (start_x + cell_w * 2, start_y, cell_w, cell_h),        'name': "드럼"},
            'cymbals': {'rect': (start_x, start_y + cell_h, cell_w, cell_h),            'name': "심벌즈"},
            'clarinet':{'rect': (start_x + cell_w, start_y + cell_h, cell_w, cell_h),   'name': "클라리넷"},
            'violin':  {'rect': (start_x + cell_w * 2, start_y + cell_h, cell_w, cell_h),'name': "바이올린"}
        }

        pygame.draw.rect(screen, (255, 50, 50), (start_x, start_y, scale_width, scale_height), 2)
        pygame.draw.line(screen, (255, 50, 50), (start_x, start_y + cell_h), (start_x + scale_width, start_y + cell_h), 2)
        pygame.draw.line(screen, (255, 50, 50), (start_x + cell_w, start_y), (start_x + cell_w, start_y + scale_height), 2)
        pygame.draw.line(screen, (255, 50, 50), (start_x + cell_w * 2, start_y), (start_x + cell_w * 2, start_y + scale_height), 2)

        current_time = time.time()

        for inst_key, data in grid_map.items():
            r_x, r_y, r_w, r_h = data['rect']
            
            if current_time - flash_timers[inst_key] < 0.2:
                pygame.draw.rect(screen, (50, 150, 255), data['rect'], 8)
                
            inst_text = font_medium.render(data['name'], True, (255, 255, 255))
            inst_text.set_alpha(150)
            t_w, t_h = inst_text.get_size()
            screen.blit(inst_text, (r_x + (r_w - t_w)//2, r_y + (r_h - t_h)//2))

    # C. UART FSM 수신 처리
    if ser is not None and ser.in_waiting > 0:
        rx_byte = ser.read(1)[0]
        
        if rx_byte == 0xFF:
            current_state = STATE_PHASE1
            status_text = "Start 수신! Phase 1 대기..."
        elif current_state == STATE_PHASE1:
            phase1_data = rx_byte
            current_state = STATE_PHASE2
            status_text = "Phase 1 수신! Phase 2 대기..."
        elif current_state == STATE_PHASE2:
            phase2_data = rx_byte
            
            note_piano   = phase1_data & 0x03
            note_trumpet = (phase1_data >> 2) & 0x03
            note_drum    = (phase1_data >> 4) & 0x03
            note_cymbals  = phase2_data & 0x03
            note_clarinet = (phase2_data >> 2) & 0x03
            note_violin   = (phase2_data >> 4) & 0x03
            
            if note_piano > 0:   play_note(ch_piano, note_piano, sound_piano_do, sound_piano_re, sound_piano_mi); flash_timers['piano'] = time.time()
            if note_trumpet > 0: play_note(ch_trumpet, note_trumpet, sound_trumpet_do, sound_trumpet_re, sound_trumpet_mi); flash_timers['trumpet'] = time.time()
            if note_drum > 0:    play_note(ch_drum, note_drum, sound_drum_kick, sound_drum_snare, sound_drum_symbal); flash_timers['drum'] = time.time()
            if note_cymbals > 0: play_note(ch_cymbals, note_cymbals, sound_cymbal_crash, sound_cymbal_stick, sound_cymbal_choke); flash_timers['cymbals'] = time.time()
            if note_clarinet > 0:play_note(ch_clarinet, note_clarinet, sound_clarinet_do, sound_clarinet_re, sound_clarinet_mi); flash_timers['clarinet'] = time.time()
            if note_violin > 0:  play_note(ch_violin, note_violin, sound_violin_do, sound_violin_re, sound_violin_mi); flash_timers['violin'] = time.time()
            
            status_text = f"연주! [ P:{note_piano} T:{note_trumpet} D:{note_drum} C:{note_cymbals} Cl:{note_clarinet} V:{note_violin} ]"
            current_state = STATE_IDLE

    # D. 하단 UI 텍스트
    text_surface = font_large.render("Interactive 6-Zone Orchestra Visualizer", True, (200, 255, 200))
    status_surface = font_small.render(status_text, True, (255, 200, 0))
    
    ui_start_y = current_height - 100
    screen.blit(text_surface, (40, ui_start_y))
    screen.blit(status_surface, (40, ui_start_y + 40))

    pygame.display.flip()
    clock.tick(60)

cap.release()
if ser is not None :
    ser.close()
pygame.quit()