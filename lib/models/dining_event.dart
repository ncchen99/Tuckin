import 'package:flutter/material.dart';

/// 聚餐事件狀態枚舉
enum DiningEventStatus {
  /// 等待配對中
  waitingForMatch,

  /// 已配對，等待確認
  matched,

  /// 已確認，等待餐廳選擇
  confirmedWaitingForRestaurant,

  /// 餐廳已選擇，等待聚餐
  readyForDinner,

  /// 聚餐已完成
  completed,

  /// 聚餐因人數不足被取消
  cancelled,
}

/// 聚餐事件模型
class DiningEvent {
  /// 唯一ID
  final String id;

  /// 聚餐日期 (星期一或星期四)
  final DateTime date;

  /// 聚餐開始時間 (固定為晚上7點)
  final TimeOfDay time;

  /// 是否僅限成大學生
  final bool onlyNckuStudents;

  /// 聚餐事件當前狀態
  final DiningEventStatus status;

  /// 參與者ID列表
  final List<String> participantIds;

  /// 已確認參與者ID列表
  final List<String> confirmedParticipantIds;

  /// 選擇的餐廳ID
  final String? restaurantId;

  /// 創建時間
  final DateTime createdAt;

  /// 更新時間
  final DateTime updatedAt;

  const DiningEvent({
    required this.id,
    required this.date,
    required this.time,
    required this.onlyNckuStudents,
    required this.status,
    required this.participantIds,
    required this.confirmedParticipantIds,
    this.restaurantId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 從JSON創建實例
  factory DiningEvent.fromJson(Map<String, dynamic> json) {
    return DiningEvent(
      id: json['id'],
      date: DateTime.parse(json['date']),
      time: TimeOfDay(
        hour: int.parse(json['time'].split(':')[0]),
        minute: int.parse(json['time'].split(':')[1]),
      ),
      onlyNckuStudents: json['only_ncku_students'],
      status: DiningEventStatus.values.byName(json['status']),
      participantIds: List<String>.from(json['participant_ids']),
      confirmedParticipantIds: List<String>.from(
        json['confirmed_participant_ids'],
      ),
      restaurantId: json['restaurant_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  /// 轉換為JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'time': '${time.hour}:${time.minute}',
      'only_ncku_students': onlyNckuStudents,
      'status': status.name,
      'participant_ids': participantIds,
      'confirmed_participant_ids': confirmedParticipantIds,
      'restaurant_id': restaurantId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// 創建副本並更新狀態
  DiningEvent copyWith({
    String? id,
    DateTime? date,
    TimeOfDay? time,
    bool? onlyNckuStudents,
    DiningEventStatus? status,
    List<String>? participantIds,
    List<String>? confirmedParticipantIds,
    String? restaurantId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiningEvent(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      onlyNckuStudents: onlyNckuStudents ?? this.onlyNckuStudents,
      status: status ?? this.status,
      participantIds: participantIds ?? this.participantIds,
      confirmedParticipantIds:
          confirmedParticipantIds ?? this.confirmedParticipantIds,
      restaurantId: restaurantId ?? this.restaurantId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
