import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';

class AttendanceConfirmationPage extends StatefulWidget {
  const AttendanceConfirmationPage({super.key});

  @override
  State<AttendanceConfirmationPage> createState() =>
      _AttendanceConfirmationPageState();
}

class _AttendanceConfirmationPageState
    extends State<AttendanceConfirmationPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // TODO: 載入出席確認資料
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    setState(() {
      _isLoading = false;
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
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF23456B)),
                  )
                  : Column(
                    children: [
                      // 頁面標題
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.h),
                        child: Row(
                          children: [
                            BackIconButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  '出席確認',
                                  style: TextStyle(
                                    fontSize: 24.sp,
                                    fontFamily: 'OtsutomeFont',
                                    color: const Color(0xFF23456B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 55.w), // 平衡左側的返回按鈕
                          ],
                        ),
                      ),

                      Expanded(
                        child: Center(
                          child: Text(
                            '出席確認頁面開發中...',
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontFamily: 'OtsutomeFont',
                              color: const Color(0xFF23456B),
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
}
