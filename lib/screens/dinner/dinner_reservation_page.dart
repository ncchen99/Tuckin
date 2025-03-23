import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/components/common/header_bar.dart';
import 'package:tuckin/utils/index.dart';

class DinnerReservationPage extends StatefulWidget {
  const DinnerReservationPage({super.key});

  @override
  State<DinnerReservationPage> createState() => _DinnerReservationPageState();
}

class _DinnerReservationPageState extends State<DinnerReservationPage> {
  // 用戶選擇的日期 (0: 星期一, 1: 星期四)
  int? _selectedDate;
  // 是否僅限成大學生參與
  bool _onlyNckuStudents = true;

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
                title: '聚餐預約',
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
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20.h),
                        // 標題
                        Text(
                          '選擇聚餐日期',
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontFamily: 'OtsutomeFont',
                            color: const Color(0xFF23456B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        // 說明文字
                        Text(
                          '請選擇您希望參加的聚餐日期，每週僅能參加一次聚餐活動',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontFamily: 'OtsutomeFont',
                            color: const Color(0xFF23456B),
                          ),
                        ),
                        SizedBox(height: 30.h),

                        // 日期選擇區域
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 星期一選項
                            _buildDateCard(
                              context,
                              '星期一',
                              'assets/images/icon/tue.png',
                              '晚間 7:00',
                              0,
                            ),
                            // 星期四選項
                            _buildDateCard(
                              context,
                              '星期四',
                              'assets/images/icon/thu.png',
                              '晚間 7:00',
                              1,
                            ),
                          ],
                        ),

                        SizedBox(height: 30.h),

                        // 預約截止時間提示
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(15.r),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: const Color(0xFF23456B),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '預約截止時間：周五午夜 12:00',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontFamily: 'OtsutomeFont',
                              color: const Color(0xFF23456B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        SizedBox(height: 20.h),

                        // 成大限定選項
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(15.r),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: const Color(0xFF23456B),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              CustomCheckbox(
                                value: _onlyNckuStudents,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _onlyNckuStudents = value;
                                    });
                                  }
                                },
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  '僅限成大學生參與',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontFamily: 'OtsutomeFont',
                                    color: const Color(0xFF23456B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 50.h),

                        // 提交按鈕
                        Center(
                          child: SizedBox(
                            width: 200.w,
                            height: 50.h,
                            child: ElevatedButton(
                              onPressed:
                                  _selectedDate != null
                                      ? () {
                                        // 導航到配對狀態頁面
                                        Navigator.pushNamed(
                                          context,
                                          '/matching_status',
                                        );
                                      }
                                      : null, // 如果未選擇日期，則禁用按鈕
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF23456B),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25.r),
                                ),
                              ),
                              child: Text(
                                '開始配對',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontFamily: 'OtsutomeFont',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 30.h),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 構建日期選擇卡片
  Widget _buildDateCard(
    BuildContext context,
    String day,
    String iconPath,
    String time,
    int dateIndex,
  ) {
    final isSelected = _selectedDate == dateIndex;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = dateIndex;
        });
      },
      child: Container(
        width: 150.w,
        padding: EdgeInsets.all(15.r),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF23456B)
                  : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: const Color(0xFF23456B), width: 1.5),
        ),
        child: Column(
          children: [
            // 日期圖示
            Image.asset(
              iconPath,
              width: 50.w,
              height: 50.w,
              color: isSelected ? Colors.white : const Color(0xFF23456B),
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.calendar_today,
                  size: 50.w,
                  color: isSelected ? Colors.white : const Color(0xFF23456B),
                );
              },
            ),
            SizedBox(height: 10.h),
            // 日期文字
            Text(
              day,
              style: TextStyle(
                fontSize: 18.sp,
                fontFamily: 'OtsutomeFont',
                color: isSelected ? Colors.white : const Color(0xFF23456B),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 5.h),
            // 時間文字
            Text(
              time,
              style: TextStyle(
                fontSize: 14.sp,
                fontFamily: 'OtsutomeFont',
                color: isSelected ? Colors.white : const Color(0xFF23456B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
