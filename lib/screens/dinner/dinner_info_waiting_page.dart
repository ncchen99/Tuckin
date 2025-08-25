import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/user_status_service.dart';
import 'package:tuckin/utils/index.dart';

class DinnerInfoWaitingPage extends StatelessWidget {
  const DinnerInfoWaitingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background/bg2.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 標題列放在滾動區域內的第一個元素
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        HeaderBar(title: '聚餐資訊'),
                        SizedBox(height: 80.h),
                        Center(
                          child: Text(
                            '等待大家選擇餐廳歐',
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontFamily: 'OtsutomeFont',
                              color: const Color(0xFF23456B),
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 35.h),
                        Center(
                          child: SizedBox(
                            width: 150.w,
                            height: 150.w,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 150.w,
                                  height: 150.w,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color.fromARGB(
                                        255,
                                        184,
                                        80,
                                        51,
                                      ),
                                      width: 3.w,
                                    ),
                                    shape: BoxShape.circle,
                                    image: const DecorationImage(
                                      image: AssetImage(
                                        'assets/images/avatar/profile/female_7.webp',
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 40.h),
                        Center(
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 24.w),
                            padding: EdgeInsets.symmetric(
                              vertical: 20.h,
                              horizontal: 15.w,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(15.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 5,
                                  offset: Offset(0, 2.h),
                                ),
                              ],
                            ),
                            child: IntrinsicWidth(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Consumer<UserStatusService>(
                                    builder: (
                                      context,
                                      userStatusService,
                                      child,
                                    ) {
                                      String iconPath =
                                          'assets/images/icon/thu.webp';
                                      if (userStatusService
                                              .confirmedDinnerTime !=
                                          null) {
                                        iconPath =
                                            userStatusService
                                                        .confirmedDinnerTime!
                                                        .weekday ==
                                                    DateTime.monday
                                                ? 'assets/images/icon/mon.webp'
                                                : 'assets/images/icon/thu.webp';
                                      }
                                      return SizedBox(
                                        width: 75.w,
                                        height: 75.h,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Positioned(
                                              left: 0,
                                              top: 3.h,
                                              child: Image.asset(
                                                iconPath,
                                                width: 75.w,
                                                height: 75.h,
                                                color: Colors.black.withOpacity(
                                                  0.4,
                                                ),
                                                colorBlendMode: BlendMode.srcIn,
                                              ),
                                            ),
                                            Image.asset(
                                              iconPath,
                                              width: 75.w,
                                              height: 75.h,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  SizedBox(width: 10.w),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '聚餐時間：',
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontFamily: 'OtsutomeFont',
                                          color: const Color(0xFF666666),
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Consumer<UserStatusService>(
                                        builder: (
                                          context,
                                          userStatusService,
                                          child,
                                        ) {
                                          return Text(
                                            userStatusService
                                                .fullDinnerTimeDescription,
                                            style: TextStyle(
                                              fontSize: 18.sp,
                                              fontFamily: 'OtsutomeFont',
                                              color: const Color(0xFF23456B),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: 10.w),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 30.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
