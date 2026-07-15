import pygame
import serial
import cv2
import numpy as np
import time
from pathlib import Path

# ====================================================
# 1. Pygame 오디오 및 가변 그래픽 초기화
# ====================================================
pygame.init()
pygame.mixer.init()

current_width, current_height = 800, 640
screen = pygame.display.set_mode((current_width, current_height), pygame.RESIZABLE)
pygame.display.set_caption("FPGA Orchestra")

try:
    font_large = pygame.font.SysFont("malgungothic", 28, bold=True)
    font_medium = pygame.font.SysFont("malgungothic", 22, bold=True)
    font_small = pygame.font.SysFont("malgungothic", 18)
    font_start = pygame.font.SysFont("malgungothic", 72, bold=True)
except Exception:
    font_large = pygame.font.Font(None, 36)
    font_medium = pygame.font.Font(None, 28)
    font_small = pygame.font.Font(None, 24)
    font_start = pygame.font.Font(None, 96)

# ====================================================
# 2. 커튼 오프닝 화면
# ====================================================
CURTAIN_WAIT_TIME = 2.0
CURTAIN_OPEN_TIME = 2.2
APP_DIR = Path(__file__).resolve().parent
curtain_original = pygame.image.load(str(APP_DIR / "curtain.png")).convert()

SCREEN_INTRO = 0
SCREEN_READY = 1
SCREEN_PLAYING = 2
screen_state = SCREEN_INTRO
intro_started_at = time.time()


def draw_curtain_opening(surface, progress):
    """커튼 이미지를 좌우 절반으로 나누어 바깥쪽으로 이동시킨다."""
    width, height = surface.get_size()
    curtain = pygame.transform.smoothscale(curtain_original, (width, height))
    half_width = width // 2

    left_curtain = curtain.subsurface((0, 0, half_width, height))
    right_curtain = curtain.subsurface((half_width, 0, width - half_width, height))

    # progress에 ease-out을 적용해 처음에는 빠르고 끝에서는 부드럽게 감속한다.
    eased = 1.0 - (1.0 - progress) ** 3
    offset = int(half_width * eased)

    surface.fill((12, 8, 18))
    surface.blit(left_curtain, (-offset, 0))
    surface.blit(right_curtain, (half_width + offset, 0))


def draw_start_button(surface):
    """커튼이 열린 뒤 START 버튼을 그리고 클릭 영역을 반환한다."""
    width, height = surface.get_size()
    surface.fill((12, 8, 18))

    title = font_start.render("START", True, (255, 225, 120))
    title_rect = title.get_rect(center=(width // 2, height // 2))

    pulse = 1.0 + 0.05 * np.sin(time.time() * 4.0)
    pulse_size = (int(title_rect.width * pulse), int(title_rect.height * pulse))
    title = pygame.transform.smoothscale(title, pulse_size)
    title_rect = title.get_rect(center=(width // 2, height // 2))

    button_rect = title_rect.inflate(80, 42)
    mouse_over = button_rect.collidepoint(pygame.mouse.get_pos())
    border_color = (255, 235, 150) if mouse_over else (170, 120, 45)

    pygame.draw.rect(surface, (38, 20, 28), button_rect, border_radius=18)
    pygame.draw.rect(surface, border_color, button_rect, 4, border_radius=18)
    surface.blit(title, title_rect)

    guide = font_small.render("Click to begin", True, (220, 210, 200))
    surface.blit(guide, guide.get_rect(center=(width // 2, button_rect.bottom + 35)))
    return button_rect


# ====================================================
# 3. OpenCV 비디오 캡처 엔진
# ====================================================
CAMERA_INDEX = 1
cap = cv2.VideoCapture(CAMERA_INDEX)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

if not cap.isOpened():
    print("캡처보드를 찾을 수 없습니다.")

# ====================================================
# 4. UART 시리얼 포트 설정
# ====================================================
try:
    ser = serial.Serial(
        port="COM7",
        baudrate=115200,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=0,
    )
    print("FPGA UART 통신 연결 성공!")
except Exception as e:
    print(f"시리얼 포트 연결 실패: {e}")
    ser = None

# ====================================================
# 5. 오디오 채널 및 음원 로드
# ====================================================
ch_piano = pygame.mixer.Channel(0)
ch_trumpet = pygame.mixer.Channel(1)
ch_drum = pygame.mixer.Channel(2)
ch_cymbals = pygame.mixer.Channel(3)
ch_clarinet = pygame.mixer.Channel(4)
ch_violin = pygame.mixer.Channel(5)

sound_piano_do = pygame.mixer.Sound("piano_do.wav")
sound_piano_re = pygame.mixer.Sound("piano_re.wav")
sound_piano_mi = pygame.mixer.Sound("piano_mi.wav")
sound_trumpet_do = pygame.mixer.Sound("Trumpet_do.wav")
sound_trumpet_re = pygame.mixer.Sound("Trumpet_re.wav")
sound_trumpet_mi = pygame.mixer.Sound("Trumpet_mi.wav")
sound_drum_kick = pygame.mixer.Sound("drum_kick.wav")
sound_drum_snare = pygame.mixer.Sound("drum_snare.wav")
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

# ====================================================
# 6. UART FSM 및 타이머
# ====================================================
STATE_IDLE, STATE_PHASE1, STATE_PHASE2 = 0, 1, 2
current_state = STATE_IDLE
phase1_data = 0x00
phase2_data = 0x00
status_text = "대기 중... (FPGA의 Start 패킷을 기다립니다)"

flash_timers = {
    "piano": 0,
    "trumpet": 0,
    "drum": 0,
    "cymbals": 0,
    "clarinet": 0,
    "violin": 0,
}


def play_note(channel, note_code, sound_1, sound_2, sound_3):
    if note_code == 1:
        channel.play(sound_1)
    elif note_code == 2:
        channel.play(sound_2)
    elif note_code == 3:
        channel.play(sound_3)


clock = pygame.time.Clock()
running = True
start_button_rect = pygame.Rect(0, 0, 0, 0)

# ====================================================
# 7. 메인 루프
# ====================================================
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.VIDEORESIZE:
            current_width, current_height = event.w, event.h
            screen = pygame.display.set_mode(
                (current_width, current_height), pygame.RESIZABLE
            )
        elif (
            screen_state == SCREEN_READY
            and event.type == pygame.MOUSEBUTTONDOWN
            and event.button == 1
            and start_button_rect.collidepoint(event.pos)
        ):
            screen_state = SCREEN_PLAYING

    # 커튼이 열리는 동안에는 본 프로그램을 그리지 않는다.
    if screen_state == SCREEN_INTRO:
        elapsed = time.time() - intro_started_at
        # 앱 화면이 생성된 뒤 2초 동안 닫힌 커튼을 그대로 보여준다.
        opening_elapsed = max(0.0, elapsed - CURTAIN_WAIT_TIME)
        progress = min(opening_elapsed / CURTAIN_OPEN_TIME, 1.0)
        draw_curtain_opening(screen, progress)
        if progress >= 1.0:
            screen_state = SCREEN_READY

        pygame.display.flip()
        clock.tick(60)
        continue

    # 커튼이 완전히 열린 뒤 START 버튼을 표시한다.
    if screen_state == SCREEN_READY:
        start_button_rect = draw_start_button(screen)
        pygame.display.flip()
        clock.tick(60)
        continue

    screen.fill((30, 30, 30))

    ret, frame = cap.read()
    if ret:
        roi = frame[0:120, 0:106]
        frame[0:120, 0:106] = cv2.flip(roi, 1)
        frame = np.ascontiguousarray(frame)

        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        video_surf_raw = pygame.image.frombuffer(
            frame_rgb.tobytes(), (640, 480), "RGB"
        )

        video_zone_height = current_height - 120
        scale_width = int(video_zone_height * (4 / 3))
        scale_height = int(video_zone_height)

        if scale_width > current_width:
            scale_width = current_width
            scale_height = int(current_width * (3 / 4))

        video_surf_scaled = pygame.transform.scale(
            video_surf_raw, (scale_width, scale_height)
        )

        start_x = (current_width - scale_width) // 2
        start_y = 10
        screen.blit(video_surf_scaled, (start_x, start_y))

        cell_w = scale_width // 3
        cell_h = scale_height // 2
        grid_map = {
            "piano": {
                "rect": (start_x, start_y, cell_w, cell_h),
                "name": "피아노",
            },
            "trumpet": {
                "rect": (start_x + cell_w, start_y, cell_w, cell_h),
                "name": "트럼펫",
            },
            "drum": {
                "rect": (start_x + cell_w * 2, start_y, cell_w, cell_h),
                "name": "드럼",
            },
            "cymbals": {
                "rect": (start_x, start_y + cell_h, cell_w, cell_h),
                "name": "심벌즈",
            },
            "clarinet": {
                "rect": (start_x + cell_w, start_y + cell_h, cell_w, cell_h),
                "name": "클라리넷",
            },
            "violin": {
                "rect": (start_x + cell_w * 2, start_y + cell_h, cell_w, cell_h),
                "name": "바이올린",
            },
        }

        pygame.draw.rect(
            screen, (255, 50, 50), (start_x, start_y, scale_width, scale_height), 2
        )
        pygame.draw.line(
            screen,
            (255, 50, 50),
            (start_x, start_y + cell_h),
            (start_x + scale_width, start_y + cell_h),
            2,
        )
        pygame.draw.line(
            screen,
            (255, 50, 50),
            (start_x + cell_w, start_y),
            (start_x + cell_w, start_y + scale_height),
            2,
        )
        pygame.draw.line(
            screen,
            (255, 50, 50),
            (start_x + cell_w * 2, start_y),
            (start_x + cell_w * 2, start_y + scale_height),
            2,
        )

        current_time = time.time()
        for inst_key, data in grid_map.items():
            r_x, r_y, r_w, r_h = data["rect"]

            if current_time - flash_timers[inst_key] < 0.2:
                pygame.draw.rect(screen, (50, 150, 255), data["rect"], 8)

            inst_text = font_medium.render(data["name"], True, (255, 255, 255))
            inst_text.set_alpha(150)
            t_w, t_h = inst_text.get_size()
            screen.blit(inst_text, (r_x + (r_w - t_w) // 2, r_y + (r_h - t_h) // 2))

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

            note_piano = phase1_data & 0x03
            note_trumpet = (phase1_data >> 2) & 0x03
            note_drum = (phase1_data >> 4) & 0x03
            note_cymbals = phase2_data & 0x03
            note_clarinet = (phase2_data >> 2) & 0x03
            note_violin = (phase2_data >> 4) & 0x03

            if note_piano > 0:
                play_note(ch_piano, note_piano, sound_piano_do, sound_piano_re, sound_piano_mi)
                flash_timers["piano"] = time.time()
            if note_trumpet > 0:
                play_note(ch_trumpet, note_trumpet, sound_trumpet_do, sound_trumpet_re, sound_trumpet_mi)
                flash_timers["trumpet"] = time.time()
            if note_drum > 0:
                play_note(ch_drum, note_drum, sound_drum_kick, sound_drum_snare, sound_drum_symbal)
                flash_timers["drum"] = time.time()
            if note_cymbals > 0:
                play_note(ch_cymbals, note_cymbals, sound_cymbal_crash, sound_cymbal_stick, sound_cymbal_choke)
                flash_timers["cymbals"] = time.time()
            if note_clarinet > 0:
                play_note(ch_clarinet, note_clarinet, sound_clarinet_do, sound_clarinet_re, sound_clarinet_mi)
                flash_timers["clarinet"] = time.time()
            if note_violin > 0:
                play_note(ch_violin, note_violin, sound_violin_do, sound_violin_re, sound_violin_mi)
                flash_timers["violin"] = time.time()

            status_text = (
                f"연주! [ P:{note_piano} T:{note_trumpet} D:{note_drum} "
                f"C:{note_cymbals} Cl:{note_clarinet} V:{note_violin} ]"
            )
            current_state = STATE_IDLE

    text_surface = font_large.render(
        "Interactive 6-Zone Orchestra Visualizer", True, (200, 255, 200)
    )
    status_surface = font_small.render(status_text, True, (255, 200, 0))

    ui_start_y = current_height - 100
    screen.blit(text_surface, (40, ui_start_y))
    screen.blit(status_surface, (40, ui_start_y + 40))

    pygame.display.flip()
    clock.tick(60)

cap.release()
if ser is not None:
    ser.close()
pygame.quit()
