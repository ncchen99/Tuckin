import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/services/image_cache_service.dart';
import 'package:tuckin/utils/index.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tuckin/services/user_status_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:tuckin/services/dining_service.dart';
import 'package:tuckin/services/realtime_service.dart';
import 'dart:math';
// import 'package:tuckin/services/time_service.dart';

class DinnerInfoPage extends StatefulWidget {
  const DinnerInfoPage({super.key});

  @override
  State<DinnerInfoPage> createState() => _DinnerInfoPageState();
}

class _DinnerInfoPageState extends State<DinnerInfoPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final NavigationService _navigationService = NavigationService();
  final RealtimeService _realtimeService = RealtimeService();
  final Random _random = Random();
  bool _isLoading = true;
  String _userStatus = ''; // 用戶當前狀態（Provider 為主，本地作為回退）
  bool _hasShownBookingDialog = false; // 追蹤是否已顯示過訂位對話框

  // Provider 監聽
  UserStatusService? _userStatusService; // 供監聽狀態變更
  String? _lastUserStatus; // 記錄上一次狀態
  // 移除未使用：聚餐時間僅透過 Provider 提供
  String? _restaurantName;
  String? _restaurantAddress;
  String? _restaurantImageUrl;
  String? _restaurantCategory;
  String? _restaurantMapUrl;

  // 新增變數
  String? _dinnerEventStatus;
  String? _reservationName;
  String? _reservationPhone;
  String? _diningEventId; // 新增: 保存聚餐事件ID用於訂閱
  String? _diningEventDescription; // 新增: 保存聚餐事件描述（密語）

  @override
  void initState() {
    super.initState();
    _loadUserAndDinnerInfo();
    // 建立 Provider 監聽，偵測用戶狀態變更
    _userStatusService = Provider.of<UserStatusService>(context, listen: false);
    _lastUserStatus = _userStatusService!.userStatus;
    _userStatusService!.addListener(_onUserStatusChanged);
    // 在頁面掛載完成後檢查餐廳確認狀態
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint('DinnerInfoPage 完全渲染');
        _checkPendingConfirmation();
      }
    });
  }

  // 當 Provider 的用戶狀態變更時呼叫
  void _onUserStatusChanged() {
    if (!mounted || _userStatusService == null) return;
    final String? newStatus = _userStatusService!.userStatus;
    if (newStatus != _lastUserStatus) {
      debugPrint('DinnerInfoPage: 用戶狀態變更 -> $_lastUserStatus → $newStatus');
      _lastUserStatus = newStatus;
      // 當進入顯示聚餐資訊的狀態時重新拉資料
      if (newStatus == 'waiting_attendance' || newStatus == 'waiting_dinner') {
        _loadUserAndDinnerInfo();
      }
      setState(() {
        _userStatus = newStatus ?? _userStatus;
      });
    }
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
      iconPath: 'assets/images/icon/reservation.webp',
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
    // 移除聚餐事件監聽器
    if (_diningEventId != null) {
      _realtimeService.removeDiningEventListener('dinner_info_page');
    }
    // 解除 Provider 監聽
    _userStatusService?.removeListener(_onUserStatusChanged);
    super.dispose();
  }

  // 訂閱聚餐事件狀態變更
  void _subscribeToDiningEvent(String diningEventId) {
    if (diningEventId.isEmpty) {
      debugPrint('無法訂閱聚餐事件：ID為空');
      return;
    }

    // 保存聚餐事件ID
    _diningEventId = diningEventId;

    // 添加監聽器
    _realtimeService.addDiningEventListener(
      'dinner_info_page',
      _onDiningEventChange,
    );

    // 訂閱聚餐事件
    _realtimeService.subscribeToDiningEvent(diningEventId);
    debugPrint('已訂閱聚餐事件：$diningEventId');
  }

  // 處理聚餐事件變更
  void _onDiningEventChange(Map<String, dynamic> eventData) {
    debugPrint('接收到聚餐事件變更：$eventData');

    // 如果頁面已卸載，忽略事件
    if (!mounted) {
      debugPrint('頁面已卸載，忽略聚餐事件變更');
      return;
    }

    final newStatus = eventData['status'] as String?;
    final newReservationName = eventData['reservation_name'] as String?;
    final newReservationPhone = eventData['reservation_phone'] as String?;
    final newRestaurantId = eventData['restaurant_id'] as String?;
    final newDescription = eventData['description'] as String?;

    // 檢查是否需要更新狀態
    bool needsUpdate = false;
    bool needsReloadData = false;

    if (newStatus != null && newStatus != _dinnerEventStatus) {
      needsUpdate = true;
      debugPrint('聚餐事件狀態變更：$_dinnerEventStatus -> $newStatus');
    }

    if (newReservationName != null && newReservationName != _reservationName) {
      needsUpdate = true;
      debugPrint('訂位人姓名變更：$_reservationName -> $newReservationName');
    }

    if (newReservationPhone != null &&
        newReservationPhone != _reservationPhone) {
      needsUpdate = true;
      debugPrint('訂位人電話變更：$_reservationPhone -> $newReservationPhone');
    }

    // 檢查描述（密語）是否變更
    if (newDescription != null && newDescription != _diningEventDescription) {
      needsUpdate = true;
      debugPrint('聚餐事件描述變更：$_diningEventDescription -> $newDescription');
    }

    // 檢查餐廳ID是否變更
    if (newRestaurantId != null) {
      // 獲取 UserStatusService 以檢查當前餐廳ID
      final userStatusService = Provider.of<UserStatusService>(
        context,
        listen: false,
      );

      final currentRestaurantId = userStatusService.dinnerRestaurantId;

      if (currentRestaurantId != newRestaurantId) {
        needsUpdate = true;
        needsReloadData = true; // 餐廳變更時需要重新載入完整數據
        debugPrint('餐廳ID變更：$currentRestaurantId -> $newRestaurantId');
      }
    }

    // 如果需要更新，則更新狀態並重新加載頁面數據
    if (needsUpdate) {
      // 獲取 UserStatusService 以更新 Provider 中的狀態
      final userStatusService = Provider.of<UserStatusService>(
        context,
        listen: false,
      );

      // 更新 Provider 中的聚餐事件狀態
      userStatusService.updateStatus(
        eventStatus: newStatus,
        reservationName: newReservationName,
        reservationPhone: newReservationPhone,
        dinnerRestaurantId: newRestaurantId,
      );

      // 更新本地狀態
      setState(() {
        _dinnerEventStatus = newStatus ?? _dinnerEventStatus;
        _reservationName = newReservationName ?? _reservationName;
        _reservationPhone = newReservationPhone ?? _reservationPhone;
        _diningEventDescription = newDescription ?? _diningEventDescription;
      });

      // 如果餐廳ID變更或需要重新載入數據，則重新載入完整頁面數據
      if (needsReloadData) {
        debugPrint('餐廳資訊變更，重新載入頁面數據');
        _loadUserAndDinnerInfo();
      }

      // 根據新狀態可能需要顯示相關對話框
      if (newStatus == 'pending_confirmation' && !_hasShownBookingDialog) {
        _showBookingConfirmationDialog();
      }
    }
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

        // 聚餐時間顯示統一由 UserStatusService 提供，不再使用伺服器時間
        String? restaurantName;
        String? restaurantAddress;
        String? restaurantImageUrl;
        String? restaurantCategory;
        String? restaurantMapUrl;
        String? dinnerEventStatus;
        String? reservationName;
        String? reservationPhone;
        int? attendeeCount; // 新增變數存儲用餐人數
        String? diningEventId; // 新增: 保存聚餐事件ID
        String? diningEventDescription; // 新增: 保存聚餐事件描述

        if (diningEvent != null) {
          // 從聚餐事件中獲取狀態和預訂信息
          dinnerEventStatus = diningEvent['status'];
          reservationName = diningEvent['reservation_name'];
          reservationPhone = diningEvent['reservation_phone'];
          diningEventDescription = diningEvent['description'];

          // 獲取聚餐事件ID並訂閱
          diningEventId = diningEvent['id'];
          if (diningEventId != null) {
            _subscribeToDiningEvent(diningEventId);
          }

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

            // 更新 UserStatusService 中的數據（移除時間欄位更新）
            userStatusService.updateStatus(
              dinnerRestaurantId: diningEvent['restaurant_id'],
              // 新增：保存配對組ID、聚餐事件ID和餐廳詳細信息
              matchingGroupId: diningEvent['matching_group_id'],
              diningEventId: diningEventId, // 使用新變數
              restaurantInfo: restaurant,
              eventStatus: dinnerEventStatus,
              reservationName: reservationName,
              reservationPhone: reservationPhone,
              attendees: attendeeCount,
            );

            debugPrint('已更新UserStatusService中的餐廳信息: ${restaurant['name']}');
          }
        } else {
          // 嘗試從 UserStatusService 獲取餐廳信息，如果有的話
          final cachedRestaurantInfo = userStatusService.restaurantInfo;
          dinnerEventStatus = userStatusService.eventStatus;
          reservationName = userStatusService.reservationName;
          reservationPhone = userStatusService.reservationPhone;

          // 嘗試從 UserStatusService 獲取聚餐事件ID
          diningEventId = userStatusService.diningEventId;
          if (diningEventId != null) {
            _subscribeToDiningEvent(diningEventId);
          }

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
          // 移除本地 _dinnerTime，聚餐時間統一由 Provider 提供
          _restaurantName = restaurantName;
          _restaurantAddress = restaurantAddress;
          _restaurantImageUrl = restaurantImageUrl;
          _restaurantCategory = restaurantCategory;
          _restaurantMapUrl = restaurantMapUrl;
          _dinnerEventStatus = dinnerEventStatus;
          _reservationName = reservationName;
          _reservationPhone = reservationPhone;
          _diningEventId = diningEventId; // 新增: 保存聚餐事件ID
          _diningEventDescription = diningEventDescription; // 新增: 保存聚餐事件描述
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

  // 根據傳入的用戶狀態獲取標題文字（改為參數化，避免依賴本地快照）
  String _getStatusTextFor(String? userStatus) {
    switch (userStatus) {
      case 'waiting_other_users':
        return '正在等待其他用戶確認...';
      case 'waiting_attendance':
      case 'waiting_dinner':
        return '聚餐資訊';
      default:
        return '';
    }
  }

  // 已移除：未使用的開地圖共用函數，改在點擊處理中直接處理

  // 已移除：未使用的星期縮寫輔助方法

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
                              'assets/images/icon/reservation.webp',
                              width: 28.w,
                              height: 28.h,
                              color: Colors.black.withOpacity(0.3),
                              colorBlendMode: BlendMode.srcIn,
                            ),
                          ),
                          // 主圖標
                          Image.asset(
                            'assets/images/icon/reservation.webp',
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
                          'assets/images/icon/checking.webp',
                          width: 28.w,
                          height: 28.h,
                          color: Colors.black.withOpacity(0.3),
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                      // 主圖標
                      Image.asset(
                        'assets/images/icon/checking.webp',
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
          // 優先使用資料庫中的描述（統一密語），如果沒有才隨機生成
          String passphrase =
              _diningEventDescription?.isNotEmpty == true
                  ? _diningEventDescription!
                  : _getRandomPassphrase();
          message = '餐廳無法訂位，可能需要候位，\n使用密語找到夥伴：\n\n$passphrase';
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
                          'assets/images/icon/done.webp',
                          width: 28.w,
                          height: 28.h,
                          color: Colors.black.withOpacity(0.3),
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                      // 主圖標
                      Image.asset(
                        'assets/images/icon/done.webp',
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
                        'assets/images/icon/info.webp',
                        width: 28.w,
                        height: 28.h,
                        color: Colors.black.withOpacity(0.3),
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                    // 主圖標
                    Image.asset(
                      'assets/images/icon/info.webp',
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

  String _getRandomPassphrase() {
    final List<String> passphrases = [
      '不好意思，你可以幫我拍照嗎',
      '不好意思，可以跟你借衛生紙嗎',
      '不好意思，請問火車站怎麼走',
      '不好意思，你有在排隊嗎',
      '想問你有吃過這家店嗎',
      '你好，你也在等朋友嗎',
    ];
    return passphrases[_random.nextInt(passphrases.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserStatusService>(
      builder: (context, userStatusService, child) {
        // 從 Provider 取得最新用戶狀態，若暫無則回退到本地快照
        final String currentUserStatus =
            userStatusService.userStatus ?? _userStatus;

        // 根據狀態決定顯示內容（改為使用 currentUserStatus，確保 Provider 更新可即時反映）
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

        // 從 UserStatusService 獲取聚餐時間（僅供後續 FutureBuilder 回退參考，若未使用則不建立本地變數）

        // 已移除 waiting_other_users 的 UI（改由 DinnerInfoWaitingPage 顯示）
        // 構建出席/聚餐資訊的UI
        {
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
                                ? CachedNetworkImage(
                                  imageUrl: _restaurantImageUrl!,
                                  cacheManager:
                                      ImageCacheService()
                                          .restaurantCacheManager,
                                  width: double.infinity,
                                  height: 150.h,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) {
                                    return Container(
                                      width: double.infinity,
                                      height: 150.h,
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF23456B),
                                        ),
                                      ),
                                    );
                                  },
                                  errorWidget: (context, url, error) {
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
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
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
                            children: [
                              // 左側時間信息
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(left: 5.w),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // 時間圖標 - 固定在左側
                                      SizedBox(
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
                                                color: Colors.black.withOpacity(
                                                  0.4,
                                                ),
                                                colorBlendMode: BlendMode.srcIn,
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

                                      SizedBox(width: 15.w),

                                      // 時間信息文字 - 固定在圖標右側
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
                                            Consumer<UserStatusService>(
                                              builder: (
                                                context,
                                                userStatusService,
                                                child,
                                              ) {
                                                return Text(
                                                  userStatusService
                                                      .simpleDinnerTimeDescription,
                                                  style: TextStyle(
                                                    fontSize: 14.sp,
                                                    fontFamily: 'OtsutomeFont',
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
                              ),

                              // 垂直分隔線
                              Container(
                                height: 45.h,
                                width: 1.w,
                                color: Colors.grey[300],
                              ),

                              // 右側導航部分
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    debugPrint(
                                      '點擊了導航按鈕，嘗試打開地圖: $_restaurantMapUrl',
                                    );
                                    if (_restaurantMapUrl != null) {
                                      final Uri url = Uri.parse(
                                        _restaurantMapUrl!,
                                      );
                                      launchUrl(
                                            url,
                                            mode:
                                                LaunchMode.externalApplication,
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
                                                      fontFamily:
                                                          'OtsutomeFont',
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
                                                      fontFamily:
                                                          'OtsutomeFont',
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                          });
                                    }
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.only(left: 15.w),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // 導航圖標 - 固定在左側
                                        SizedBox(
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
                                                  'assets/images/icon/navigation.webp',
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
                                                'assets/images/icon/navigation.webp',
                                                width: 35.w,
                                                height: 35.h,
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 15.w),
                                        // 導航文字 - 固定在圖標右側
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '導航',
                                                style: TextStyle(
                                                  fontSize: 16.sp,
                                                  fontFamily: 'OtsutomeFont',
                                                  color: const Color(
                                                    0xFF23456B,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: 2.h),
                                              Text(
                                                'Google Map',
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  fontFamily: 'OtsutomeFont',
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
                              ),
                            ],
                          ),

                          // 水平分隔線
                          Container(
                            height: 1,
                            color: Colors.grey[300],
                            margin: EdgeInsets.symmetric(
                              horizontal: 0.w,
                              vertical: 15.h,
                            ),
                          ),

                          // 第二行：參加名單和聊天室
                          Row(
                            children: [
                              // 左側參加名單
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(left: 5.w),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // 名單圖標 - 固定在左側
                                      SizedBox(
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
                                                'assets/images/icon/list.webp',
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
                                              'assets/images/icon/list.webp',
                                              width: 35.w,
                                              height: 35.h,
                                            ),
                                          ],
                                        ),
                                      ),

                                      SizedBox(width: 15.w),

                                      // 名單信息文字 - 固定在圖標右側
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '參加名單',
                                              style: TextStyle(
                                                fontSize: 16.sp,
                                                fontFamily: 'OtsutomeFont',
                                                color: const Color(0xFF23456B),
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
                                                final attendees =
                                                    userStatusService
                                                        .attendees ??
                                                    0;
                                                return Text(
                                                  '${NumberFormatter.toChinese(attendees)}個人',
                                                  style: TextStyle(
                                                    fontSize: 14.sp,
                                                    fontFamily: 'OtsutomeFont',
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
                              ),

                              // 垂直分隔線
                              Container(
                                height: 45.h,
                                width: 1.w,
                                color: Colors.grey[300],
                              ),

                              // 右側聊天室部分
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    // TODO: 導航到聊天室頁面
                                    debugPrint('點擊了聊天室按鈕');
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.only(left: 15.w),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // 聊天室圖標 - 固定在左側
                                        SizedBox(
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
                                                  'assets/images/icon/chat2.webp',
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
                                                'assets/images/icon/chat2.webp',
                                                width: 35.w,
                                                height: 35.h,
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 15.w),
                                        // 聊天室文字 - 固定在圖標右側
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '聊天室',
                                                style: TextStyle(
                                                  fontSize: 16.sp,
                                                  fontFamily: 'OtsutomeFont',
                                                  color: const Color(
                                                    0xFF23456B,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: 2.h),
                                              Text(
                                                '點擊開啟',
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  fontFamily: 'OtsutomeFont',
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
                  image: AssetImage('assets/images/background/bg2.jpg'),
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
                            'assets/images/illustrate/p3.webp',
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
                        HeaderBar(title: _getStatusTextFor(currentUserStatus)),

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
      },
    );
  }
}
