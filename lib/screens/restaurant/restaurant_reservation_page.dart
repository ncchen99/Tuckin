import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:tuckin/services/user_status_service.dart';
import 'package:tuckin/services/dining_service.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:tuckin/services/time_service.dart';

class RestaurantReservationPage extends StatefulWidget {
  const RestaurantReservationPage({super.key});

  @override
  State<RestaurantReservationPage> createState() =>
      _RestaurantReservationPageState();
}

class _RestaurantReservationPageState extends State<RestaurantReservationPage>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final NavigationService _navigationService = NavigationService();
  bool _isLoading = true;
  bool _isPageMounted = false;
  final bool _isConfirming = false;
  bool _isProcessingAction = false; // 新增：處理按鈕點擊時的loading狀態

  // 新增計時器相關變數
  Timer? _redirectTimer;
  static const int _redirectTimeInSeconds = 596; // 9分56秒 = 596秒
  static const String _entryTimeKey = "restaurant_reservation_entry_time";

  // 餐廳相關資訊
  final Map<String, dynamic> _restaurantInfo = {};
  String? _restaurantName;
  String? _restaurantAddress;
  String? _restaurantImageUrl;
  String? _restaurantCategory;
  String? _restaurantMapUrl;
  String? _restaurantPhone;
  String? _restaurantWebsite;
  String? _restaurantReservationNote;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 添加觀察者
    _loadRestaurantInfo();
    _setupRedirectTimer(); // 設置重定向計時器

    // 在Provider中設置用戶正在幫忙訂位的狀態
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final userStatusService = Provider.of<UserStatusService>(
          context,
          listen: false,
        );
        userStatusService.setHelpingWithReservation(true);
        debugPrint('已設置用戶正在幫忙訂位狀態');

        setState(() {
          _isPageMounted = true;
        });
        debugPrint('RestaurantReservationPage 完全渲染');
      }
    });
  }

  @override
  void dispose() {
    debugPrint('RestaurantReservationPage dispose開始');
    WidgetsBinding.instance.removeObserver(this); // 移除觀察者

    // 取消計時器
    _cancelRedirectTimer();

    // 清除SharedPreferences中的入口時間
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.remove(_entryTimeKey);
          debugPrint('dispose時已清除入口時間記錄');
        })
        .catchError((e) {
          debugPrint('dispose時清除入口時間記錄出錯: $e');
        });

    _isPageMounted = false;
    debugPrint('RestaurantReservationPage dispose完成');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 當應用程式恢復前景狀態時檢查計時器
    if (state == AppLifecycleState.resumed) {
      _checkRedirectTimeout();
    }
  }

  // 設置重定向計時器並存儲進入時間
  Future<void> _setupRedirectTimer() async {
    try {
      // 獲取 SharedPreferences 實例
      final prefs = await SharedPreferences.getInstance();

      // 保存進入頁面的時間戳（校正後）
      final currentTime = TimeService().epochMilliseconds();
      await prefs.setInt(_entryTimeKey, currentTime);
      debugPrint('已保存頁面進入時間戳: $currentTime');

      // 設置計時器，10分鐘後自動跳轉
      _cancelRedirectTimer(); // 先取消舊的計時器（如果有）
      _redirectTimer = Timer(Duration(seconds: _redirectTimeInSeconds), () {
        _redirectToDinnerInfo();
      });
      debugPrint('已設置 $_redirectTimeInSeconds 秒後自動跳轉');
    } catch (e) {
      debugPrint('設置重定向計時器時出錯: $e');
    }
  }

  // 檢查是否已超過重定向時間限制
  Future<void> _checkRedirectTimeout() async {
    try {
      if (!mounted) {
        debugPrint('_checkRedirectTimeout: Widget已卸載，取消檢查');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final entryTime = prefs.getInt(_entryTimeKey);

      if (entryTime != null) {
        final currentTime = TimeService().epochMilliseconds();
        final timeElapsed = currentTime - entryTime;
        final timeElapsedInSeconds = timeElapsed ~/ 1000;

        debugPrint('已經過時間：$timeElapsedInSeconds 秒');

        if (!mounted) {
          debugPrint('_checkRedirectTimeout: 檢查過程中Widget被卸載，取消後續操作');
          return;
        }

        if (timeElapsedInSeconds >= _redirectTimeInSeconds) {
          debugPrint('時間已超過 $_redirectTimeInSeconds 秒，即將跳轉');
          _redirectToDinnerInfo();
        } else {
          // 重新設置剩餘時間的計時器
          _cancelRedirectTimer();

          if (!mounted) {
            debugPrint('_checkRedirectTimeout: Widget已卸載，不重新設置計時器');
            return;
          }

          final remainingSeconds =
              _redirectTimeInSeconds - timeElapsedInSeconds;
          debugPrint('重新設置計時器，剩餘 $remainingSeconds 秒');

          _redirectTimer = Timer(Duration(seconds: remainingSeconds), () {
            if (mounted) {
              _redirectToDinnerInfo();
            } else {
              debugPrint('計時器觸發時Widget已卸載，不執行跳轉');
            }
          });
        }
      }
    } catch (e) {
      debugPrint('檢查重定向超時時出錯: $e');
    }
  }

  // 取消重定向計時器
  void _cancelRedirectTimer() {
    if (_redirectTimer != null && _redirectTimer!.isActive) {
      _redirectTimer!.cancel();
      _redirectTimer = null;
      debugPrint('已取消重定向計時器');
    }
  }

  // 重定向到晚餐信息頁面
  void _redirectToDinnerInfo() {
    if (!mounted) {
      debugPrint('_redirectToDinnerInfo: Widget已卸載，取消導航');
      return;
    }

    try {
      debugPrint('準備跳轉到晚餐信息頁面');

      // 跳轉前清除計時器和入口時間
      _cancelRedirectTimer();

      // 嘗試清除SharedPreferences中的入口時間
      SharedPreferences.getInstance()
          .then((prefs) {
            prefs.remove(_entryTimeKey);
            debugPrint('已清除入口時間記錄');
          })
          .catchError((e) {
            debugPrint('清除入口時間記錄時出錯: $e');
          });

      // 重置用戶幫忙訂位的狀態
      if (mounted) {
        final userStatusService = Provider.of<UserStatusService>(
          context,
          listen: false,
        );
        userStatusService.setHelpingWithReservation(false);
        debugPrint('已重置用戶幫忙訂位狀態');
      }

      // 使用Future.microtask確保在當前渲染幀完成後再執行導航
      Future.microtask(() {
        if (mounted) {
          _navigationService.navigateToDinnerInfo(context);
        } else {
          debugPrint('導航前Widget已卸載，取消導航');
        }
      });
    } catch (e) {
      debugPrint('重定向到晚餐信息頁面時出錯: $e');
    }
  }

  Future<void> _loadRestaurantInfo() async {
    try {
      if (!mounted) {
        debugPrint('_loadRestaurantInfo: Widget已卸載，取消加載');
        return;
      }

      // 從Provider獲取UserStatusService
      final userStatusService = Provider.of<UserStatusService>(
        context,
        listen: false,
      );

      // 從UserStatusService獲取餐廳信息
      final restaurantInfo = userStatusService.restaurantInfo;

      if (restaurantInfo != null) {
        debugPrint('從Provider獲取到餐廳信息');

        // 讀取餐廳基本信息
        final name = restaurantInfo['name'];
        final address = restaurantInfo['address'];
        final imageUrl = restaurantInfo['image_path'];
        final category = restaurantInfo['category'];
        final phone = restaurantInfo['phone'] ?? '未提供';
        final website =
            restaurantInfo['website'] ?? 'https://example.com/restaurant';
        final reservationNote = restaurantInfo['reservation_note'] ?? '請提前預訂。';

        // 構建地圖URL
        String? mapUrl;
        if (address != null && name != null) {
          mapUrl =
              "https://maps.google.com/?q=${Uri.encodeComponent(name)}+${Uri.encodeComponent(address)}";
        }

        if (!mounted) {
          debugPrint('_loadRestaurantInfo: 讀取完畢但Widget已卸載，取消更新UI');
          return;
        }

        setState(() {
          _restaurantName = name ?? "未指定餐廳名稱";
          _restaurantAddress = address ?? "未提供地址";
          _restaurantImageUrl = imageUrl;
          _restaurantCategory = category ?? "未分類";
          _restaurantMapUrl = mapUrl;
          _restaurantPhone = phone;
          _restaurantWebsite = website;
          _restaurantReservationNote = reservationNote;
          _isLoading = false;
        });

        debugPrint('餐廳資訊已更新: $_restaurantName, $_restaurantCategory');
      } else {
        // 若Provider中沒有餐廳信息，則從資料庫獲取
        debugPrint('Provider中無餐廳信息，嘗試從資料庫獲取');

        final currentUser = await _authService.getCurrentUser();
        if (currentUser != null) {
          // 獲取當前用戶的聚餐事件
          final diningEvent = await _databaseService.getCurrentDiningEvent(
            currentUser.id,
          );

          if (!mounted) {
            debugPrint('_loadRestaurantInfo: 獲取用戶聚餐事件後Widget已卸載');
            return;
          }

          if (diningEvent != null && diningEvent.containsKey('restaurant')) {
            // 從聚餐事件獲取餐廳信息
            final restaurant = diningEvent['restaurant'];

            // 更新UserStatusService
            userStatusService.updateStatus(
              restaurantInfo: restaurant,
              dinnerRestaurantId: diningEvent['restaurant_id'],
            );

            if (!mounted) {
              debugPrint('_loadRestaurantInfo: 更新Provider後Widget已卸載');
              return;
            }

            // 更新UI
            setState(() {
              _restaurantName = restaurant['name'] ?? "未指定餐廳名稱";
              _restaurantAddress = restaurant['address'] ?? "未提供地址";
              _restaurantImageUrl = restaurant['image_path'];
              _restaurantCategory = restaurant['category'] ?? "未分類";
              _restaurantMapUrl =
                  restaurant['address'] != null && restaurant['name'] != null
                      ? "https://maps.google.com/?q=${Uri.encodeComponent(restaurant['name'])}+${Uri.encodeComponent(restaurant['address'])}"
                      : null;
              _restaurantPhone = restaurant['phone'] ?? "未提供";
              _restaurantWebsite = restaurant['website'] ?? "未提供";
              _restaurantReservationNote =
                  restaurant['reservation_note'] ?? "請提前預訂。";
              _isLoading = false;
            });

            debugPrint('餐廳資訊已從資料庫更新: $_restaurantName');
          } else {
            // 兜底使用測試數據
            debugPrint('無法從資料庫獲取餐廳信息，使用測試數據');

            if (!mounted) return;

            setState(() {
              _restaurantName = "餐廳資訊載入中...";
              _restaurantAddress = "地址載入中...";
              _restaurantImageUrl =
                  "https://images.unsplash.com/photo-1552566626-52f8b828add9?q=80&w=2070";
              _restaurantCategory = "載入中...";
              _restaurantMapUrl = "https://maps.google.com/";
              _restaurantPhone = "未提供";
              _restaurantWebsite = "https://example.com/restaurant";
              _restaurantReservationNote = "載入中...";
              _isLoading = false;
            });
          }
        } else {
          // 用戶未登入
          debugPrint('用戶未登入，無法獲取餐廳資訊');

          if (!mounted) return;

          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('獲取餐廳資訊時出錯: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      debugPrint('嘗試撥打電話: $phoneNumber');
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw '無法撥打電話：$phoneNumber';
      }
    } catch (e) {
      debugPrint('撥打電話時出錯: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$e',
              style: const TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openWebsite(String websiteUrl) async {
    final Uri url = Uri.parse(websiteUrl);
    try {
      debugPrint('嘗試開啟網站: $websiteUrl');
      launchUrl(url, mode: LaunchMode.externalApplication)
          .then((success) {
            if (!success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '無法開啟網站',
                    style: TextStyle(fontFamily: 'OtsutomeFont'),
                  ),
                ),
              );
            }
          })
          .catchError((error) {
            debugPrint('開啟網站出錯: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$error',
                    style: const TextStyle(fontFamily: 'OtsutomeFont'),
                  ),
                ),
              );
            }
          });
    } catch (e) {
      debugPrint('開啟網站時出錯: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '開啟網站時出錯: $e',
              style: const TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openMap(String? mapUrl) async {
    try {
      if (mapUrl != null) {
        final Uri url = Uri.parse(mapUrl);
        debugPrint('嘗試打開地圖URL: $url');
        launchUrl(url, mode: LaunchMode.externalApplication)
            .then((success) {
              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '無法開啟地圖',
                      style: TextStyle(fontFamily: 'OtsutomeFont'),
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
                      '打開地圖出錯: $error',
                      style: const TextStyle(fontFamily: 'OtsutomeFont'),
                    ),
                  ),
                );
              }
            });
      }
    } catch (e) {
      debugPrint('打開地圖時出錯: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '打開地圖時出錯: $e',
              style: const TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  // 添加檢查聚餐事件狀態的方法
  Future<bool> _checkDiningEventStatus() async {
    try {
      // 1. 獲取當前用戶
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('用戶未登入');
      }

      // 2. 從資料庫獲取最新的聚餐事件資訊
      final diningEvent = await _databaseService.getCurrentDiningEvent(
        currentUser.id,
      );

      if (diningEvent == null) {
        throw Exception('未找到當前聚餐事件');
      }

      // 3. 獲取最新狀態
      final latestStatus = diningEvent['status'];
      debugPrint('從資料庫獲取到的最新聚餐狀態: $latestStatus');

      // 4. 檢查狀態是否為confirming
      if (latestStatus != 'confirming') {
        // 如果狀態不是confirming，顯示提示訊息
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '訂位操作已逾時，正在返回聚餐資訊頁面',
                style: const TextStyle(fontFamily: 'OtsutomeFont'),
              ),
            ),
          );

          // 導航回晚餐信息頁面
          _navigationService.navigateToDinnerInfo(context);
        }
        return false;
      }

      // 5. 如果狀態是confirming，更新Provider中的狀態
      if (mounted) {
        final userStatusService = Provider.of<UserStatusService>(
          context,
          listen: false,
        );
        userStatusService.updateStatus(eventStatus: latestStatus);
      }

      return true;
    } catch (e) {
      debugPrint('檢查聚餐事件狀態時出錯: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '檢查聚餐事件狀態失敗: $e',
              style: const TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _handleReservationConfirm() async {
    try {
      // 設置按鈕處理中狀態
      setState(() {
        _isProcessingAction = true;
      });

      // 先檢查聚餐事件狀態
      bool isStatusValid = await _checkDiningEventStatus();
      if (!isStatusValid) {
        // 重置狀態
        setState(() {
          _isProcessingAction = false;
        });
        return; // 如果狀態不是confirming，直接返回
      }

      // 獲取UserStatusService
      final userStatusService = Provider.of<UserStatusService>(
        context,
        listen: false,
      );

      // 獲取聚餐事件ID
      final diningEventId = userStatusService.diningEventId;
      if (diningEventId == null) {
        throw Exception('無法獲取聚餐事件ID');
      }

      // 創建DiningService實例
      final diningService = DiningService();

      // 重置按鈕狀態，因為對話框有自己的狀態管理
      setState(() {
        _isProcessingAction = false;
      });

      // 顯示輸入預訂資訊的對話框
      await _showReservationInfoDialog(diningEventId, diningService);
    } catch (e) {
      debugPrint('確認預訂時出錯: $e');

      // 重置按鈕狀態
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '確認預訂失敗: $e',
              style: const TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleCannotReserve() async {
    try {
      // 設置按鈕處理中狀態
      setState(() {
        _isProcessingAction = true;
      });

      // 先檢查聚餐事件狀態
      bool isStatusValid = await _checkDiningEventStatus();
      if (!isStatusValid) {
        // 重置狀態
        setState(() {
          _isProcessingAction = false;
        });
        return; // 如果狀態不是confirming，直接返回
      }

      // 獲取UserStatusService
      final userStatusService = Provider.of<UserStatusService>(
        context,
        listen: false,
      );

      // 獲取聚餐事件ID
      final diningEventId = userStatusService.diningEventId;
      if (diningEventId == null) {
        throw Exception('無法獲取聚餐事件ID');
      }

      // 使用自定義確認對話框
      bool? confirmChange = await showCustomConfirmationDialog(
        context: context,
        iconPath: 'assets/images/icon/failed.webp',
        content: '確定要更換另一家餐廳嗎？系統將從候選餐廳中選擇下一間！',
        cancelButtonText: '取消',
        confirmButtonText: '確定',
        barrierDismissible: true, // 正常狀態可點擊空白處關閉
        onCancel: () {
          // 重置按鈕狀態
          setState(() {
            _isProcessingAction = false;
          });
          Navigator.of(context).pop(false);
        },
        onConfirm: () async {
          try {
            // 調用API更換餐廳
            final diningService = DiningService();
            final response = await diningService.changeRestaurant(
              diningEventId,
            );

            // 檢查回應中是否有新餐廳資訊
            if (response.containsKey('restaurant') &&
                response['restaurant'] != null) {
              final restaurant = response['restaurant'];

              // 更新UserStatusService中的餐廳資訊
              userStatusService.updateStatus(
                restaurantInfo: restaurant,
                dinnerRestaurantId: restaurant['id'],
              );

              // 更新幫忙訂位開始時間
              userStatusService.updateHelpingReservationStartTime();

              debugPrint('成功更換餐廳，新餐廳：${restaurant['name']}');

              // 重新加載頁面數據
              if (mounted) await _loadRestaurantInfo();

              // 重置計時器 - 重新設置596秒倒計時
              if (mounted) await _setupRedirectTimer();

              // 顯示成功訊息
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '已成功更換為：${restaurant['name']}',
                      style: const TextStyle(fontFamily: 'OtsutomeFont'),
                    ),
                  ),
                );
              }

              // 重置按鈕狀態
              setState(() {
                _isProcessingAction = false;
              });

              // 返回true表示更換成功
              Navigator.of(context).pop(true);
            } else {
              throw Exception('無法獲取新餐廳資訊');
            }
          } catch (e) {
            _handleApiError(context, e);
          }
        },
      );

      // 檢查用戶是否點擊空白處關閉對話框
      if (confirmChange == null) {
        // 用戶點擊空白處關閉對話框，重置loading狀態
        setState(() {
          _isProcessingAction = false;
        });
      }
    } catch (e) {
      debugPrint('準備更換餐廳時出錯: $e');

      // 重置按鈕狀態
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '更換餐廳失敗: $e',
              style: const TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  // 添加錯誤處理輔助函數
  void _handleApiError(BuildContext dialogContext, dynamic e) {
    debugPrint('API請求發生錯誤: $e');

    if (!mounted) {
      debugPrint('頁面已卸載，取消錯誤處理');
      return;
    }

    // 確保對話框關閉（如果存在）
    if (Navigator.of(dialogContext).canPop()) {
      Navigator.of(dialogContext).pop();
    }

    // 顯示錯誤消息
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '操作失敗: $e',
          style: const TextStyle(fontFamily: 'OtsutomeFont'),
        ),
      ),
    );
  }

  // 顯示輸入預訂資訊的對話框
  Future<void> _showReservationInfoDialog(
    String eventId,
    DiningService diningService,
  ) async {
    if (!mounted) {
      debugPrint('_showReservationInfoDialog: Widget已卸載，取消操作');
      return;
    }

    // 創建TextEditingController
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    // 使用外部變量來控制處理狀態
    bool isProcessing = false;

    // 控制輸入框提示狀態
    bool nameHasError = false;
    bool phoneHasError = false;

    // 封裝顯示對話框的函數，當isProcessing變化時可以重新呼叫
    Future<void> showProcessingDialog() async {
      return showDialog<void>(
        context: context,
        barrierDismissible: !isProcessing, // 根據處理狀態決定是否可點擊空白處關閉
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return WillPopScope(
                onWillPop: () async => !isProcessing, // 處理中時禁止返回鍵關閉
                child: Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      width: 320.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 1,
                            offset: Offset(0, 8.h),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: 30.h),

                          // 對話框圖標
                          SizedBox(
                            width: 55.w,
                            height: 55.h,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // 底部陰影
                                Positioned(
                                  left: 0,
                                  top: 3.h,
                                  child: Image.asset(
                                    'assets/images/icon/checking.webp',
                                    width: 55.w,
                                    height: 55.h,
                                    color: Colors.black.withOpacity(0.4),
                                    colorBlendMode: BlendMode.srcIn,
                                  ),
                                ),
                                // 主圖像
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: Image.asset(
                                    'assets/images/icon/checking.webp',
                                    width: 55.w,
                                    height: 55.h,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 15.h),

                          // 標題
                          Text(
                            '訂位資訊',
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontFamily: 'OtsutomeFont',
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF23456B),
                            ),
                          ),

                          // 刪除了說明文字
                          SizedBox(height: 18.h),

                          // 預訂人姓名輸入框
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 30.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: 8.w,
                                    bottom: 4.h,
                                  ),
                                  child: Text(
                                    '預訂人稱呼',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: const Color(0xFF23456B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  margin: EdgeInsets.only(bottom: 10.h),
                                  padding: EdgeInsets.only(
                                    left: 12.w,
                                    right: 8.w,
                                  ),
                                  height: 50.h,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: const Color(0xFF23456B),
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: nameController,
                                          onChanged: (value) {
                                            if (nameHasError &&
                                                value.trim().isNotEmpty) {
                                              setDialogState(() {
                                                nameHasError = false;
                                              });
                                            }
                                          },
                                          style: TextStyle(
                                            fontFamily: 'OtsutomeFont',
                                            fontSize: 16.sp,
                                            height: 1.2,
                                          ),
                                          decoration: InputDecoration(
                                            hintText:
                                                nameHasError
                                                    ? '請填寫預訂人稱呼'
                                                    : 'e.g. 陳先生',
                                            border: InputBorder.none,
                                            hintStyle: TextStyle(
                                              color:
                                                  nameHasError
                                                      ? const Color(0xFFB33D1C)
                                                      : Colors.grey,
                                              fontFamily: 'OtsutomeFont',
                                              fontSize: 14.sp,
                                              height: 1.2,
                                            ),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  vertical: 15.h,
                                                ),
                                            isDense: true,
                                            alignLabelWithHint: true,
                                          ),
                                          textAlignVertical:
                                              TextAlignVertical.center,
                                        ),
                                      ),
                                      SizedBox(width: 5.w),
                                      // 帶陰影的圖標
                                      SizedBox(
                                        width: 28.w,
                                        height: 28.h,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          alignment: Alignment.center,
                                          children: [
                                            // 底部陰影圖片
                                            Positioned(
                                              left: 0,
                                              top: 2,
                                              child: Image.asset(
                                                'assets/images/icon/user_profile.webp',
                                                width: 25.w,
                                                height: 25.h,
                                                fit: BoxFit.contain,
                                                color: Colors.black.withOpacity(
                                                  0.4,
                                                ),
                                                colorBlendMode: BlendMode.srcIn,
                                              ),
                                            ),
                                            // 圖片主圖層
                                            Positioned(
                                              left: 0,
                                              top: 0,
                                              child: Image.asset(
                                                'assets/images/icon/user_profile.webp',
                                                width: 25.w,
                                                height: 25.h,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 8.h),
                          // 聯絡電話輸入框
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 30.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: 8.w,
                                    bottom: 4.h,
                                  ),
                                  child: Text(
                                    '電話末三碼',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: const Color(0xFF23456B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  margin: EdgeInsets.only(bottom: 15.h),
                                  padding: EdgeInsets.only(
                                    left: 12.w,
                                    right: 8.w,
                                  ),
                                  height: 50.h,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: const Color(0xFF23456B),
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: phoneController,
                                          onChanged: (value) {
                                            if (phoneHasError &&
                                                value.trim().isNotEmpty) {
                                              setDialogState(() {
                                                phoneHasError = false;
                                              });
                                            }
                                          },
                                          keyboardType: TextInputType.phone,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          style: TextStyle(
                                            fontFamily: 'OtsutomeFont',
                                            fontSize: 16.sp,
                                            height: 1.2,
                                          ),
                                          decoration: InputDecoration(
                                            hintText:
                                                phoneHasError
                                                    ? '請填寫電話末三碼'
                                                    : 'e.g. 870',
                                            border: InputBorder.none,
                                            hintStyle: TextStyle(
                                              color:
                                                  phoneHasError
                                                      ? const Color(0xFFB33D1C)
                                                      : Colors.grey,
                                              fontFamily: 'OtsutomeFont',
                                              fontSize: 14.sp,
                                              height: 1.2,
                                            ),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  vertical: 15.h,
                                                ),
                                            isDense: true,
                                            alignLabelWithHint: true,
                                          ),
                                          textAlignVertical:
                                              TextAlignVertical.center,
                                        ),
                                      ),
                                      SizedBox(width: 5.w),
                                      // 帶陰影的圖標
                                      SizedBox(
                                        width: 28.w,
                                        height: 28.h,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          alignment: Alignment.center,
                                          children: [
                                            // 底部陰影圖片
                                            Positioned(
                                              left: 0,
                                              top: 2,
                                              child: Image.asset(
                                                'assets/images/icon/phone.webp',
                                                width: 25.w,
                                                height: 25.h,
                                                fit: BoxFit.contain,
                                                color: Colors.black.withOpacity(
                                                  0.4,
                                                ),
                                                colorBlendMode: BlendMode.srcIn,
                                              ),
                                            ),
                                            // 圖片主圖層
                                            Positioned(
                                              left: 0,
                                              top: 0,
                                              child: Image.asset(
                                                'assets/images/icon/phone.webp',
                                                width: 25.w,
                                                height: 25.h,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 15.h),

                          // 按鈕區域
                          Padding(
                            padding: EdgeInsets.only(bottom: 25.h),
                            child:
                                isProcessing
                                    ? Center(
                                      child: LoadingImage(
                                        width: 60.w,
                                        height: 60.h,
                                        color: const Color(0xFFB33D1C),
                                      ),
                                    )
                                    : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // 左側按鈕 - 不接受訂位
                                        ImageButton(
                                          text: '不接受訂位',
                                          imagePath:
                                              'assets/images/ui/button/blue_l.webp',
                                          width: 120.w,
                                          height: 55.h,
                                          onPressed: () async {
                                            try {
                                              // 顯示處理中狀態
                                              setDialogState(() {
                                                isProcessing = true;
                                              });

                                              // 使用空字符串作為訂位資訊
                                              final response =
                                                  await diningService
                                                      .confirmRestaurant(
                                                        eventId,
                                                        reservationName: "",
                                                        reservationPhone: "",
                                                      );

                                              // 更新UserStatusService中的資訊
                                              if (mounted) {
                                                final userStatusService =
                                                    Provider.of<
                                                      UserStatusService
                                                    >(context, listen: false);

                                                userStatusService.updateStatus(
                                                  eventStatus: 'confirmed',
                                                  reservationName: "",
                                                  reservationPhone: "",
                                                );

                                                // 關閉對話框
                                                Navigator.of(
                                                  dialogContext,
                                                ).pop();

                                                // 顯示成功訊息
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      '已確認不接受訂位',
                                                      style: TextStyle(
                                                        fontFamily:
                                                            'OtsutomeFont',
                                                      ),
                                                    ),
                                                  ),
                                                );

                                                // 導航到下一個頁面
                                                _navigationService
                                                    .navigateToDinnerInfo(
                                                      context,
                                                    );
                                              }
                                            } catch (e) {
                                              // 重置處理狀態
                                              setDialogState(() {
                                                isProcessing = false;
                                              });

                                              _handleApiError(dialogContext, e);
                                            }
                                          },
                                          textStyle: TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'OtsutomeFont',
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        SizedBox(width: 20.w),

                                        // 右側按鈕 - 已訂位
                                        ImageButton(
                                          text: '已訂位',
                                          imagePath:
                                              'assets/images/ui/button/red_m.webp',
                                          width: 120.w,
                                          height: 55.h,
                                          onPressed: () async {
                                            try {
                                              // 顯示處理中狀態
                                              setDialogState(() {
                                                isProcessing = true;
                                              });

                                              // 獲取輸入的預訂資訊
                                              final reservationName =
                                                  nameController.text.trim();
                                              final reservationPhone =
                                                  phoneController.text.trim();

                                              // 檢查輸入是否完整
                                              if (reservationName.isEmpty ||
                                                  reservationPhone.isEmpty) {
                                                // 重置處理狀態並設置錯誤狀態
                                                setDialogState(() {
                                                  isProcessing = false;
                                                  nameHasError =
                                                      reservationName.isEmpty;
                                                  phoneHasError =
                                                      reservationPhone.isEmpty;
                                                });
                                                return;
                                              }

                                              // 輸入完整，清除錯誤狀態
                                              setDialogState(() {
                                                nameHasError = false;
                                                phoneHasError = false;
                                              });

                                              // 調用API確認餐廳預訂
                                              final response =
                                                  await diningService
                                                      .confirmRestaurant(
                                                        eventId,
                                                        reservationName:
                                                            reservationName,
                                                        reservationPhone:
                                                            reservationPhone,
                                                      );

                                              // 更新UserStatusService中的資訊
                                              if (mounted) {
                                                final userStatusService =
                                                    Provider.of<
                                                      UserStatusService
                                                    >(context, listen: false);

                                                userStatusService.updateStatus(
                                                  eventStatus: 'confirmed',
                                                  reservationName:
                                                      reservationName,
                                                  reservationPhone:
                                                      reservationPhone,
                                                );

                                                debugPrint(
                                                  '已更新聚餐事件狀態為confirmed，預訂人：$reservationName',
                                                );

                                                // 關閉對話框
                                                Navigator.of(
                                                  dialogContext,
                                                ).pop();

                                                // 顯示成功訊息
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      '餐廳預訂資訊已確認',
                                                      style: TextStyle(
                                                        fontFamily:
                                                            'OtsutomeFont',
                                                      ),
                                                    ),
                                                  ),
                                                );

                                                // 導航到下一個頁面
                                                _navigationService
                                                    .navigateToDinnerInfo(
                                                      context,
                                                    );
                                              }
                                            } catch (e) {
                                              // 重置處理狀態
                                              setDialogState(() {
                                                isProcessing = false;
                                              });

                                              _handleApiError(dialogContext, e);
                                            }
                                          },
                                          textStyle: TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'OtsutomeFont',
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    // 呼叫顯示對話框
    return showProcessingDialog();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return WillPopScope(
        onWillPop: () async {
          return false; // 禁用返回按鈕
        },
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background/bg2.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: LoadingImage(
                width: 60.w,
                height: 60.h,
                color: const Color(0xFF23456B),
              ),
            ),
          ),
        ),
      );
    }

    // 定義卡片寬度，確保一致性
    final cardWidth = MediaQuery.of(context).size.width - 48.w;

    return WillPopScope(
      onWillPop: () async {
        return false; // 禁用返回按鈕
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background/bg2.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // 頂部導航欄 - 移到滾動區域內
                  HeaderBar(title: '餐廳預訂'),

                  // 主要內容
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20.h),
                        // 標題
                        Text(
                          '確認有營業',
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontFamily: 'OtsutomeFont',
                            color: const Color(0xFF23456B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        // 小標題
                        Text(
                          '可以的話幫忙訂位',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontFamily: 'OtsutomeFont',
                            color: const Color(0xFF23456B),
                          ),
                        ),
                        SizedBox(height: 25.h),

                        // 餐廳資訊卡片
                        Container(
                          width: cardWidth,
                          margin: EdgeInsets.symmetric(vertical: 0.h),
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
                              // 餐廳圖片和上半部分 - 整體可點擊
                              GestureDetector(
                                onTap: () => _openMap(_restaurantMapUrl),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 餐廳圖片
                                    ClipRRect(
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(15.r),
                                        topRight: Radius.circular(15.r),
                                      ),
                                      child:
                                          _restaurantImageUrl != null
                                              ? Image.network(
                                                _restaurantImageUrl!,
                                                width: double.infinity,
                                                height: 150.h,
                                                fit: BoxFit.cover,
                                                errorBuilder: (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) {
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

                                    // 餐廳詳細資訊
                                    Padding(
                                      padding: EdgeInsets.all(15.h),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),

                                          SizedBox(height: 8.h),
                                          // 餐廳地址
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _restaurantAddress ?? '地址未提供',
                                                  style: TextStyle(
                                                    fontSize: 14.sp,
                                                    fontFamily: 'OtsutomeFont',
                                                    color: const Color(
                                                      0xFF23456B,
                                                    ),
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

                              // 分隔線
                              Container(
                                height: 1,
                                color: Colors.grey[300],
                                margin: EdgeInsets.symmetric(horizontal: 12.w),
                              ),

                              // 聚餐時間和人數部分
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 15.h,
                                  vertical: 15.h,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // 左側聚餐時間
                                    SizedBox(
                                      width: cardWidth * 0.4,
                                      child: Row(
                                        children: [
                                          // 時間圖標
                                          Padding(
                                            padding: EdgeInsets.only(
                                              bottom: 5.h,
                                            ),
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
                                                      'assets/images/icon/clock.webp',
                                                      width: 35.w,
                                                      height: 35.h,
                                                      color: Colors.black
                                                          .withOpacity(0.4),
                                                      colorBlendMode:
                                                          BlendMode.srcIn,
                                                    ),
                                                  ),
                                                  // 主圖標
                                                  Image.asset(
                                                    'assets/images/icon/clock.webp',
                                                    width: 35.w,
                                                    height: 35.h,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          SizedBox(width: 10.w),

                                          // 時間資訊文字
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
                                                    color: const Color(
                                                      0xFF23456B,
                                                    ),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(height: 2.h),
                                                Consumer<UserStatusService>(
                                                  builder: (
                                                    context,
                                                    userStatusService,
                                                    child,
                                                  ) {
                                                    final dinnerTime =
                                                        userStatusService
                                                            .confirmedDinnerTime;
                                                    return Text(
                                                      dinnerTime != null
                                                          ? '${dinnerTime.month}月${dinnerTime.day}日 ${dinnerTime.hour}:${dinnerTime.minute.toString().padLeft(2, '0')}'
                                                          : '時間待定',
                                                      style: TextStyle(
                                                        fontSize: 12.sp,
                                                        fontFamily:
                                                            'OtsutomeFont',
                                                        color: const Color(
                                                          0xFF666666,
                                                        ),
                                                      ),
                                                    );
                                                  },
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

                                    // 右側人數部分
                                    SizedBox(
                                      width: cardWidth * 0.4,
                                      child: Row(
                                        children: [
                                          // 人數圖標
                                          Padding(
                                            padding: EdgeInsets.only(
                                              bottom: 5.h,
                                            ),
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
                                                      'assets/images/icon/attendee.webp',
                                                      width: 35.w,
                                                      height: 35.h,
                                                      color: Colors.black
                                                          .withOpacity(0.4),
                                                      colorBlendMode:
                                                          BlendMode.srcIn,
                                                    ),
                                                  ),
                                                  // 主圖標
                                                  Image.asset(
                                                    'assets/images/icon/attendee.webp',
                                                    width: 35.w,
                                                    height: 35.h,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 10.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '用餐人數',
                                                  style: TextStyle(
                                                    fontSize: 16.sp,
                                                    fontFamily: 'OtsutomeFont',
                                                    color: const Color(
                                                      0xFF23456B,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(height: 2.h),
                                                Consumer<UserStatusService>(
                                                  builder: (
                                                    context,
                                                    userStatusService,
                                                    child,
                                                  ) {
                                                    // 從UserStatusService獲取人數，如未設置則顯示2人
                                                    final attendees =
                                                        userStatusService
                                                            .attendees ??
                                                        2;
                                                    return Text(
                                                      '$attendees人',
                                                      style: TextStyle(
                                                        fontSize: 12.sp,
                                                        fontFamily:
                                                            'OtsutomeFont',
                                                        color: const Color(
                                                          0xFF666666,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
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

                              // 聯絡資訊部分 - 電話和網站
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 15.h,
                                  vertical: 15.h,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // 左側電話資訊
                                    SizedBox(
                                      width: cardWidth * 0.4,
                                      child: InkWell(
                                        onTap: () {
                                          if (_restaurantPhone != null) {
                                            _makePhoneCall(_restaurantPhone!);
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            // 電話圖標 - 使用指定的圖標並添加陰影效果
                                            Padding(
                                              padding: EdgeInsets.only(
                                                bottom: 5.h,
                                              ),
                                              child: SizedBox(
                                                width: 35.w,
                                                height: 35.h,
                                                child: Stack(
                                                  clipBehavior:
                                                      Clip.none, // 允許陰影超出容器範圍
                                                  children: [
                                                    // 底部陰影
                                                    Positioned(
                                                      left: 0,
                                                      top: 2.h,
                                                      child: Image.asset(
                                                        'assets/images/icon/phone.webp',
                                                        width: 35.w,
                                                        height: 35.h,
                                                        color: Colors.black
                                                            .withOpacity(0.4),
                                                        colorBlendMode:
                                                            BlendMode.srcIn,
                                                      ),
                                                    ),
                                                    // 主圖標
                                                    Image.asset(
                                                      'assets/images/icon/phone.webp',
                                                      width: 35.w,
                                                      height: 35.h,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            SizedBox(width: 10.w),

                                            // 電話資訊文字
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '電話',
                                                    style: TextStyle(
                                                      fontSize: 16.sp,
                                                      fontFamily:
                                                          'OtsutomeFont',
                                                      color: const Color(
                                                        0xFF23456B,
                                                      ),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  SizedBox(height: 2.h),
                                                  Text(
                                                    _restaurantPhone ?? '未提供',
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      fontFamily:
                                                          'OtsutomeFont',
                                                      color: const Color(
                                                        0xFF666666,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // 垂直分隔線
                                    Container(
                                      height: 45.h,
                                      width: 1.w,
                                      color: Colors.grey[300],
                                    ),

                                    // 右側網站部分
                                    SizedBox(
                                      width: cardWidth * 0.4,
                                      child: InkWell(
                                        onTap: () {
                                          if (_restaurantWebsite != null &&
                                              _restaurantWebsite != "未提供") {
                                            _openWebsite(_restaurantWebsite!);
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            // 網站圖標
                                            Padding(
                                              padding: EdgeInsets.only(
                                                bottom: 5.h,
                                              ),
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
                                                        'assets/images/icon/link.webp',
                                                        width: 35.w,
                                                        height: 35.h,
                                                        color: Colors.black
                                                            .withOpacity(0.4),
                                                        colorBlendMode:
                                                            BlendMode.srcIn,
                                                      ),
                                                    ),
                                                    // 主圖標
                                                    Image.asset(
                                                      'assets/images/icon/link.webp',
                                                      width: 35.w,
                                                      height: 35.h,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 10.w),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '網站',
                                                    style: TextStyle(
                                                      fontSize: 16.sp,
                                                      fontFamily:
                                                          'OtsutomeFont',
                                                      color: const Color(
                                                        0xFF23456B,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 2.h),
                                                  Text(
                                                    _restaurantWebsite !=
                                                                null &&
                                                            _restaurantWebsite !=
                                                                "未提供"
                                                        ? '點擊前往'
                                                        : '未提供',
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      fontFamily:
                                                          'OtsutomeFont',
                                                      color: const Color(
                                                        0xFF666666,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 40.h),

                        // 確認按鈕
                        Center(
                          child:
                              _isProcessingAction
                                  ? Container(
                                    margin: EdgeInsets.only(bottom: 15.h),
                                    child: LoadingImage(
                                      width: 60.w,
                                      height: 60.h,
                                      color: const Color(0xFFB33D1C),
                                    ),
                                  )
                                  : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // 左側藍色按鈕 - 這間無法
                                      ImageButton(
                                        text: '這間無法',
                                        imagePath:
                                            'assets/images/ui/button/blue_l.webp',
                                        width: 150.w,
                                        height: 70.h,
                                        onPressed: _handleCannotReserve,
                                      ),
                                      SizedBox(width: 20.w),
                                      // 右側橘色按鈕 - 已確認
                                      ImageButton(
                                        text: '已確認',
                                        imagePath:
                                            'assets/images/ui/button/red_m.webp',
                                        width: 150.w,
                                        height: 70.h,
                                        onPressed: _handleReservationConfirm,
                                      ),
                                    ],
                                  ),
                        ),

                        SizedBox(height: 30.h),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
