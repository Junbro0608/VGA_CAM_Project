import pygame
import keyboard
import time

# 1. 오디오 믹서 초기화
pygame.mixer.init()

# ====================================================
# [오디오 채널 할당] 심벌즈 세션을 위한 4번째 독립 채널 할당
# 각 악기는 독립 구동되며, 해당 악기 내에서만 새 음이 이전 음을 밀어냅니다.
# ====================================================
ch_piano = pygame.mixer.Channel(0)
ch_trumpet = pygame.mixer.Channel(1)
ch_drum = pygame.mixer.Channel(2)
ch_cymbal = pygame.mixer.Channel(3)  # 심벌 전용 채널 추가

# ====================================================
# 악기별 개별 볼륨 설정 (클리핑 방지 및 황금 밸런스)
# ====================================================
ch_piano.set_volume(1.0)     # 피아노 최대 볼륨
ch_trumpet.set_volume(0.5)   # 트럼펫 감쇄
ch_drum.set_volume(0.6)      # 드럼 타격감 유지
ch_cymbal.set_volume(0.4)    # 심벌즈 시원한 울림을 위한 60% 설정

# 2. 음원 파일 RAM 메모리 적재 (폴더 내 파일명과 100% 매칭)
sound_piano_do = pygame.mixer.Sound("piano_do.wav")
sound_piano_re = pygame.mixer.Sound("piano_re.wav")
sound_piano_mi = pygame.mixer.Sound("piano_mi.wav")

sound_trumpet_do = pygame.mixer.Sound("Trumpet_do.wav")
sound_trumpet_re = pygame.mixer.Sound("Trumpet_re.wav")
sound_trumpet_mi = pygame.mixer.Sound("Trumpet_mi.wav")

sound_drum_kick = pygame.mixer.Sound("drum_kick.wav")
sound_drum_snare = pygame.mixer.Sound("drum_snare.wav")
sound_drum_symbal = pygame.mixer.Sound("drum_symbal.wav")

# [새로 추가된 심벌즈 음원]
sound_cymbal_crash = pygame.mixer.Sound("cymbal_crash.wav")
sound_cymbal_stick = pygame.mixer.Sound("cymbal_stick.wav")
sound_cymbal_choke = pygame.mixer.Sound("cymbal_choke.wav")

# 사운드 객체 자체 볼륨 잠금 해제 (버그 방지 원천 차단)
for s in [sound_piano_do, sound_piano_re, sound_piano_mi, 
          sound_trumpet_do, sound_trumpet_re, sound_trumpet_mi, 
          sound_drum_kick, sound_drum_snare, sound_drum_symbal,
          sound_cymbal_crash, sound_cymbal_stick, sound_cymbal_choke]:
    s.set_volume(1.0)

# 3. 무한 연타 방지 및 라이징 엣지 감지를 위한 상태 플래그 변수
is_active_q, is_active_w, is_active_e = False, False, False  # 피아노
is_active_a, is_active_s, is_active_d = False, False, False  # 트럼펫
is_active_z, is_active_x, is_active_c = False, False, False  # 드럼
is_active_i, is_active_o, is_active_p = False, False, False  # 심벌 (신규)

print("====================================================")
print(" 🎹 대규모 오케스트라 실시간 합주 프로그램 시작 🎹 ")
print("  - 피아노 (Q: 도 / W: 레 / E: 미)                  ")
print("  - 트럼펫 (A: 도 / S: 레 / D: 미)                  ")
print("  - 드 럼  (Z: 킥 / X: 스네어 / C: 기본심벌)         ")
print("  - 심벌즈 (I: 크래시 대격 / O: 스틱 타격 / P: 초크) ")
print("  - 종료   (ESC)                                    ")
print("====================================================")

while True:
    try:
        if keyboard.is_pressed('esc'):
            print("\n프로그램을 종료합니다.")
            break

        # ====================================================
        # 🎹 [피아노 트랙] 채널 0
        # ====================================================
        if keyboard.is_pressed('q'):
            if not is_active_q:
                ch_piano.play(sound_piano_do)
                print("▶ [피아노] 도 (C4) 재생 중...                          ", end='\r')
                is_active_q = True
        else:
            is_active_q = False

        if keyboard.is_pressed('w'):
            if not is_active_w:
                ch_piano.play(sound_piano_re)
                print("▶ [피아노] 레 (D4) 재생 중...                          ", end='\r')
                is_active_w = True
        else:
            is_active_w = False

        if keyboard.is_pressed('e'):
            if not is_active_e:
                ch_piano.play(sound_piano_mi)
                print("▶ [피아노] 미 (E4) 재생 중...                          ", end='\r')
                is_active_e = True
        else:
            is_active_e = False

        # ====================================================
        # 🎺 [트럼펫 트랙] 채널 1
        # ====================================================
        if keyboard.is_pressed('a'):
            if not is_active_a:
                ch_trumpet.play(sound_trumpet_do)
                print("▶ [트럼펫] 도 (C4) 재생 중...                          ", end='\r')
                is_active_a = True
        else:
            is_active_a = False

        if keyboard.is_pressed('s'):
            if not is_active_s:
                ch_trumpet.play(sound_trumpet_re)
                print("▶ [트럼펫] 레 (D4) 재생 중...                          ", end='\r')
                is_active_s = True
        else:
            is_active_s = False

        if keyboard.is_pressed('d'):
            if not is_active_d:
                ch_trumpet.play(sound_trumpet_mi)
                print("▶ [트럼펫] 미 (E4) 재생 중...                          ", end='\r')
                is_active_d = True
        else:
            is_active_d = False

        # ====================================================
        # 🥁 [드럼 트랙] 채널 2
        # ====================================================
        if keyboard.is_pressed('z'):
            if not is_active_z:
                ch_drum.play(sound_drum_kick)
                print("▶ [드럼] 킥 (Kick) 재생 중...                          ", end='\r')
                is_active_z = True
        else:
            is_active_z = False

        if keyboard.is_pressed('x'):
            if not is_active_x:
                ch_drum.play(sound_drum_snare)
                print("▶ [드럼] 스네어 (Snare) 재생 중...                     ", end='\r')
                is_active_x = True
        else:
            is_active_x = False

        if keyboard.is_pressed('c'):
            if not is_active_c:
                ch_drum.play(sound_drum_symbal)
                print("▶ [드럼] 심벌 (Symbal) 재생 중...                      ", end='\r')
                is_active_c = True
        else:
            is_active_c = False

        # ====================================================
        # 🪙 [신규 심벌즈 트랙] 채널 3 사용 (I, O, P 매핑)
        # ====================================================
        if keyboard.is_pressed('i'):
            if not is_active_i:
                ch_cymbal.play(sound_cymbal_crash)   # 큰 울림 (마디 시작점용)
                print("▶ [심벌즈] 크래시 (큰 울림) 재생 중...                 ", end='\r')
                is_active_i = True
        else:
            is_active_i = False

        if keyboard.is_pressed('o'):
            if not is_active_o:
                ch_cymbal.play(sound_cymbal_stick)   # 작은 울림 (중간 박자용)
                print("▶ [심벌즈] 스틱타격 (작은 울림) 재생 중...              ", end='\r')
                is_active_o = True
        else:
            is_active_o = False

        if keyboard.is_pressed('p'):
            if not is_active_p:
                ch_cymbal.play(sound_cymbal_choke)   # 숏 타격 (곡의 마무리용)
                print("▶ [심벌즈] 초크 (숏 타격) 재생 중...                   ", end='\r')
                is_active_p = True
        else:
            is_active_p = False

        # 하드웨어 스캔 수준의 고속 동시 감지를 위한 타임 딜레이
        time.sleep(0.005)

    except Exception as e:
        print(f"\n오류 발생: {e}")
        break

pygame.mixer.quit()