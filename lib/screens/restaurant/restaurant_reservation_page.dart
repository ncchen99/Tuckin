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
  bool _isConfirming = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
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

      // 保存進入頁面的時間戳
      final currentTime = DateTime.now().millisecondsSinceEpoch;
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
        final currentTime = DateTime.now().millisecondsSinceEpoch;
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
              _restaurantWebsite =
                  restaurant['website'] ?? "https://example.com/restaurant";
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

  Future<void> _handleReservationConfirm() async {
    setState(() {
      _isConfirming = true;
    });

    try {
      if (!mounted) {
        debugPrint('_handleReservationConfirm: Widget已卸載，取消操作');
        return;
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

      // 顯示輸入預訂資訊的對話框
      await _showReservationInfoDialog(diningEventId, diningService);
    } catch (e) {
      debugPrint('確認預訂時出錯: $e');
      if (mounted) {
        setState(() {
          _isConfirming = false;
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

    // 設置默認預訂人姓名
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        // 從Provider獲取最新的預訂姓名或用戶ID
        final userStatusService = Provider.of<UserStatusService>(
          context,
          listen: false,
        );

        if (userStatusService.reservationName != null) {
          nameController.text = userStatusService.reservationName!;
        } else {
          // 使用當前用戶ID作為預設值
          nameController.text = '預訂人';
        }
      }
    } catch (e) {
      debugPrint('獲取用戶資訊出錯: $e');
      nameController.text = '預訂人';
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            '訂位資訊',
            style: TextStyle(fontFamily: 'OtsutomeFont'),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text(
                  '請輸入預訂人資訊，以便餐廳確認',
                  style: TextStyle(fontFamily: 'OtsutomeFont'),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '預訂人姓名',
                    hintText: '請輸入預訂人姓名',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontFamily: 'OtsutomeFont'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: '聯絡電話',
                    hintText: '請輸入聯絡電話',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontFamily: 'OtsutomeFont'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                '取消',
                style: TextStyle(fontFamily: 'OtsutomeFont'),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (mounted) {
                  setState(() {
                    _isConfirming = false;
                  });
                }
              },
            ),
            TextButton(
              child: const Text(
                '確認',
                style: TextStyle(fontFamily: 'OtsutomeFont'),
              ),
              onPressed: () async {
                try {
                  Navigator.of(dialogContext).pop();

                  // 顯示加載中對話框
                  if (mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return const AlertDialog(
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                '正在提交預訂資訊...',
                                style: TextStyle(fontFamily: 'OtsutomeFont'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }

                  // 獲取輸入的預訂資訊
                  final reservationName = nameController.text.trim();
                  final reservationPhone = phoneController.text.trim();

                  // 調用API確認餐廳預訂
                  final response = await diningService.confirmRestaurant(
                    eventId,
                    reservationName: reservationName,
                    reservationPhone: reservationPhone,
                  );

                  // 關閉加載中對話框
                  if (mounted) {
                    Navigator.of(context).pop();
                  }

                  // 更新UserStatusService中的資訊
                  if (mounted) {
                    final userStatusService = Provider.of<UserStatusService>(
                      context,
                      listen: false,
                    );

                    userStatusService.updateStatus(
                      eventStatus: 'confirmed',
                      reservationName: reservationName,
                      reservationPhone: reservationPhone,
                    );

                    debugPrint('已更新聚餐事件狀態為confirmed，預訂人：$reservationName');

                    // 顯示成功訊息
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '餐廳預訂資訊已確認',
                          style: TextStyle(fontFamily: 'OtsutomeFont'),
                        ),
                      ),
                    );

                    // 導航到下一個頁面
                    _navigationService.navigateToDinnerInfo(context);
                  }
                } catch (e) {
                  debugPrint('確認餐廳預訂時出錯: $e');
                  if (mounted) {
                    // 關閉加載中對話框（如果存在）
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).popUntil((route) => route.isFirst);

                    setState(() {
                      _isConfirming = false;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '確認餐廳預訂失敗: $e',
                          style: const TextStyle(fontFamily: 'OtsutomeFont'),
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCannotReserve() async {
    // 顯示加載中UI
    setState(() {
      _isConfirming = true;
    });

    try {
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
        iconPath: 'assets/images/icon/failed.png',
        content: '確定要更換另一家餐廳嗎？系統將從候選餐廳中選擇下一間！',
        cancelButtonText: '取消',
        confirmButtonText: '確定',
        onCancel: () {
          Navigator.of(context).pop(false);
          setState(() {
            _isConfirming = false;
          });
        },
        onConfirm: () async {
          // 顯示加載中對話框
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      '正在更換餐廳...',
                      style: TextStyle(fontFamily: 'OtsutomeFont'),
                    ),
                  ],
                ),
              );
            },
          );

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

              // 關閉加載中對話框
              if (mounted) Navigator.of(context).pop();

              // 更新UserStatusService中的餐廳資訊
              userStatusService.updateStatus(
                restaurantInfo: restaurant,
                dinnerRestaurantId: restaurant['id'],
              );

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

              // 返回true表示更換成功
              Navigator.of(context).pop(true);
            } else {
              throw Exception('無法獲取新餐廳資訊');
            }
          } catch (e) {
            debugPrint('更換餐廳時出錯: $e');
            // 關閉加載中對話框（如果存在）
            if (mounted) {
              Navigator.of(
                context,
                rootNavigator: true,
              ).popUntil((route) => route.isFirst);
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '更換餐廳失敗: $e',
                    style: const TextStyle(fontFamily: 'OtsutomeFont'),
                  ),
                ),
              );
            }

            // 返回false表示更換失敗
            if (mounted) Navigator.of(context).pop(false);
          }
        },
      );

      // 如果用戶沒有確認更換（取消了操作）
      if (confirmChange != true) {
        setState(() {
          _isConfirming = false;
        });
      }
    } catch (e) {
      debugPrint('準備更換餐廳時出錯: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '更換餐廳失敗: $e',
              style: const TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    } finally {
      // 重置確認狀態
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
      }
    }
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
              image: AssetImage('assets/images/background/bg2.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 頂部導航欄 - 使用預設顯示TUCKIN
                HeaderBar(title: '餐廳預訂'),

                // 主要內容
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20.h),
                        // 標題
                        Text(
                          '確認餐廳',
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
                          '確認營業時間，可以的話幫忙預定',
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
                              // 餐廳圖片 - 恢復原始設計
                              ClipRRect(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(15.r),
                                  topRight: Radius.circular(15.r),
                                ),
                                child: GestureDetector(
                                  onTap: () => _openMap(_restaurantMapUrl),
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
                                      onTap: () => _openMap(_restaurantMapUrl),
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

                              // 聯絡資訊部分 - 分左右兩區塊
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
                                                        'assets/images/icon/phone.png',
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
                                                      'assets/images/icon/phone.png',
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
                                          if (_restaurantWebsite != null) {
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
                                                        'assets/images/icon/link.png',
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
                                                      'assets/images/icon/link.png',
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
                                                    _restaurantWebsite != null
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

                        SizedBox(height: 60.h),

                        // 確認按鈕
                        Center(
                          child:
                              _isConfirming
                                  ? LoadingImage(
                                    width: 60.w,
                                    height: 60.h,
                                    color: const Color(0xFF23456B),
                                  )
                                  : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // 左側藍色按鈕 - 這間無法
                                      ImageButton(
                                        text: '這間無法',
                                        imagePath:
                                            'assets/images/ui/button/blue_l.png',
                                        width: 150.w,
                                        height: 70.h,
                                        onPressed: _handleCannotReserve,
                                      ),
                                      SizedBox(width: 20.w),
                                      // 右側橘色按鈕 - 已確認
                                      ImageButton(
                                        text: '已確認',
                                        imagePath:
                                            'assets/images/ui/button/red_m.png',
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
