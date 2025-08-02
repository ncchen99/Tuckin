# 圖片壓縮工具使用說明

這是一個用於批量壓縮和轉換圖片格式的Python腳本。

## ✨ 重要功能更新

**靈活的尺寸控制**: 現在預設不會調整圖片尺寸，只有當您明確指定 `--max-size` 參數時才會進行尺寸調整。這樣您可以：
- 只進行格式轉換而保持原始尺寸
- 只壓縮檔案大小而不改變解析度  
- 靈活控制何時需要調整尺寸

## 安裝依賴

```bash
pip install -r requirements.txt
```

或直接安裝 Pillow：
```bash
pip install Pillow
```

## 基本使用方法

### 1. 在目前資料夾只轉換格式，不調整尺寸
```bash
python image_compressor.py --format jpeg
```

### 2. 指定最大尺寸並壓縮
```bash
python image_compressor.py --max-size 512
```

### 3. 轉換PNG到JPEG並壓縮到256px
```bash
python image_compressor.py --format jpeg --max-size 256
```

### 4. 指定目錄處理
```bash
python image_compressor.py --directory ./avatar --max-size 128
```

### 5. 遞歸處理所有子資料夾
```bash
python image_compressor.py --recursive --max-size 256
```

### 6. 覆寫原檔案（小心使用！）
```bash
python image_compressor.py --overwrite --format jpeg
```

### 7. 設定JPEG品質
```bash
python image_compressor.py --format jpeg --quality 70
```

## 完整參數說明

| 參數          | 簡寫 | 說明                                  | 預設值      |
| ------------- | ---- | ------------------------------------- | ----------- |
| `--directory` | `-d` | 要處理的目錄路徑                      | 目前目錄    |
| `--max-size`  | `-s` | 最大邊長像素 (如果不指定則不調整尺寸) | 不調整尺寸  |
| `--format`    | `-f` | 輸出格式 (jpeg/png/webp)              | 保持原格式  |
| `--quality`   | `-q` | JPEG/WEBP品質 (1-100)                 | 85          |
| `--recursive` | `-r` | 遞歸處理子目錄                        | 否          |
| `--overwrite` | `-o` | 覆寫原檔案                            | 否          |
| `--suffix`    |      | 輸出檔案後綴                          | _compressed |

## 支援的格式

- **輸入**: JPG, JPEG, PNG, BMP, TIFF, TIF, WEBP
- **輸出**: JPEG, PNG, WEBP

## 使用範例

### 處理 avatar 資料夾中的圖片
```bash
cd assets/images/avatar/profile
python ../image_compressor.py --max-size 256 --format jpeg --quality 80
```

### 處理 icon 資料夾並保持PNG格式
```bash
cd assets/images/icon
python ../image_compressor.py --max-size 128 --format png
```

### 大量處理所有子資料夾
```bash
cd assets/images
python image_compressor.py --recursive --max-size 256 --format jpeg --quality 75
```

## 注意事項

1. **尺寸控制**: 預設不調整尺寸，只有指定 `--max-size` 時才會調整
2. **備份重要檔案**: 使用 `--overwrite` 前請先備份原檔案
3. **PNG轉JPEG**: 透明背景會被轉為白色背景
4. **品質設定**: JPEG品質 70-85 通常提供良好的壓縮比和畫質平衡
5. **WEBP格式**: 提供最佳的壓縮率，但相容性可能有限
6. **記錄檔**: 執行過程會產生 `compression_log.txt` 記錄檔

## 壓縮策略建議

### 不同類型圖片的建議設定：

**頭像圖片 (avatar)**:
```bash
python image_compressor.py --max-size 256 --format jpeg --quality 80
```

**圖示 (icon)**:
```bash
python image_compressor.py --max-size 128 --format png
```

**背景圖片 (background)**:
```bash
python image_compressor.py --max-size 1024 --format jpeg --quality 70
```

**食物圖片 (dish)**:
```bash
python image_compressor.py --max-size 512 --format jpeg --quality 75
```

**UI元件 (ui)**:
```bash
python image_compressor.py --max-size 256 --format png
```