#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import argparse
from PIL import Image, ImageOps
from pathlib import Path
import logging

def setup_logging():
    """設置日誌記錄"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler('compression_log.txt', encoding='utf-8')
        ]
    )

def calculate_new_size(original_size, max_dimension):
    """
    計算新的圖片尺寸，保持長寬比
    
    Args:
        original_size (tuple): 原始圖片尺寸 (width, height)
        max_dimension (int or None): 最大邊長，如果為 None 或 0 則不調整尺寸
    
    Returns:
        tuple: 新的尺寸 (width, height)
    """
    width, height = original_size
    
    # 如果沒有指定最大尺寸或為0，則不調整尺寸
    if max_dimension is None or max_dimension == 0:
        return original_size
    
    if width <= max_dimension and height <= max_dimension:
        return original_size
    
    if width > height:
        new_width = max_dimension
        new_height = int((height * max_dimension) / width)
    else:
        new_height = max_dimension
        new_width = int((width * max_dimension) / height)
    
    return (new_width, new_height)

def compress_image(input_path, output_path, max_dimension=None, output_format=None, quality=85):
    """
    壓縮單張圖片
    
    Args:
        input_path (str): 輸入圖片路徑
        output_path (str): 輸出圖片路徑
        max_dimension (int or None): 最大邊長，如果為 None 則不調整尺寸
        output_format (str): 輸出格式 ('JPEG', 'PNG', 'WEBP' 等)
        quality (int): JPEG 品質 (1-100)
    
    Returns:
        bool: 是否成功壓縮
    """
    try:
        with Image.open(input_path) as img:
            # 轉換 RGBA 到 RGB（如果輸出格式不支持透明度）
            if output_format == 'JPEG' and img.mode in ('RGBA', 'LA', 'P'):
                # 創建白色背景
                background = Image.new('RGB', img.size, (255, 255, 255))
                if img.mode == 'P':
                    img = img.convert('RGBA')
                background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
                img = background
            
            # 自動旋轉圖片（基於 EXIF 數據）
            img = ImageOps.exif_transpose(img)
            
            # 計算新尺寸
            original_size = img.size
            new_size = calculate_new_size(original_size, max_dimension)
            
            # 調整圖片大小
            if new_size != original_size:
                img = img.resize(new_size, Image.Resampling.LANCZOS)
            
            # 保存圖片
            save_kwargs = {}
            if output_format == 'JPEG':
                save_kwargs = {
                    'format': 'JPEG',
                    'quality': quality,
                    'optimize': True
                }
            elif output_format == 'PNG':
                save_kwargs = {
                    'format': 'PNG',
                    'optimize': True
                }
            elif output_format == 'WEBP':
                save_kwargs = {
                    'format': 'WEBP',
                    'quality': quality,
                    'optimize': True
                }
            else:
                # 保持原格式
                save_kwargs = {'optimize': True}
                if img.format == 'JPEG':
                    save_kwargs['quality'] = quality
            
            img.save(output_path, **save_kwargs)
            
            # 計算壓縮比
            file_original_size = os.path.getsize(input_path)
            compressed_size = os.path.getsize(output_path)
            compression_ratio = (1 - compressed_size / file_original_size) * 100
            
            logging.info(f"✓ {input_path} -> {output_path}")
            if new_size != original_size:
                logging.info(f"  尺寸: {original_size} -> {new_size}")
            else:
                logging.info(f"  尺寸: {original_size} (未調整)")
            logging.info(f"  大小: {file_original_size:,} bytes -> {compressed_size:,} bytes ({compression_ratio:.1f}% 減少)")
            
            return True
            
    except Exception as e:
        logging.error(f"✗ 處理 {input_path} 時發生錯誤: {str(e)}")
        return False

def process_directory(directory, max_dimension=None, output_format=None, quality=90, 
                     recursive=False, overwrite=False, output_suffix="_compressed"):
    """
    處理目錄中的所有圖片
    
    Args:
        directory (str): 目錄路徑
        max_dimension (int or None): 最大邊長，如果為 None 則不調整尺寸
        output_format (str): 輸出格式
        quality (int): 圖片品質
        recursive (bool): 是否遞歸處理子目錄
        overwrite (bool): 是否覆寫原檔案
        output_suffix (str): 輸出檔案後綴
    """
    directory = Path(directory)
    supported_formats = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.tif', '.webp'}
    
    # 取得所有圖片檔案
    if recursive:
        image_files = [f for f in directory.rglob('*') if f.suffix.lower() in supported_formats]
    else:
        image_files = [f for f in directory.iterdir() if f.is_file() and f.suffix.lower() in supported_formats]
    
    if not image_files:
        logging.warning(f"在 {directory} 中沒有找到支援的圖片檔案")
        return
    
    logging.info(f"找到 {len(image_files)} 個圖片檔案")
    
    successful = 0
    failed = 0
    
    for image_file in image_files:
        try:
            if overwrite:
                output_path = image_file
                if output_format:
                    # 更改副檔名
                    if output_format.upper() == 'JPEG':
                        output_path = image_file.with_suffix('.jpg')
                    else:
                        output_path = image_file.with_suffix(f'.{output_format.lower()}')
            else:
                # 創建新檔名
                stem = image_file.stem
                if output_format:
                    if output_format.upper() == 'JPEG':
                        suffix = '.jpg'
                    else:
                        suffix = f'.{output_format.lower()}'
                else:
                    suffix = image_file.suffix
                
                output_path = image_file.parent / f"{stem}{output_suffix}{suffix}"
            
            if compress_image(str(image_file), str(output_path), max_dimension, 
                            output_format, quality):
                successful += 1
            else:
                failed += 1
                
        except Exception as e:
            logging.error(f"處理 {image_file} 時發生未預期的錯誤: {str(e)}")
            failed += 1
    
    logging.info(f"處理完成！成功: {successful}, 失敗: {failed}")

def main():
    parser = argparse.ArgumentParser(
        description="圖片壓縮工具 - 批量壓縮和轉換圖片格式",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用範例:
  python image_compressor.py --max-size 256 --format jpeg --quality 80
  python image_compressor.py --max-size 512 --format png --recursive
  python image_compressor.py --max-size 256 --format jpeg --overwrite
  python image_compressor.py --directory ./avatar --max-size 128 --format webp
        """
    )
    
    parser.add_argument(
        '--directory', '-d',
        type=str,
        default='.',
        help='要處理的目錄路徑 (預設: 目前目錄)'
    )
    
    parser.add_argument(
        '--max-size', '-s',
        type=int,
        default=None,
        help='最大邊長像素 (預設: 不調整尺寸，如果指定則調整到該尺寸)'
    )
    
    parser.add_argument(
        '--format', '-f',
        type=str,
        choices=['jpeg', 'jpg', 'png', 'webp'],
        help='輸出格式 (jpeg/jpg/png/webp, 預設: 保持原格式)'
    )
    
    parser.add_argument(
        '--quality', '-q',
        type=int,
        default=85,
        help='JPEG/WEBP 品質 1-100 (預設: 85)'
    )
    
    parser.add_argument(
        '--recursive', '-r',
        action='store_true',
        help='遞歸處理子目錄'
    )
    
    parser.add_argument(
        '--overwrite', '-o',
        action='store_true',
        help='覆寫原檔案 (預設: 建立新檔案)'
    )
    
    parser.add_argument(
        '--suffix',
        type=str,
        default='_compressed',
        help='輸出檔案後綴 (當不覆寫時使用, 預設: _compressed)'
    )
    
    args = parser.parse_args()
    
    # 設置日誌
    setup_logging()
    
    # 驗證參數
    if not os.path.exists(args.directory):
        logging.error(f"目錄不存在: {args.directory}")
        sys.exit(1)
    
    if not 1 <= args.quality <= 100:
        logging.error("品質必須在 1-100 之間")
        sys.exit(1)
    
    # 標準化格式名稱
    output_format = None
    if args.format:
        if args.format.lower() in ['jpeg', 'jpg']:
            output_format = 'JPEG'
        elif args.format.lower() == 'png':
            output_format = 'PNG'
        elif args.format.lower() == 'webp':
            output_format = 'WEBP'
    
    logging.info("=== 圖片壓縮工具 ===")
    logging.info(f"目錄: {args.directory}")
    if args.max_size:
        logging.info(f"最大尺寸: {args.max_size}px")
    else:
        logging.info("最大尺寸: 不調整 (保持原始尺寸)")
    logging.info(f"輸出格式: {output_format or '保持原格式'}")
    logging.info(f"品質: {args.quality}")
    logging.info(f"遞歸處理: {'是' if args.recursive else '否'}")
    logging.info(f"覆寫原檔: {'是' if args.overwrite else '否'}")
    if not args.overwrite:
        logging.info(f"檔案後綴: {args.suffix}")
    logging.info("-" * 50)
    
    # 處理圖片
    process_directory(
        args.directory,
        args.max_size,
        output_format,
        args.quality,
        args.recursive,
        args.overwrite,
        args.suffix
    )

if __name__ == "__main__":
    main()