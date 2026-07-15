import cv2
import time

def perform_curtain_call(frame):
    """캠 화면에 양옆에서 검은색 커튼이 닫히는 시각적 효과를 줍니다."""
    print("\n[커튼콜] 'a' 키가 눌렸습니다! 커튼콜을 진행합니다... 👏")
    
    # 프레임의 세로(height)와 가로(width) 길이 가져오기
    height, width = frame.shape[:2]
    
    # 양옆에서 중앙으로 픽셀을 이동시키며 검은색 사각형(커튼) 그리기
    for i in range(0, width // 2 + 10, 15):
        # 왼쪽 커튼
        cv2.rectangle(frame, (0, 0), (i, height), (0, 0, 0), -1)
        # 오른쪽 커튼
        cv2.rectangle(frame, (width - i, 0), (width, height), (0, 0, 0), -1)
        
        cv2.imshow('Webcam Curtain Call', frame)
        cv2.waitKey(20) # 숫자가 클수록 커튼이 천천히 닫힙니다.
        
    time.sleep(1) # 커튼이 완전히 닫힌 후 여운을 위해 1초 대기
    print("모든 공연이 끝났습니다. 카메라를 안전하게 종료합니다.")

def main():
    # 0번 기본 웹캠 장치 연결
    cap = cv2.VideoCapture(0)

    if not cap.isOpened():
        print("카메라를 열 수 없습니다. 장치를 확인해 주세요.")
        return

    print("🎥 카메라가 켜졌습니다!")
    print("👉 커튼콜을 보려면 영어 소문자 'a' 키를 누르세요.")
    print("👉 즉시 강제 종료하려면 'q' 키를 누르세요.")

    while True:
        # 카메라에서 프레임 읽어오기
        ret, frame = cap.read()
        if not ret:
            print("프레임을 읽어올 수 없습니다.")
            break

        # 읽어온 프레임을 화면에 출력
        cv2.imshow('Webcam Curtain Call', frame)

        # 1ms마다 키보드 입력 대기
        key = cv2.waitKey(1) & 0xFF

        # 'a' 키가 눌렸을 때
        if key == ord('a'):
            perform_curtain_call(frame)
            break  # 커튼콜이 끝나면 while 루프 탈출
            
        # 'q' 키가 눌렸을 때 (즉시 종료)
        elif key == ord('q'):
            print("공연이 취소되었습니다. (즉시 종료)")
            break

    # 루프를 빠져나오면 모든 리소스 정리 (진짜 마무리 작업)
    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()