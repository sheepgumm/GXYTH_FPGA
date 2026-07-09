import numpy as np
import os
import matplotlib.pyplot as plt
import pandas as pd
from tqdm import tqdm
import struct
def read_raw(file_path, width=640, height=512, bit_depth=16):
    """
    读取原始 RAW 图像数据，并返回图像帧
    """
    frame_size = width * height * (bit_depth // 8)
    file_size = os.path.getsize(file_path)
    num_frames = file_size // frame_size
    
    if file_size % frame_size != 0:
        raise ValueError(f"文件大小不符合图像的预期格式，请检查文件或分辨率设置。")
    
    frames = []
    with open(file_path, 'rb') as f:
        for i in range(num_frames):
            frame_data = f.read(frame_size)
            frame = np.frombuffer(frame_data, dtype='<u2').reshape((height, width))
            frames.append(frame)
    
    return np.array(frames), num_frames

def interpolate_blind_pixels(K, B):
    """
    对盲元像素进行插值，使用相邻像素的K和B进行补偿
    """
    # 获取盲元的掩码：盲元是 K == 0 或者 B < -1000
    mask = (K == 0) | (B < -1000)  # 使用逻辑“或”运算符
    
    # 获取图像大小
    height, width = K.shape
    
    # 遍历盲元像素，进行插值
    # for i in range(0, height-1):
    #     for j in range(0, width-1):
    for i in range(height):
        for j in range(width):
            # if mask[i, j]:  # 如果是盲元像素
            #     # 获取相邻像素的B值和K值（上下左右四个像素的加权平均）
            #     neighbors_K = [
            #         K[i-1, j], K[i+1, j],   # 上下
            #         K[i, j-1], K[i, j+1]    # 左右
            #     ]
            #     neighbors_B = [
            #         B[i-1, j], B[i+1, j],   # 上下
            #         B[i, j-1], B[i, j+1]    # 左右
            #     ]
                
            #     # 使用相邻像素的K值和B值进行加权平均
            #     K_interp = np.mean(neighbors_K)  # K的插值
            #     B_interp = np.mean(neighbors_B)  # B的插值
                
            # 更新 K 和 B
            if K[i, j] >= 2 :
                K[i, j] = 1 
            if B[i, j] < -5000 or B[i, j] > 5000:
                B[i, j] = 1
                # B[i, j] = B_interp - 12000
            # elif B[i, j] < -1000:
            #     K[i, j] = K[i, j] - 0.15
            # else:
            #     K[i, j] = K_interp 
                   
    return K, B

def two_point_calibration(T0_DN, T0_avg, T1_DN, T1_avg, T):
    """
    使用两点法进行非均匀校正，同时处理盲元（K=0的像素）
    """
    # 计算K和B
    K = (T0_DN - T1_DN) / (T0_avg - T1_avg)
    K = np.maximum(K, 0)  # 保证 K 为非负值
    B = (T1_DN * T0_avg - T0_DN * T1_avg) / (T0_avg - T1_avg)
    
    # 插值处理盲元的K和B值
    K, B = interpolate_blind_pixels(K, B)
    
    # 对 K 和 B 进行四舍五入
    K = np.round(K, 2)  # 对 K 值保留两位小数
    B = np.round(B)     # 对 B 值保留整数部分
    
    # 校正
    T_NUC = K * T + B
    
    return T_NUC, K, B
def detect_and_correct_blind_pixels_with_progress(image, window_size=16, progress_bar=None):
    # 定义局部窗口半径
    radius = window_size // 2
    width = image.shape[1]
    height = image.shape[0]
    # 初始化盲元信息
    blind_pixel_info = []
    corrected_image = image.copy()

    # 使用tqdm显示进度条
    print("开始检测和修复盲元...")
    for row in range(height):
        for col in range(width):
            # 提取局部窗口 使用min和max防止像素越界
            row_start = max(row - radius, 0)
            row_end = min(row + radius + 1, height)
            col_start = max(col - radius, 0)
            col_end = min(col + radius + 1, width)

            local_window = image[row_start:row_end, col_start:col_end]

            # 计算局部均值和标准差
            local_mean = np.mean(local_window)
            local_std = np.std(local_window)

            # 定义局部正常范围
            lower_bound = local_mean - 3 * local_std
            upper_bound = local_mean + 3 * local_std

            # 判断当前像素是否为盲元
            if image[row, col] < lower_bound or image[row, col] > upper_bound:
                blind_pixel_info.append((col, row, image[row, col]))

                # 临近像素插值：计算去除盲元后的均值（排除盲元）
                valid_pixels = local_window[
                    (local_window >= lower_bound) & (local_window <= upper_bound)
                ]
                if valid_pixels.size > 0:
                    corrected_image[row, col] = np.mean(valid_pixels)
                else:
                    # 如果无有效像素，保留原值
                    corrected_image[row, col] = local_mean
        
        # 更新进度条
        if progress_bar:
            progress_bar["value"] = (row + 1) / height * 100
            root.update_idletasks()
        
    # 输出盲元信息
    blind_pixel_count = len(blind_pixel_info)
    print(f"\n盲元个数: {blind_pixel_count}")

    return corrected_image, blind_pixel_info, blind_pixel_count
def display_frames(first_frame, corrected_frame):
    """
    显示原始图像和校正后的图像
    """
    fig, axes = plt.subplots(2, 1, figsize=(10, 16))  # 2行1列
    
    # 显示原始第一帧
    im1 = axes[0].imshow(first_frame, cmap='gray', vmin=0, vmax=16383)
    axes[0].set_title("First Frame (Before Calibration)")
    fig.colorbar(im1, ax=axes[0])
    
    # 显示校正后的图像
    im2 = axes[1].imshow(corrected_frame, cmap='gray', vmin=0, vmax=16383)
    axes[1].set_title("Corrected Frame")
    fig.colorbar(im2, ax=axes[1])
    
    plt.tight_layout()
    plt.show()
def save_raw(file_path, data, width=640, height=512, bit_depth=16):
    """
    将图像数据保存为 raw 格式，使用大端存储
    """
    frame_size = width * height * (bit_depth // 8)
    data = data.astype('>u2')  # 确保数据是16位大端格式
    with open(file_path, 'wb') as f:
        f.write(data.tobytes())
def save_kb_to_excel(K, B, filename):
    """
    将 K 和 B 参数保存到 Excel 文件，格式为：（列，行）， K 值， B 值
    """
    # 获取像素的行列号
    height, width = K.shape
    pixel_positions = [(col, row) for row in range(height) for col in range(width)]
    
    # 将 K 和 B 扁平化为一维数组
    k_values = K.flatten()
    b_values = B.flatten()
    
    # 创建一个 DataFrame，其中第一列为像素位置（列，行），第二列为 K 值，第三列为 B 值
    kb_data = {
        'Pixel (Column, Row)': [f"({col}, {row})" for (col, row) in pixel_positions],
        'K': k_values,
        'B': b_values
    }
    df = pd.DataFrame(kb_data)
    
    # 将 DataFrame 保存为 Excel
    df.to_excel(filename, index=False)

        # print(f"K 和 B 参数已保存到 {filename}")

def save_kb_raw(K, B, K_file='K.raw', B_file='B.raw'):
    """
    保存 K 和 B 参数为 RAW 格式，K 1 字节，B 2 字节
    """
    # 保存 K 参数
    K_data = np.zeros(K.shape, dtype=np.uint8)
    for i in range(K.shape[0]):
        for j in range(K.shape[1]):
            # 整数部分
            int_part = int(K[i, j])
            # if K > 2 :
            #     print(K[i,j])
            # 小数部分，保留两位
            # frac_part = int((K[i, j]* 100 - int_part* 100))
            frac_part = int((K[i, j] - int_part) * 128)  # 小数部分 * 128，并取整
            # K 1字节，最高位存储整数部分，剩余7位存储小数部分
            K_data[i, j] = (int_part << 7) | frac_part  # 整数部分左移7位，小数部分填充到后7位
            # if i==0 and j == 0:
            #     print(K_data[i, j])
            #     print(K[i, j])
    with open(K_file, 'wb') as f:
        f.write(K_data.tobytes())  # 保存 K

    # # 保存 B 参数
    # B_data = np.zeros(B.shape, dtype=np.uint16)
    # for i in range(B.shape[0]):
    #     for j in range(B.shape[1]):
    #         if B[i, j] < 0:
    #             B_data[i, j] = (1 << 15) | abs(int(B[i, j]))  # 负数符号位
    #         else:
    #             B_data[i, j] = int(B[i, j])  # 正数

    # with open(B_file, 'wb') as f:
    #     f.write(B_data.tobytes())  # 保存 B
    
    # 保存 B 参数（大端存储）
    B_data = np.zeros(B.shape, dtype=np.uint16)
    with open(B_file, 'wb') as f:
        for i in range(B.shape[0]):
            for j in range(B.shape[1]):
                # 获取 B 的 16 位二进制表示，符号位处理
                if B[i, j] < 0:
                    B_value = (1 << 15) | abs(int(B[i, j]))  # 负数符号位
                else:
                    B_value = int(B[i, j])  # 正数，直接保存

                # 使用 Python 原生整数类型调用 to_bytes 方法，确保大端存储
                f.write(B_value.to_bytes(2, byteorder='big'))  # 每个16位值按大端格式写入文件     

    print(f"K 和 B 参数已保存到 {K_file} 和 {B_file}")
# def detect_blind_pixels(input_file, width=640, height=512, window_size=8):
#     """
#     检测盲元并返回盲元的坐标列表。

#     Args:
#         input_file (str): 输入的16bit RAW图像文件路径。
#         width (int): 图像宽度，默认640。
#         height (int): 图像高度，默认512。
#         window_size (int): 局部窗口大小，默认5。

#     Returns:
#         list: 包含盲元的坐标列表，每个元素为 (col, row)。
#     """
#     # 每个像素2字节（16位）
#     pixel_depth = 2
#     frame_size = width * height * pixel_depth

#     # 读取RAW文件
#     with open(input_file, 'rb') as f:
#         raw_data = f.read()

#     # 检查文件大小是否为整数倍的单帧大小
#     if len(raw_data) % frame_size != 0:
#         raise ValueError(f"文件大小不正确，不能整除单帧大小 {frame_size} 字节")

#     # 提取第一帧数据
#     first_frame_data = raw_data[:frame_size]

#     # 将大端字节序解码为16位无符号整数
#     image = np.frombuffer(first_frame_data, dtype='>u2').reshape((height, width))

#     # 定义局部窗口半径
#     radius = window_size // 2

#     # 初始化盲元坐标列表
#     blind_pixel_coords = []

#     # 使用tqdm显示进度条
#     print("开始检测盲元...")
#     for row in tqdm(range(height), desc="检测进度", unit="行"):
#         for col in range(width):
#             # 提取局部窗口
#             row_start = max(row - radius, 0)
#             row_end = min(row + radius + 1, height)
#             col_start = max(col - radius, 0)
#             col_end = min(col + radius + 1, width)

#             local_window = image[row_start:row_end, col_start:col_end]

#             # 计算局部均值和标准差
#             local_mean = np.mean(local_window)
#             local_std = np.std(local_window)

#             # 定义局部正常范围
#             lower_bound = local_mean - 3 * local_std
#             upper_bound = local_mean + 3 * local_std

#             # 判断当前像素是否为盲元
#             if image[row, col] < lower_bound or image[row, col] > upper_bound:
#                 blind_pixel_coords.append((col, row))

#     print(f"检测完成，盲元个数: {len(blind_pixel_coords)}")
#     # print("盲元坐标 (列, 行) 和灰度值:")
#     # for col, row in blind_pixel_coords:
#     #     print(f"(列: {col}, 行: {row}")
#     return blind_pixel_coords

def process_and_save_blind_pixels(input_file, output_file, blind_pixel_coords, width=640, height=512):
    """
    标记盲元并保存为16bit大端格式的二进制文件。

    Args:
        input_file (str): 输入的8bit BIN图像文件路径。
        output_file (str): 输出的16bit BIN图像文件路径。
        blind_pixel_coords (list): 盲元的坐标列表。
        width (int): 图像宽度，默认640。
        height (int): 图像高度，默认512。
    """
    # 读取8bit图像数据
    with open(input_file, 'rb') as f:
        raw_data = f.read()

    # 检查文件大小是否正确
    if len(raw_data) != width * height:
        raise ValueError("输入文件大小与指定宽高不匹配！")

    # 将图像数据转为二维数组
    image = np.frombuffer(raw_data, dtype=np.uint8).reshape((height, width))

    # 初始化标记后的16位数据数组
    processed_image = np.zeros((height, width), dtype=np.uint16)

    # 使用tqdm显示进度条
    print("开始标记盲元...")
    for row in tqdm(range(height), desc="标记进度", unit="行"):
        for col in range(width):
            if (col, row) in blind_pixel_coords:
                # 盲元标记规则：10000000（高8位） + 原始8bit数据
                processed_image[row, col] = 0b1000000000000000 | image[row, col]
            else:
                # 正常像素标记规则：00000000（高8位） + 原始8bit数据
                processed_image[row, col] = 0b0000000000000000 | image[row, col]

    # 将16位图像数据转换为大端字节序并保存为二进制文件
    with open(output_file, 'wb') as f:
        f.write(processed_image.byteswap().tobytes())

    print(f"处理完成，结果已保存到文件: {output_file}")
def merge_bin_files(file1_path, file2_path, output_file_path, width=640, height=512):
    pixel_count = width * height

    with open(file1_path, 'rb') as file1, open(file2_path, 'rb') as file2, open(output_file_path, 'wb') as output:
        # Read both files into memory
        file1_data = file1.read()
        file2_data = file2.read()

        # Check file size consistency
        if len(file1_data) != pixel_count * 2 or len(file2_data) != pixel_count * 2:
            raise ValueError("Input files do not match the expected size for 640x512 16-bit images.")

        # Iterate through each pixel and merge
        for i in range(pixel_count):
            # Read one pixel (2 bytes) from each file
            pixel1 = file1_data[i * 2: (i + 1) * 2]
            pixel2 = file2_data[i * 2: (i + 1) * 2]

            # Write both pixels to the output file in sequence
            output.write(pixel1)
            output.write(pixel2)
#bin文件拼接（以页为单位，不足补1）
def combine_bin_files_page_aligned(file1, file2, output_file, page_size=256):
    # 读取第一个bin文件内容
    with open(file1, 'rb') as f1:
        data1 = f1.read()
    
    # 计算第一个文件的长度
    len1 = len(data1)
    
    # 计算需要填充的字节数，以使下一个数据块从新的页面开始
    padding_size = (page_size - (len1 % page_size)) % page_size
    data1_padded = data1 + b'\xFF' * padding_size  # 使用 0xFF 进行填充

    # 计算第一个文件的起始和结束地址
    start_addr_file1 = 0
    end_addr_file1 = len1 - 1

    # 读取第二个bin文件内容
    with open(file2, 'rb') as f2:
        data2 = f2.read()

    # 第二个文件将从填充后的地址开始
    start_addr_file2 = start_addr_file1 + len(data1_padded)
    end_addr_file2 = start_addr_file2 + len(data2) - 1

    # 合并两个文件的数据
    combined_data = data1_padded + data2

    # 将合并后的数据写入到输出文件
    with open(output_file, 'wb') as out_f:
        out_f.write(combined_data)
    
    # 输出文件的起始和结束地址
    print(f"{file1} 的起始地址: {start_addr_file1}, 结束地址: {end_addr_file1}")
    print(f"{file2} 的起始地址: {start_addr_file2}, 结束地址: {end_addr_file2}")
    print(f"合并后的文件已保存到 {output_file}")
def funtion1(T0_file,T1_file,T_file,save_dir,top_bin,save_bin_name):
    T0_frames, num_frames_T0 = read_raw(T0_file)
    T1_frames, num_frames_T1 = read_raw(T1_file)
    raw_iamge,_ = read_raw(T_file)
    
    # 计算低温和高温黑体图像的平均值
    T0_avg = np.mean(T0_frames, axis=0)
    T0_DN = np.mean(T0_avg)
    
    T1_avg = np.mean(T1_frames, axis=0)
    T1_DN = np.mean(T1_avg)
    
    print(f"T0 文件帧数: {num_frames_T0}")
    print(f"T1 文件帧数: {num_frames_T1}")

    T_raw_frames, num_frames_T = read_raw(T_file)  # 只取第一帧
    # 获取第一帧
    first_frame = T_raw_frames[0]
    
    # 应用两点法校正，同时处理盲元（使用邻域插值修正K和B）
    T_corrected, K, B = two_point_calibration(T0_DN, T0_avg, T1_DN, T1_avg, first_frame)
    # 步骤1: 检测盲元
    T_corrected_compensate_blind,blind_pixels,_ = detect_and_correct_blind_pixels_with_progress(raw_iamge[0])

    
    # 显示原始第一帧和校正后的图像
    display_frames(first_frame, T_corrected_compensate_blind)
    
    #保存校正后的图像为 RAW 格式
    # output_file = '校正后的图像6.raw'
    # save_raw(output_file, T_corrected)
    
    # print(f"校正后的图像已保存到 {output_file}")
    
    # 将 K 和 B 参数保存到 Excel
    save_kb_to_excel(K, B, filename = save_dir + '\k_b_800Hz.xlsx')
    print("K 和 B 参数已保存到 k_b_800Hz.xlsx")
    # 将 K 和 B 保存为 raw 文件
    save_kb_raw(K, B, K_file= save_dir + '\\k_bin_8bit.bin', 
                B_file= save_dir + '\\b_bin_16bit.bin')

    # # 步骤1: 检测盲元
    # blind_pixels = detect_blind_pixels(T_file)
    
    # 步骤2: 标记盲元并保存
    process_and_save_blind_pixels(save_dir + '\k_bin_8bit.bin',save_dir + '\k_blind_bin_16bit.bin', blind_pixels)
    #交替合成k、b文件
    merge_bin_files(save_dir + '\\k_blind_bin_16bit.bin', save_dir + '\\b_bin_16bit.bin', save_dir + '\\k_b_combine_bin.bin')
    print('k_b_combine_bin.bin已保存')
    #bin文件拼接（以页为单位，不足补1）
    combine_bin_files_page_aligned(
    top_bin,            # 第一个bin文件路径
    save_dir + '\\k_b_combine_bin.bin',            # 第二个bin文件路径
    # r'C:\Users\Administrator\Desktop\combine_bin' +'\\' + save_bin_name) 
    save_dir +'\\' + save_bin_name) 
    print('bin文件制作完成')
if __name__ == "__main__":
    save_dir = r"C:\Users\Administrator\xwechat_files\wxid_o4ca5ivx7gnl11_57db\msg\file\2026-01\20260129163525定标测试\kb"
    # 加载低温和高温黑体图像数据
    #低温 黑色
    T0_file = r"C:\Users\Administrator\xwechat_files\wxid_o4ca5ivx7gnl11_57db\msg\file\2026-01\20260129163525定标测试\100us_level1.dat"
    #高温 白色
    T1_file = r"C:\Users\Administrator\xwechat_files\wxid_o4ca5ivx7gnl11_57db\msg\file\2026-01\20260129163525定标测试\100us_level2.dat"
    # 读取待校正的原始图像 检测盲元的RAW文件路径
    T_file = r"C:\Users\Administrator\xwechat_files\wxid_o4ca5ivx7gnl11_57db\msg\file\2026-01\20260129163525定标测试\4ms_img.dat"
    #fpga要烧录的bin文件
    top_bin = r"C:\Users\Administrator\xwechat_files\wxid_o4ca5ivx7gnl11_57db\msg\file\2026-01\20260129163525定标测试\top.bin"
    save_bin_name = '2026-1-5_YGS.bin'
    funtion1(T0_file,T1_file,T_file,save_dir,top_bin,save_bin_name)