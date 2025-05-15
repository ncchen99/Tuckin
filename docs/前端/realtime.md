# Tuckin App - Supabase Realtime 實作指南

## 將 dining_events 表格設置為 Realtime

當你在 Supabase 中啟用表格的 realtime 功能時，可以讓客戶端即時接收資料庫變更。以下是實作步驟：

### 在 Supabase 控制台中設置 Realtime

1. 登入 Supabase 控制台
2. 進入您的項目
3. 點擊左側菜單的「Database」
4. 點擊「Replication」標籤
5. 找到「dining_events」表格，並將其啟用為 realtime（勾選 INSERT、UPDATE、DELETE 事件）

### 在 Flutter 應用中實現 Realtime 監聽

#### 1. 擴展 RealtimeService

首先在 `realtime_service.dart` 中添加對 `dining_events` 表格的監聽功能：

```dart
// 新增實時通道
RealtimeChannel? _diningEventsChannel;

// 新增訂閱狀態
bool _isDiningEventsSubscribed = false;

// 聚餐事件監聽器集合
final Map<String, Function(Map<String, dynamic>)> _diningEventListeners = {};

// 訂閱特定聚餐事件變更
Future<void> subscribeToDiningEvent(String diningEventId) async {
  // 檢查 ID 有效性
  if (diningEventId.isEmpty) {
    debugPrint('RealtimeService: 聚餐事件ID為空，無法訂閱');
    return;
  }

  // 取消先前的訂閱
  await _diningEventsChannel?.unsubscribe();

  try {
    // 創建實時通道
    _diningEventsChannel = _supabaseService.client
        .channel('dining_event_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'dining_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: diningEventId,
          ),
          callback: _handleDiningEventChange,
        );

    // 啟動訂閱
    _diningEventsChannel?.subscribe();
    _isDiningEventsSubscribed = true;
  } catch (e) {
    // 錯誤處理與重試機制
  }
}

// 處理聚餐事件變更
void _handleDiningEventChange(PostgresChangePayload payload) {
  final newRecord = payload.newRecord;
  final diningStatus = newRecord['status'] as String?;
  final diningEventId = newRecord['id'] as String?;
  final reservationName = newRecord['reservation_name'] as String?;
  final reservationPhone = newRecord['reservation_phone'] as String?;

  // 創建變更事件數據
  Map<String, dynamic> eventData = {
    'status': diningStatus,
    'id': diningEventId,
    'reservation_name': reservationName,
    'reservation_phone': reservationPhone,
  };

  // 廣播聚餐事件變更通知
  _notifyDiningEventListeners(eventData);
}

// 添加聚餐事件監聽器
void addDiningEventListener(String listenerId, Function(Map<String, dynamic>) listener) {
  _diningEventListeners[listenerId] = listener;
}

// 移除聚餐事件監聽器
void removeDiningEventListener(String listenerId) {
  _diningEventListeners.remove(listenerId);
}

// 通知所有聚餐事件監聽器
void _notifyDiningEventListeners(Map<String, dynamic> eventData) {
  for (var callback in _diningEventListeners.values) {
    callback(eventData);
  }
}
```

#### 2. 在 DinnerInfoPage 中實現監聽

在 `dinner_info_page.dart` 中：

```dart
// 1. 導入 RealtimeService
final RealtimeService _realtimeService = RealtimeService();
String? _diningEventId; // 保存聚餐事件ID

// 2. 在 dispose 方法中移除監聽器
@override
void dispose() {
  if (_diningEventId != null) {
    _realtimeService.removeDiningEventListener('dinner_info_page');
  }
  super.dispose();
}

// 3. 訂閱聚餐事件狀態變更
void _subscribeToDiningEvent(String diningEventId) {
  if (diningEventId.isEmpty) return;
  
  _diningEventId = diningEventId;
  _realtimeService.addDiningEventListener('dinner_info_page', _onDiningEventChange);
  _realtimeService.subscribeToDiningEvent(diningEventId);
}

// 4. 處理聚餐事件變更
void _onDiningEventChange(Map<String, dynamic> eventData) {
  if (!mounted) return;
  
  final newStatus = eventData['status'] as String?;
  final newReservationName = eventData['reservation_name'] as String?;
  final newReservationPhone = eventData['reservation_phone'] as String?;
  
  // 檢查是否需要更新狀態
  bool needsUpdate = false;
  
  if (newStatus != null && newStatus != _dinnerEventStatus) {
    needsUpdate = true;
  }
  
  if (newReservationName != null && newReservationName != _reservationName) {
    needsUpdate = true;
  }
  
  if (newReservationPhone != null && newReservationPhone != _reservationPhone) {
    needsUpdate = true;
  }
  
  // 更新狀態
  if (needsUpdate) {
    final userStatusService = Provider.of<UserStatusService>(context, listen: false);
    
    userStatusService.updateStatus(
      eventStatus: newStatus,
      reservationName: newReservationName,
      reservationPhone: newReservationPhone,
    );
    
    setState(() {
      _dinnerEventStatus = newStatus ?? _dinnerEventStatus;
      _reservationName = newReservationName ?? _reservationName;
      _reservationPhone = newReservationPhone ?? _reservationPhone;
    });
    
    // 根據新狀態執行相應操作
  }
}
```

## 測試方法

1. 在 Supabase Studio 中手動更新 dining_events 表中的記錄
2. 在應用中查看是否即時反映變更
3. 可以通過 `debugPrint` 查看日誌，確認事件是否正確傳遞

## 注意事項

1. 確保 Supabase 的 realtime 功能已啟用
2. 在頁面卸載時記得移除監聽器，避免內存洩漏
3. 處理網絡斷線重連的情況
4. 添加足夠的錯誤處理和日誌記錄，方便調試

## 可能遇到的問題與解決方案

1. **訂閱失敗**：檢查 Supabase 配置和網絡連接
2. **沒有收到更新**：確認表格的 realtime 功能已啟用
3. **應用崩潰**：確保在處理事件回調時檢查 widget 是否仍然掛載
4. **事件重複處理**：實現去重邏輯，避免同一事件被多次處理
