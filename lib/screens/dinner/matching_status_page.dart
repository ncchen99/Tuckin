import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:tuckin/components/common/header_bar.dart';
import 'package:tuckin/utils/index.dart';

class MatchingStatusPage extends StatefulWidget {
  const MatchingStatusPage({super.key});

  @override
  State<MatchingStatusPage> createState() => _MatchingStatusPageState();
}

class _MatchingStatusPageState extends State<MatchingStatusPage> {
  // 配對狀態：0-等待中，1-配對成功，2-配對失敗
  int _matchingStatus = 0;
  // 模擬剩餘時間（秒）
  int _remainingSeconds = 120;
  // 倒數計時器
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // 模擬配對過程
    _startMatching();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // 開始配對流程
  void _startMatching() {
    setState(() {
      _matchingStatus = 0; // 設置為等待中
      _remainingSeconds = 120; // 2分鐘倒數
    });

    // 啟動倒數計時器
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        // 模擬配對結果 (這裡隨機決定成功或失敗，實際應用中應由後端決定)
        final random = Random();
        final isSuccess = random.nextBool();

        setState(() {
          _matchingStatus = isSuccess ? 1 : 2;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background/bg1.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 頂部導航欄
              HeaderBar(
                title: '配對狀態',
                onNotificationTap: () {
                  // 導航到通知頁面
                  Navigator.pushNamed(context, '/notifications');
                },
                onProfileTap: () {
                  // 導航到個人資料頁面
                  Navigator.pushNamed(context, '/user_settings');
                },
              ),

              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 根據配對狀態顯示不同內容
                      if (_matchingStatus == 0)
                        _buildMatchingInProgress()
                      else if (_matchingStatus == 1)
                        _buildMatchingSuccess()
                      else
                        _buildMatchingFailed(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 配對進行中UI
  Widget _buildMatchingInProgress() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;

    return Column(
      children: [
        // 動畫或圖示
        Container(
          width: 200.w,
          height: 200.w,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Image.asset(
              'assets/images/icon/matching.png',
              width: 120.w,
              height: 120.w,
              // 如果沒有合適的圖示，可以使用CircularProgressIndicator代替
              errorBuilder: (context, error, stackTrace) {
                return CircularProgressIndicator(
                  color: const Color(0xFF23456B),
                  strokeWidth: 8.w,
                );
              },
            ),
          ),
        ),
        SizedBox(height: 30.h),
        // 標題
        Text(
          '正在為您尋找配對...',
          style: TextStyle(
            fontSize: 24.sp,
            fontFamily: 'OtsutomeFont',
            color: const Color(0xFF23456B),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 20.h),
        // 倒數計時
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: const Color(0xFF23456B), width: 1.5),
          ),
          child: Text(
            '剩餘時間: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 18.sp,
              fontFamily: 'OtsutomeFont',
              color: const Color(0xFF23456B),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: 30.h),
        // 取消按鈕
        SizedBox(
          width: 200.w,
          height: 50.h,
          child: ElevatedButton(
            onPressed: () {
              // 取消配對，返回上一頁
              _timer.cancel();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE57373),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25.r),
              ),
            ),
            child: Text(
              '取消配對',
              style: TextStyle(
                fontSize: 18.sp,
                fontFamily: 'OtsutomeFont',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 配對成功UI
  Widget _buildMatchingSuccess() {
    return Column(
      children: [
        // 成功圖示
        Container(
          width: 200.w,
          height: 200.w,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green, width: 3.w),
          ),
          child: Center(
            child: Icon(Icons.check_circle, color: Colors.green, size: 100.w),
          ),
        ),
        SizedBox(height: 30.h),
        // 標題
        Text(
          '配對成功！',
          style: TextStyle(
            fontSize: 28.sp,
            fontFamily: 'OtsutomeFont',
            color: const Color(0xFF23456B),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 20.h),
        // 內容
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(color: const Color(0xFF23456B), width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                '您已成功與 3 位用戶配對！',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontFamily: 'OtsutomeFont',
                  color: const Color(0xFF23456B),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                '請在接下來的頁面中確認出席並選擇餐廳。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontFamily: 'OtsutomeFont',
                  color: const Color(0xFF23456B),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 30.h),
        // 下一步按鈕
        SizedBox(
          width: 200.w,
          height: 50.h,
          child: ElevatedButton(
            onPressed: () {
              // 導航到出席確認頁面
              Navigator.pushReplacementNamed(
                context,
                '/attendance_confirmation',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25.r),
              ),
            ),
            child: Text(
              '下一步',
              style: TextStyle(
                fontSize: 18.sp,
                fontFamily: 'OtsutomeFont',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 配對失敗UI
  Widget _buildMatchingFailed() {
    return Column(
      children: [
        // 失敗圖示
        Container(
          width: 200.w,
          height: 200.w,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.red, width: 3.w),
          ),
          child: Center(
            child: Icon(Icons.error, color: Colors.red, size: 100.w),
          ),
        ),
        SizedBox(height: 30.h),
        // 標題
        Text(
          '配對未成功',
          style: TextStyle(
            fontSize: 28.sp,
            fontFamily: 'OtsutomeFont',
            color: const Color(0xFF23456B),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 20.h),
        // 內容
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(color: const Color(0xFF23456B), width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                '抱歉，目前沒有足夠的用戶可供配對。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontFamily: 'OtsutomeFont',
                  color: const Color(0xFF23456B),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                '請稍後再試，或選擇其他日期。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontFamily: 'OtsutomeFont',
                  color: const Color(0xFF23456B),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 30.h),
        // 返回按鈕
        SizedBox(
          width: 200.w,
          height: 50.h,
          child: ElevatedButton(
            onPressed: () {
              // 返回預約頁面
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF23456B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25.r),
              ),
            ),
            child: Text(
              '返回',
              style: TextStyle(
                fontSize: 18.sp,
                fontFamily: 'OtsutomeFont',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: 15.h),
        // 重試按鈕
        TextButton(
          onPressed: () {
            // 重新開始配對
            _startMatching();
          },
          child: Text(
            '重新配對',
            style: TextStyle(
              fontSize: 16.sp,
              fontFamily: 'OtsutomeFont',
              color: const Color(0xFF23456B),
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
