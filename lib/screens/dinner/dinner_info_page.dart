import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tuckin/services/user_status_service.dart';
import 'package:provider/provider.dart';
import 'package:tuckin/services/dining_service.dart';

class DinnerInfoPage extends StatefulWidget {
  const DinnerInfoPage({super.key});

  @override
  State<DinnerInfoPage> createState() => _DinnerInfoPageState();
}

class _DinnerInfoPageState extends State<DinnerInfoPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final NavigationService _navigationService = NavigationService();
  bool _isLoading = true;
  bool _isPageMounted = false; // 追蹤頁面是否完全掛載
  String _userStatus = ''; // 用戶當前狀態
  bool _hasShownBookingDialog = false; // 追蹤是否已顯示過訂位對話框

  // 聚餐相關資訊
  final Map<String, dynamic> _dinnerInfo = {};
  DateTime? _dinnerTime;
  String? _restaurantName;
  String? _restaurantAddress;
  String? _restaurantImageUrl;
  String? _restaurantCategory;
  String? _restaurantMapUrl;

  // 新增變數
  String? _dinnerEventStatus;
  String? _reservationName;
  String? _reservationPhone;

  @override
  void initState() {
    super.initState();
    _loadUserAndDinnerInfo();
    // 使用延遲來確保頁面完全渲染後才設置為掛載狀態
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isPageMounted = true;
        });
        debugPrint('DinnerInfoPage 完全渲染');

        // 在頁面掛載完成後檢查餐廳確認狀態
        _checkPendingConfirmation();
      }
    });
  }

  // 檢查是否需要顯示幫忙訂位對話框
  void _checkPendingConfirmation() {
    // 延遲4秒後執行，確保UI已完全渲染
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted &&
          _dinnerEventStatus == 'pending_confirmation' &&
          !_hasShownBookingDialog) {
        _showBookingConfirmationDialog();
      }
    });
  }

  // 顯示幫忙訂位確認對話框
  void _showBookingConfirmationDialog() {
    // 設置已顯示對話框標記，僅表示系統自動顯示對話框時不要重複顯示
    if (!mounted) {
      debugPrint('_showBookingConfirmationDialog: Widget已卸載，取消顯示對話框');
      return;
    }

    setState(() {
      _hasShownBookingDialog = true;
    });

    showCustomConfirmationDialog(
      context: context,
      iconPath: 'assets/images/icon/reservation.png',
      title: '',
      content: '你願意幫忙確認餐廳營業時間，\n並協助訂位嗎？',
      cancelButtonText: '不要',
      confirmButtonText: '好哇',
      onCancel: () {
        // 用戶點擊"不要"時，重置標記，允許再次點擊卡片顯示對話框
        if (!mounted) {
          debugPrint(
            '_showBookingConfirmationDialog onCancel: Widget已卸載，不處理取消操作',
          );
          return;
        }

        setState(() {
          _hasShownBookingDialog = false;
        });
        Navigator.of(context).pop();
      },
      onConfirm: () async {
        try {
          if (!mounted) {
            debugPrint(
              '_showBookingConfirmationDialog onConfirm: Widget已卸載，不處理確認操作',
            );
            return;
          }

          // 1. 先從資料庫獲取當前用戶的最新聚餐事件資訊
          final currentUser = await _authService.getCurrentUser();
          if (currentUser == null) {
            throw Exception('用戶未登入');
          }

          if (!mounted) {
            debugPrint(
              '_showBookingConfirmationDialog onConfirm: 獲取用戶後Widget已卸載',
            );
            return;
          }

          // 從資料庫獲取最新的聚餐事件資訊
          final diningEvent = await _databaseService.getCurrentDiningEvent(
            currentUser.id,
          );

          if (!mounted) {
            debugPrint(
              '_showBookingConfirmationDialog onConfirm: 獲取聚餐事件後Widget已卸載',
            );
            return;
          }

          if (diningEvent == null) {
            throw Exception('未找到當前聚餐事件');
          }

          // 獲取UserStatusService以更新狀態
          final userStatusService = Provider.of<UserStatusService>(
            context,
            listen: false,
          );

          // 2. 更新本地狀態變數和Provider中的狀態
          final latestStatus = diningEvent['status'];
          debugPrint('從資料庫獲取到的最新聚餐狀態: $latestStatus，原狀態: $_dinnerEventStatus');

          // 更新Provider中的事件狀態
          userStatusService.updateStatus(eventStatus: latestStatus);
          debugPrint('已更新Provider中的事件狀態: $latestStatus');

          // 3. 根據最新聚餐事件狀態採取不同行動
          switch (latestStatus) {
            case 'pending_confirmation':
              final diningEventId = diningEvent['id'];
              if (diningEventId == null) {
                throw Exception('聚餐事件ID無效');
              }

              // 發送API請求，開始確認餐廳
              final diningService = DiningService();
              await diningService.startConfirming(diningEventId);

              // 更新Provider中的事件狀態為confirming和幫忙訂位狀態
              userStatusService.updateStatus(
                eventStatus: 'confirming',
                isHelpingWithReservation: true,
              );
              debugPrint('已更新Provider中的事件狀態為confirming並設置幫忙訂位狀態');

              // 關閉對話框
              if (!mounted) {
                debugPrint('pending_confirmation: API請求後Widget已卸載');
                return;
              }

              Navigator.of(context).pop();

              // 導航到餐廳預訂頁面
              if (!mounted) {
                debugPrint('pending_confirmation: 關閉對話框後Widget已卸載');
                return;
              }

              _navigationService.navigateToRestaurantReservation(context);
              break;

            case 'confirming':
              // 關閉對話框
              Navigator.of(context).pop();

              // 顯示SnackBar提示其他用戶正在協助訂位
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '其他用戶正在協助訂位中，請稍候...',
                      style: TextStyle(fontFamily: 'OtsutomeFont'),
                    ),
                  ),
                );
              }

              // 更新本地狀態
              setState(() {
                _dinnerEventStatus = latestStatus;
              });

              // 重新加載頁面數據
              if (mounted) {
                await _loadUserAndDinnerInfo();
              }
              break;

            case 'confirmed':
              // 關閉對話框
              Navigator.of(context).pop();

              // 顯示SnackBar提示已經完成訂位
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '餐廳已由其他用戶協助完成訂位',
                      style: TextStyle(fontFamily: 'OtsutomeFont'),
                    ),
                  ),
                );
              }

              // 更新本地狀態
              setState(() {
                _dinnerEventStatus = latestStatus;
              });

              // 重新加載頁面數據
              if (mounted) {
                await _loadUserAndDinnerInfo();
              }
              break;

            default:
              // 未知狀態，關閉對話框
              Navigator.of(context).pop();

              // 更新本地狀態
              setState(() {
                _dinnerEventStatus = latestStatus;
              });

              // 重新加載用戶數據
              if (mounted) {
                await _loadUserAndDinnerInfo();
              }
              break;
          }
        } catch (e) {
          // 關閉對話框
          if (mounted) {
            Navigator.of(context).pop();

            // 顯示錯誤提示
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '操作失敗: $e',
                  style: const TextStyle(fontFamily: 'OtsutomeFont'),
                ),
              ),
            );

            // 重置標記，允許用戶再次點擊
            setState(() {
              _hasShownBookingDialog = false;
            });
          }
        }
      },
    ).then((_) {
      // 對話框關閉時檢查頁面是否仍然掛載，然後重置標記
      // 這將處理用戶點擊空白處關閉對話框的情況
      if (mounted) {
        setState(() {
          _hasShownBookingDialog = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _isPageMounted = false;
    super.dispose();
  }

  Future<void> _loadUserAndDinnerInfo() async {
    try {
      if (!mounted) {
        debugPrint('_loadUserAndDinnerInfo: Widget已卸載，取消加載');
        return;
      }

      final currentUser = await _authService.getCurrentUser();

      if (!mounted) {
        debugPrint('_loadUserAndDinnerInfo: 獲取用戶後Widget已卸載，取消後續操作');
        return;
      }

      if (currentUser != null) {
        // 獲取用戶狀態
        final status = await _databaseService.getUserStatus(currentUser.id);

        if (!mounted) {
          debugPrint('_loadUserAndDinnerInfo: 獲取狀態後Widget已卸載，取消後續操作');
          return;
        }

        // 檢查用戶狀態是否是有效的狀態
        if (status != 'waiting_other_users' && status != 'waiting_attendance') {
          debugPrint('用戶狀態不是晚餐信息相關狀態: $status，導向到適當頁面');
          if (mounted) {
            _navigationService.navigateToUserStatusPage(context);
          }
          return;
        }

        // 從 UserStatusService 獲取聚餐時間，若無則使用預設值
        if (!mounted) {
          debugPrint('_loadUserAndDinnerInfo: 檢查狀態後Widget已卸載，取消後續操作');
          return;
        }

        // 獲取UserStatusService
        final userStatusService = Provider.of<UserStatusService>(
          context,
          listen: false,
        );

        // 獲取當前聚餐事件信息
        final diningEvent = await _databaseService.getCurrentDiningEvent(
          currentUser.id,
        );

        if (!mounted) {
          debugPrint('_loadUserAndDinnerInfo: 獲取聚餐事件後Widget已卸載，取消後續操作');
          return;
        }

        // 記錄用戶狀態到provider
        userStatusService.setUserStatus(status);
        debugPrint('已將用戶狀態 $status 記錄到Provider');

        // 從 Provider 中獲取聚餐時間或從 dining_events 中獲取
        DateTime? dinnerTime;
        String? restaurantName;
        String? restaurantAddress;
        String? restaurantImageUrl;
        String? restaurantCategory;
        String? restaurantMapUrl;
        String? dinnerEventStatus;
        String? reservationName;
        String? reservationPhone;
        int? attendeeCount; // 新增變數存儲用餐人數

        if (diningEvent != null) {
          // 從聚餐事件中獲取時間
          dinnerTime = DateTime.parse(diningEvent['date']);

          // 從聚餐事件中獲取狀態和預訂信息
          dinnerEventStatus = diningEvent['status'];
          reservationName = diningEvent['reservation_name'];
          reservationPhone = diningEvent['reservation_phone'];

          // 獲取用餐人數
          attendeeCount = diningEvent['attendee_count'];
          debugPrint('從聚餐事件中獲取到用餐人數: $attendeeCount');

          // 從聚餐事件中關聯的餐廳獲取信息
          if (diningEvent.containsKey('restaurant')) {
            final restaurant = diningEvent['restaurant'];
            restaurantName = restaurant['name'];
            restaurantAddress = restaurant['address'];
            restaurantImageUrl = restaurant['image_path'];
            restaurantCategory = restaurant['category'];

            // 構建地圖URL
            if (restaurantAddress != null && restaurantName != null) {
              restaurantMapUrl =
                  "https://maps.google.com/?q=${Uri.encodeComponent(restaurantName)}+${Uri.encodeComponent(restaurantAddress)}";
            }

            // 更新 UserStatusService 中的數據
            userStatusService.updateStatus(
              confirmedDinnerTime: dinnerTime,
              dinnerRestaurantId: diningEvent['restaurant_id'],
              cancelDeadline: DateTime.parse(
                diningEvent['status_change_time'] ??
                    dinnerTime.toIso8601String(),
              ),
              // 新增：保存配對組ID、聚餐事件ID和餐廳詳細信息
              matchingGroupId: diningEvent['matching_group_id'],
              diningEventId: diningEvent['id'],
              restaurantInfo: restaurant,
              eventStatus: dinnerEventStatus, // 保存聚餐事件狀態
              reservationName: reservationName, // 保存預訂人姓名
              reservationPhone: reservationPhone, // 保存預訂人電話
              attendees: attendeeCount, // 保存用餐人數
            );

            debugPrint('已更新UserStatusService中的餐廳信息: ${restaurant['name']}');
          }
        } else {
          // 若無聚餐事件，使用 UserStatusService 中的數據或預設值
          dinnerTime =
              userStatusService.confirmedDinnerTime ??
              DateTime.now().add(const Duration(days: 1));

          // 嘗試從 UserStatusService 獲取餐廳信息，如果有的話
          final cachedRestaurantInfo = userStatusService.restaurantInfo;
          dinnerEventStatus = userStatusService.eventStatus;
          reservationName = userStatusService.reservationName;
          reservationPhone = userStatusService.reservationPhone;

          if (cachedRestaurantInfo != null) {
            restaurantName = cachedRestaurantInfo['name'];
            restaurantAddress = cachedRestaurantInfo['address'];
            restaurantImageUrl = cachedRestaurantInfo['image_path'];
            restaurantCategory = cachedRestaurantInfo['category'];

            // 構建地圖URL
            if (restaurantAddress != null && restaurantName != null) {
              restaurantMapUrl =
                  "https://maps.google.com/?q=${Uri.encodeComponent(restaurantName)}+${Uri.encodeComponent(restaurantAddress)}";
            }

            debugPrint('從UserStatusService獲取到餐廳信息: $restaurantName');
          } else {
            // 使用預設餐廳數據（臨時）
            restaurantName = "查無餐廳";
            restaurantAddress = "查無地址";
            restaurantImageUrl = "assets/images/placeholder/restaurant.jpg";
            restaurantCategory = "未知種類";
            restaurantMapUrl = "https://maps.google.com/";
            debugPrint('無法獲取餐廳信息，使用預設值');
          }
        }

        debugPrint(
          '從 UserStatusService 獲取聚餐時間: ${userStatusService.formattedDinnerTime}',
        );
        debugPrint(
          '從 UserStatusService 獲取取消截止時間: ${userStatusService.formattedCancelDeadline}',
        );
        if (userStatusService.matchingGroupId != null) {
          debugPrint(
            '從 UserStatusService 獲取配對組ID: ${userStatusService.matchingGroupId}',
          );
        }
        if (userStatusService.diningEventId != null) {
          debugPrint(
            '從 UserStatusService 獲取聚餐事件ID: ${userStatusService.diningEventId}',
          );
        }
        if (userStatusService.restaurantInfo != null) {
          debugPrint('從 UserStatusService 獲取餐廳信息成功');
        }
        if (dinnerEventStatus != null) {
          debugPrint('聚餐事件狀態: $dinnerEventStatus');
        }

        // 更新狀態前再次檢查mounted
        if (!mounted) {
          debugPrint('_loadUserAndDinnerInfo: 準備更新狀態時Widget已卸載，取消更新');
          return;
        }

        // 更新狀態
        setState(() {
          _userStatus = status;
          _dinnerTime = dinnerTime;
          _restaurantName = restaurantName;
          _restaurantAddress = restaurantAddress;
          _restaurantImageUrl = restaurantImageUrl;
          _restaurantCategory = restaurantCategory;
          _restaurantMapUrl = restaurantMapUrl;
          _dinnerEventStatus = dinnerEventStatus;
          _reservationName = reservationName;
          _reservationPhone = reservationPhone;
          _isLoading = false;
        });

        debugPrint('餐廳資訊已更新: $_restaurantName, $_restaurantCategory');

        // 檢查用戶是否正在幫忙訂位，如果是且事件狀態為confirming，則導航到餐廳預訂頁面
        if (mounted &&
            userStatusService.isHelpingWithReservation &&
            dinnerEventStatus == 'confirming') {
          // 檢查幫忙訂位時間是否有效
          if (userStatusService.isHelpingReservationValid) {
            debugPrint('用戶正在幫忙訂位且事件狀態為confirming，時間戳有效，導航到餐廳預訂頁面');
            Future.microtask(
              () => _navigationService.navigateToRestaurantReservation(context),
            );
          } else {
            debugPrint('幫忙訂位時間已過期，不自動導航到餐廳預訂頁面');
            // 重置幫忙訂位狀態
            userStatusService.setHelpingWithReservation(false);
          }
        }
      } else {
        if (!mounted) {
          debugPrint('_loadUserAndDinnerInfo: 用戶為空時Widget已卸載，取消更新');
          return;
        }

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('獲取用戶和聚餐資訊時出錯: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 獲取狀態相關的提示文字
  String _getStatusText() {
    switch (_userStatus) {
      case 'waiting_other_users':
        return '正在等待其他用戶確認...';
      case 'waiting_attendance':
      case 'waiting_dinner':
        return '聚餐資訊';
      default:
        return '';
    }
  }

  // 打開地圖的共用函數
  Future<void> _openMap(String? mapUrl) async {
    try {
      if (mapUrl != null) {
        final Uri url = Uri.parse(mapUrl);
        debugPrint('嘗試打開地圖URL: $url');
        if (await launchUrl(url, mode: LaunchMode.externalApplication)) {
          debugPrint('地圖已成功打開');
        } else {
          debugPrint('無法打開URL: $url');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '無法開啟地圖',
                  style: TextStyle(fontFamily: 'OtsutomeFont'),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('打開地圖時出錯: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '打開地圖時出錯: $e',
              style: TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  // 在 _DinnerInfoPageState 類中添加此輔助方法，用於獲取星期的簡短表示
  String _getWeekdayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return '一';
      case DateTime.tuesday:
        return '二';
      case DateTime.wednesday:
        return '三';
      case DateTime.thursday:
        return '四';
      case DateTime.friday:
        return '五';
      case DateTime.saturday:
        return '六';
      case DateTime.sunday:
        return '日';
      default:
        return '';
    }
  }

  // 根據聚餐事件狀態顯示不同內容的提示卡片
  Widget _buildStatusPromptCard() {
    // 如果沒有狀態或不在範圍內，顯示默認卡片
    if (_dinnerEventStatus == null ||
        ![
          'pending_confirmation',
          'confirming',
          'confirmed',
        ].contains(_dinnerEventStatus)) {
      return _buildDefaultPromptCard();
    }

    final cardWidth = MediaQuery.of(context).size.width - 48.w;

    switch (_dinnerEventStatus) {
      case 'pending_confirmation':
        return Container(
          width: cardWidth,
          margin: EdgeInsets.symmetric(vertical: 8.h),
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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15.r),
              onTap: () {
                if (!_hasShownBookingDialog) {
                  _showBookingConfirmationDialog();
                }
              },
              child: Padding(
                padding: EdgeInsets.all(15.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 預訂圖標置中 (帶陰影)
                    SizedBox(
                      width: 30.w,
                      height: 30.h,
                      child: Stack(
                        children: [
                          // 底部陰影
                          Positioned(
                            left: 0.w,
                            top: 1.h,
                            child: Image.asset(
                              'assets/images/icon/reservation.png',
                              width: 28.w,
                              height: 28.h,
                              color: Colors.black.withOpacity(0.3),
                              colorBlendMode: BlendMode.srcIn,
                            ),
                          ),
                          // 主圖標
                          Image.asset(
                            'assets/images/icon/reservation.png',
                            width: 28.w,
                            height: 28.h,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8.h),
                    // 提示內容
                    Text(
                      '尚未確認餐廳，需要小幫手協助訂位！',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontFamily: 'OtsutomeFont',
                        color: const Color(0xFF666666),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

      case 'confirming':
        return Container(
          width: cardWidth,
          margin: EdgeInsets.symmetric(vertical: 8.h),
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
          child: Padding(
            padding: EdgeInsets.all(15.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 等待確認圖標置中 (帶陰影)
                SizedBox(
                  width: 30.w,
                  height: 30.h,
                  child: Stack(
                    children: [
                      // 底部陰影
                      Positioned(
                        left: 0.w,
                        top: 1.h,
                        child: Image.asset(
                          'assets/images/icon/checking.png',
                          width: 28.w,
                          height: 28.h,
                          color: Colors.black.withOpacity(0.3),
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                      // 主圖標
                      Image.asset(
                        'assets/images/icon/checking.png',
                        width: 28.w,
                        height: 28.h,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                // 提示內容
                Text(
                  '正在由其他用戶幫忙訂位中...',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontFamily: 'OtsutomeFont',
                    color: const Color(0xFF666666),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );

      case 'confirmed':
        String message = '';
        if (_reservationName != null &&
            _reservationName!.isNotEmpty &&
            _reservationPhone != null &&
            _reservationPhone!.isNotEmpty) {
          message = '$_reservationName幫忙訂位了！ 手機號碼：$_reservationPhone';
        } else {
          message = '餐廳已確認！請在聚餐時間到達';
        }

        return Container(
          width: cardWidth,
          margin: EdgeInsets.symmetric(vertical: 8.h),
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
          child: Padding(
            padding: EdgeInsets.all(15.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 已完成圖標置中 (帶陰影)
                SizedBox(
                  width: 30.w,
                  height: 30.h,
                  child: Stack(
                    children: [
                      // 底部陰影
                      Positioned(
                        left: 0.w,
                        top: 1.h,
                        child: Image.asset(
                          'assets/images/icon/done.png',
                          width: 28.w,
                          height: 28.h,
                          color: Colors.black.withOpacity(0.3),
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                      // 主圖標
                      Image.asset(
                        'assets/images/icon/done.png',
                        width: 28.w,
                        height: 28.h,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                // 提示內容
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontFamily: 'OtsutomeFont',
                    color: const Color(0xFF666666),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );

      default:
        return _buildDefaultPromptCard();
    }
  }

  // 預設提示卡片
  Widget _buildDefaultPromptCard() {
    final cardWidth = MediaQuery.of(context).size.width - 48.w;

    return Container(
      width: cardWidth,
      margin: EdgeInsets.symmetric(vertical: 8.h),
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
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.all(15.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 提示圖標置中 (帶陰影)
              SizedBox(
                width: 30.w,
                height: 30.h,
                child: Stack(
                  children: [
                    // 底部陰影
                    Positioned(
                      left: 0.w,
                      top: 1.h,
                      child: Image.asset(
                        'assets/images/icon/info.png',
                        width: 28.w,
                        height: 28.h,
                        color: Colors.black.withOpacity(0.3),
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                    // 主圖標
                    Image.asset(
                      'assets/images/icon/info.png',
                      width: 28.w,
                      height: 28.h,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              // 提示內容
              Text(
                '請在指定時間抵達餐廳。\n如有任何變動，系統將會發送通知。',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontFamily: 'OtsutomeFont',
                  color: const Color(0xFF666666),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 獲取 UserStatusService 以便在 UI 中使用
    final userStatusService = Provider.of<UserStatusService>(context);

    // 根據狀態決定顯示內容
    Widget content;

    if (_isLoading) {
      return WillPopScope(
        onWillPop: () async {
          return false; // 禁用返回按鈕
        },
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background/bg2.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF23456B)),
            ),
          ),
        ),
      );
    }

    // 從 UserStatusService 獲取聚餐時間，如果已有值則使用，否則使用頁面加載時獲取的值
    final dinnerTime = userStatusService.confirmedDinnerTime ?? _dinnerTime;

    // 格式化聚餐時間
    final dinnerTimeFormatted =
        dinnerTime != null
            ? '${dinnerTime.month}月${dinnerTime.day}日 ${dinnerTime.hour}:${dinnerTime.minute.toString().padLeft(2, '0')}'
            : '時間待定';

    // 取消截止時間
    final cancelDeadline = userStatusService.cancelDeadline;
    final canCancelReservation = userStatusService.canCancelReservation;

    // 構建等待其他用戶確認的UI
    if (_userStatus == 'waiting_other_users') {
      content = Column(
        children: [
          SizedBox(height: 80.h),

          // 提示文字
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

          // 圖示 - 使用頭像和圓形遮罩
          Center(
            child: SizedBox(
              width: 150.w,
              height: 150.w, // 使用相同的寬度單位確保是正方形
              child: Stack(
                clipBehavior: Clip.none, // 允許陰影超出容器範圍
                children: [
                  // 主圖像（使用 BoxDecoration 確保圓形）
                  Container(
                    width: 150.w,
                    height: 150.w, // 使用相同的寬度單位確保是正方形
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color.fromARGB(255, 184, 80, 51),
                        width: 3.w,
                      ),
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: AssetImage(
                          'assets/images/avatar/profile/female_7.png',
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

          // 聚餐時間顯示卡片 - 使用與 dinner_reservation_page 相同的風格
          Center(
            child: Container(
              // 移除固定寬度，使用內容自適應寬度
              // width: MediaQuery.of(context).size.width - 48.w,
              margin: EdgeInsets.symmetric(horizontal: 24.w),
              padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 15.w),
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
                // 使用 IntrinsicWidth 讓容器寬度適應內容
                child: Row(
                  mainAxisSize: MainAxisSize.min, // 設置為最小寬度
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 左側 - 時間圖標及陰影
                    SizedBox(
                      width: 75.w,
                      height: 75.h,
                      child: Stack(
                        clipBehavior: Clip.none, // 允許陰影超出容器範圍
                        children: [
                          // 底部陰影
                          Positioned(
                            left: 0,
                            top: 3.h,
                            child: Image.asset(
                              dinnerTime != null &&
                                      dinnerTime.weekday == DateTime.monday
                                  ? 'assets/images/icon/mon.png'
                                  : 'assets/images/icon/thu.png',
                              width: 75.w,
                              height: 75.h,
                              color: Colors.black.withOpacity(0.4),
                              colorBlendMode: BlendMode.srcIn,
                            ),
                          ),
                          // 主圖標
                          Image.asset(
                            dinnerTime != null &&
                                    dinnerTime.weekday == DateTime.monday
                                ? 'assets/images/icon/mon.png'
                                : 'assets/images/icon/thu.png',
                            width: 75.w,
                            height: 75.h,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 10.w),

                    // 右側 - 增加垂直排列以容納標題和時間
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 聚餐時間標題
                        Text(
                          "聚餐時間：",
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontFamily: 'OtsutomeFont',
                            color: const Color(0xFF666666),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        // 單行顯示日期和時間信息
                        Text(
                          dinnerTime != null
                              ? '${dinnerTime.month}月${dinnerTime.day}日（${_getWeekdayShort(dinnerTime.weekday)}）${dinnerTime.hour}:${dinnerTime.minute.toString().padLeft(2, '0')}'
                              : '-- 月 -- 日（-）--:--',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontFamily: 'OtsutomeFont',
                            color: const Color(0xFF23456B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 10.w),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    // 構建等待出席/聚餐資訊的UI
    else {
      // 定義卡片寬度，確保一致性
      final cardWidth = MediaQuery.of(context).size.width - 48.w;

      content = Column(
        children: [
          SizedBox(height: 10.h),

          // 聚餐資訊卡片（結合餐廳資訊和時間）
          Container(
            width: cardWidth,
            margin: EdgeInsets.symmetric(vertical: 8.h),
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
            child: Column(
              children: [
                // 餐廳資訊部分 - 使用與預訂頁面相同的樣式
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15.r),
                    topRight: Radius.circular(15.r),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      debugPrint('點擊了圖片，嘗試打開地圖: $_restaurantMapUrl');
                      if (_restaurantMapUrl != null) {
                        final Uri url = Uri.parse(_restaurantMapUrl!);
                        launchUrl(url, mode: LaunchMode.externalApplication)
                            .then((success) {
                              if (!success && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '無法開啟地圖',
                                      style: TextStyle(
                                        fontFamily: 'OtsutomeFont',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            })
                            .catchError((error) {
                              debugPrint('打開地圖出錯: $error');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '$error',
                                      style: const TextStyle(
                                        fontFamily: 'OtsutomeFont',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            });
                      }
                    },
                    child:
                        _restaurantImageUrl != null
                            ? Image.network(
                              _restaurantImageUrl!,
                              width: double.infinity,
                              height: 150.h,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: double.infinity,
                                  height: 150.h,
                                  color: Colors.grey[300],
                                  child: Icon(
                                    Icons.restaurant,
                                    color: Colors.grey[600],
                                    size: 50.sp,
                                  ),
                                );
                              },
                            )
                            : Container(
                              width: double.infinity,
                              height: 150.h,
                              color: Colors.grey[300],
                              child: Icon(
                                Icons.restaurant,
                                color: Colors.grey[600],
                                size: 50.sp,
                              ),
                            ),
                  ),
                ),

                // 餐廳詳細資訊
                Padding(
                  padding: EdgeInsets.all(15.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 餐廳名稱
                      Text(
                        _restaurantName ?? '未指定餐廳',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontFamily: 'OtsutomeFont',
                          color: const Color(0xFF23456B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 5.h),
                      // 餐廳類別
                      Text(
                        _restaurantCategory ?? '未分類',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontFamily: 'OtsutomeFont',
                          color: const Color(0xFF666666),
                        ),
                      ),

                      SizedBox(height: 10.h),
                      // 餐廳地址 - 可點擊
                      GestureDetector(
                        onTap: () {
                          debugPrint('點擊了地址，嘗試打開地圖: $_restaurantMapUrl');
                          if (_restaurantMapUrl != null) {
                            final Uri url = Uri.parse(_restaurantMapUrl!);
                            launchUrl(url, mode: LaunchMode.externalApplication)
                                .then((success) {
                                  if (!success && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '無法開啟地圖',
                                          style: TextStyle(
                                            fontFamily: 'OtsutomeFont',
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                })
                                .catchError((error) {
                                  debugPrint('打開地圖出錯: $error');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '$error',
                                          style: const TextStyle(
                                            fontFamily: 'OtsutomeFont',
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                });
                          }
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _restaurantAddress ?? '地址未提供',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontFamily: 'OtsutomeFont',
                                  color: const Color(0xFF23456B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 分隔線
                Container(
                  height: 1,
                  color: Colors.grey[300],
                  margin: EdgeInsets.symmetric(horizontal: 12.w),
                ),

                // 聚餐時間部分
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 15.h,
                    vertical: 15.h,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 左側時間信息
                          SizedBox(
                            width: cardWidth * 0.4,
                            child: Row(
                              children: [
                                // 時間圖標 - 使用指定的圖標並添加陰影效果
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: 0.w,
                                    bottom: 5.h,
                                  ),
                                  child: SizedBox(
                                    width: 35.w,
                                    height: 35.h,
                                    child: Stack(
                                      clipBehavior: Clip.none, // 允許陰影超出容器範圍
                                      children: [
                                        // 底部陰影
                                        Positioned(
                                          left: 0,
                                          top: 2.h,
                                          child: Image.asset(
                                            'assets/images/icon/clock.png',
                                            width: 35.w,
                                            height: 35.h,
                                            color: Colors.black.withOpacity(
                                              0.4,
                                            ),
                                            colorBlendMode: BlendMode.srcIn,
                                          ),
                                        ),
                                        // 主圖標
                                        Image.asset(
                                          'assets/images/icon/clock.png',
                                          width: 35.w,
                                          height: 35.h,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                SizedBox(width: 10.w),

                                // 時間信息文字
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '聚餐時間',
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontFamily: 'OtsutomeFont',
                                          color: const Color(0xFF23456B),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        dinnerTimeFormatted,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontFamily: 'OtsutomeFont',
                                          color: const Color(0xFF666666),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 垂直分隔線
                          Container(
                            height: 45.h,
                            width: 1.w,
                            color: Colors.grey[300],
                          ),

                          // 右側導航部分
                          SizedBox(
                            width: cardWidth * 0.4,
                            child: InkWell(
                              onTap: () {
                                debugPrint(
                                  '點擊了導航按鈕，嘗試打開地圖: $_restaurantMapUrl',
                                );
                                if (_restaurantMapUrl != null) {
                                  final Uri url = Uri.parse(_restaurantMapUrl!);
                                  launchUrl(
                                        url,
                                        mode: LaunchMode.externalApplication,
                                      )
                                      .then((success) {
                                        if (!success && mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '無法開啟地圖',
                                                style: TextStyle(
                                                  fontFamily: 'OtsutomeFont',
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      })
                                      .catchError((error) {
                                        debugPrint('打開地圖出錯: $error');
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '打開地圖出錯: $error',
                                                style: TextStyle(
                                                  fontFamily: 'OtsutomeFont',
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      });
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // 導航圖標
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 5.h),
                                    child: SizedBox(
                                      width: 35.w,
                                      height: 35.h,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          // 底部陰影
                                          Positioned(
                                            left: 0,
                                            top: 2.h,
                                            child: Image.asset(
                                              'assets/images/icon/navigation.png',
                                              width: 35.w,
                                              height: 35.h,
                                              color: Colors.black.withOpacity(
                                                0.4,
                                              ),
                                              colorBlendMode: BlendMode.srcIn,
                                            ),
                                          ),
                                          // 主圖標
                                          Image.asset(
                                            'assets/images/icon/navigation.png',
                                            width: 35.w,
                                            height: 35.h,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '導航',
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontFamily: 'OtsutomeFont',
                                          color: const Color(0xFF23456B),
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        'Google Map',
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontFamily: 'OtsutomeFont',
                                          color: const Color(0xFF666666),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          // 替換舊的提示卡片為根據狀態顯示的卡片
          _buildStatusPromptCard(),
        ],
      );
    }

    return WillPopScope(
      onWillPop: () async {
        return false; // 禁用返回按鈕
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background/bg2.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // 右下角背景圖片
                Positioned(
                  right: -7.w, // 負值使圖片右側超出螢幕
                  bottom: -45.h, // 負值使圖片底部超出螢幕
                  child: Opacity(
                    opacity: 0.65, // 降低透明度，使圖片更加融入背景
                    child: ColorFiltered(
                      // 降低彩度的矩陣
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.6, 0.1, 0.1, 0, 0, // R影響
                        0.1, 0.6, 0.1, 0, 0, // G影響
                        0.1, 0.1, 0.6, 0, 0, // B影響
                        0, 0, 0, 1, 0, // A影響
                      ]),
                      child: Image.asset(
                        'assets/images/illustrate/p3.png',
                        width: 220.w, // 增大尺寸
                        height: 220.h, // 增大尺寸
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // 主要內容
                Column(
                  children: [
                    // 頂部導航欄
                    HeaderBar(title: _getStatusText()),

                    // 主要內容
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: content,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
