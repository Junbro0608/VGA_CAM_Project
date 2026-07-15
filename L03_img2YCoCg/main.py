import numpy as np
from PIL import Image
import os

def convert_to_mem(input_image_path, output_mem_path):
    # 1. 이미지 로드 및 106x120으로 리사이징
    if not os.path.exists(input_image_path):
        print(f"❌ 파일을 찾을 수 없습니다: {input_image_path}")
        return

    img = Image.open(input_image_path).convert('RGB')
    img = img.resize((106, 120)) # (width, height)
    
    # 계산을 위해 float32 타입의 numpy 배열로 변환
    img_arr = np.array(img, dtype=np.float32)

    # 2. 8비트 RGB (0~255)를 하드웨어에 맞게 4비트 RGB (0~15)로 스케일 다운
    img_arr = np.clip(np.round(img_arr / 16.0), 0, 15)

    print(f"✅ 이미지 리사이징 완료: {img.size}")
    
    # 3. .mem 파일 열기 및 2x2 블록 순회
    with open(output_mem_path, 'w') as f:
        # y축으로 2칸씩, x축으로 2칸씩 이동하며 2x2 블록(4픽셀)을 가져옵니다.
        for y in range(0, 120, 2):
            for x in range(0, 106, 2):
                
                # 2x2 픽셀의 RGB 값 추출
                p_tl = img_arr[y, x]         # Top-Left (Y1)
                p_tr = img_arr[y, x+1]       # Top-Right (Y2)
                p_bl = img_arr[y+1, x]       # Bottom-Left (Y3)
                p_br = img_arr[y+1, x+1]     # Bottom-Right (Y4)

                # 각 픽셀별 명도(Y) 계산: Y = (R + 2G + B) / 4
                # 0~15 사이의 4비트 양수
                y_tl = int(np.clip(np.round((p_tl[0] + 2*p_tl[1] + p_tl[2]) / 4.0), 0, 15))
                y_tr = int(np.clip(np.round((p_tr[0] + 2*p_tr[1] + p_tr[2]) / 4.0), 0, 15))
                y_bl = int(np.clip(np.round((p_bl[0] + 2*p_bl[1] + p_bl[2]) / 4.0), 0, 15))
                y_br = int(np.clip(np.round((p_br[0] + 2*p_br[1] + p_br[2]) / 4.0), 0, 15))

                # 색차(Co, Cg)는 2x2 블록의 평균 색상을 사용하여 하나만 계산 (압축)
                avg_r = (p_tl[0] + p_tr[0] + p_bl[0] + p_br[0]) / 4.0
                avg_g = (p_tl[1] + p_tr[1] + p_bl[1] + p_br[1]) / 4.0
                avg_b = (p_tl[2] + p_tr[2] + p_bl[2] + p_br[2]) / 4.0

                # Co = (R - B) / 2
                # Cg = (-R + 2G - B) / 4
                # 색차는 음수가 될 수 있으므로 4비트 signed 범위(-8 ~ 7)로 클램핑
                co = int(np.clip(np.round((avg_r - avg_b) / 2.0), -8, 7))
                cg = int(np.clip(np.round((-avg_r + 2*avg_g - avg_b) / 4.0), -8, 7))

                # UnScaleImage는 unsigned 4비트 값에서 8을 빼서 signed 색차를 복원한다.
                # 따라서 -8~7 값을 offset-binary 0~15로 저장한다.
                co_4bit = co + 8
                cg_4bit = cg + 8

                # 4. 24비트 데이터 조립 (비트 시프트 연산)
                # UnScaleImage 모듈의 데이터 순서: [Cg, Co, Y_br, Y_bl, Y_tr, Y_tl]
                word = (cg_4bit << 20) | (co_4bit << 16) | (y_br << 12) | (y_bl << 8) | (y_tr << 4) | y_tl

                # 6자리 16진수(대문자)로 변환하여 파일에 한 줄씩 쓰기
                f.write(f"{word:06X}\n")

    print(f"✅ 변환 완료! 총 3180 라인이 생성되었습니다: {output_mem_path}")

# ==========================================
# 실행 부분: 실제 이미지 경로와 저장할 .mem 파일 이름 지정
# ==========================================
if __name__ == "__main__":
    # 테스트할 이미지 파일 경로 (jpg, png 등)
    input_file = "imageb3.png" 
    
    # 생성될 메모리 초기화 파일 이름
    output_file = "image_b3.mem"  
    
    convert_to_mem(input_file, output_file)
