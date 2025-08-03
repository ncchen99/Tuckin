#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
快速開始腳本 - 針對不同資料夾的預設壓縮設定
"""

import subprocess
import os
import sys

def run_compression(directory, max_size, format_type, quality=85):
    """執行圖片壓縮"""
    cmd = [
        sys.executable, 
        "image_compressor.py",
        "--directory", directory,
        "--max-size", str(max_size),
        "--format", format_type,
        "--quality", str(quality)
    ]
    
    print(f"正在處理 {directory} 資料夾...")
    print(f"命令: {' '.join(cmd)}")
    print("-" * 50)
    
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        print(result.stdout)
        if result.stderr:
            print("警告:", result.stderr)
    except subprocess.CalledProcessError as e:
        print(f"錯誤: {e}")
        print(e.stderr)
    
    print("=" * 50)

def main():
    """主函數 - 提供預設的壓縮方案"""
    
    print("圖片壓縮工具 - 快速開始")
    print("=" * 50)
    
    # 檢查是否在正確的目錄
    if not os.path.exists("image_compressor.py"):
        print("錯誤: 請確保在包含 image_compressor.py 的目錄中執行此腳本")
        return
    
    compression_plans = [
        {
            "name": "頭像圖片 (avatar)",
            "directory": "./avatar",
            "max_size": 256,
            "format": "jpeg",
            "quality": 80
        },
        {
            "name": "圖示 (icon)", 
            "directory": "./icon",
            "max_size": 128,
            "format": "png",
            "quality": 85
        },
        {
            "name": "食物圖片 (dish)",
            "directory": "./dish", 
            "max_size": 512,
            "format": "jpeg",
            "quality": 75
        },
        {
            "name": "背景圖片 (background)",
            "directory": "./background",
            "max_size": 1024, 
            "format": "jpeg",
            "quality": 70
        },
        {
            "name": "UI元件 (ui)",
            "directory": "./ui",
            "max_size": 256,
            "format": "png",
            "quality": 85
        }
    ]
    
    print("選擇要處理的資料夾:")
    for i, plan in enumerate(compression_plans, 1):
        print(f"{i}. {plan['name']} - {plan['max_size']}px, {plan['format'].upper()}, 品質{plan['quality']}")
    print("6. 處理所有資料夾")
    print("0. 離開")
    
    try:
        choice = input("\n請選擇 (0-6): ").strip()
        
        if choice == "0":
            print("已離開")
            return
        elif choice == "6":
            # 處理所有資料夾
            for plan in compression_plans:
                if os.path.exists(plan["directory"]):
                    run_compression(
                        plan["directory"],
                        plan["max_size"], 
                        plan["format"],
                        plan["quality"]
                    )
                else:
                    print(f"跳過 {plan['directory']} (資料夾不存在)")
        elif choice in ["1", "2", "3", "4", "5"]:
            plan = compression_plans[int(choice) - 1]
            if os.path.exists(plan["directory"]):
                run_compression(
                    plan["directory"],
                    plan["max_size"],
                    plan["format"], 
                    plan["quality"]
                )
            else:
                print(f"錯誤: 資料夾 {plan['directory']} 不存在")
        else:
            print("無效的選擇")
            
    except KeyboardInterrupt:
        print("\n操作已取消")
    except Exception as e:
        print(f"發生錯誤: {e}")

if __name__ == "__main__":
    main()