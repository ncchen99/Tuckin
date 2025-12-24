import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';

class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  // 用於存儲當前的錯誤狀態
  bool _hasError = false;
  String? _errorMessage;
  String? _detailedErrorMessage; // 新增：詳細錯誤信息用於調試
  bool _isServerError = false;
  bool _isNetworkError = false;
  VoidCallback? _retryCallback;

  // 用於通知 UI 更新的控制器
  final _errorController = StreamController<bool>.broadcast();

  // 獲取錯誤狀態流
  Stream<bool> get errorStream => _errorController.stream;

  // 獲取當前錯誤狀態
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  String? get detailedErrorMessage => _detailedErrorMessage;
  bool get isServerError => _isServerError;
  bool get isNetworkError => _isNetworkError;
  VoidCallback? get retryCallback => _retryCallback;

  // 顯示錯誤
  void showError({
    required String message,
    required bool isServerError,
    bool isNetworkError = false,
    required VoidCallback onRetry,
  }) {
    _hasError = true;
    _errorMessage = message;
    _detailedErrorMessage = message; // 保存詳細錯誤信息
    _isServerError = isServerError;
    _isNetworkError = isNetworkError;
    _retryCallback = onRetry;
    _errorController.add(true);

    // 輸出詳細錯誤信息進行調試
    debugPrint('ErrorHandler: 顯示錯誤 - 詳細: $_detailedErrorMessage');
    debugPrint(
      'ErrorHandler: 錯誤類型 - 網絡錯誤: $isNetworkError, 伺服器錯誤: $isServerError',
    );
  }

  // 清除錯誤
  void clearError() {
    _hasError = false;
    _errorMessage = null;
    _detailedErrorMessage = null;
    _isServerError = false;
    _isNetworkError = false;
    _retryCallback = null;
    _errorController.add(false);
    debugPrint('ErrorHandler: 清除錯誤');
  }

  // 處理 API 錯誤
  void handleApiError(ApiError error, VoidCallback onRetry) {
    // 保存詳細的錯誤信息用於調試
    final detailedMessage = error.toString();
    debugPrint('ApiError 詳細信息: $detailedMessage');

    showError(
      message: error.message,
      isServerError: error.isServerError,
      isNetworkError: error.isNetworkError || error.isTimeout,
      onRetry: onRetry,
    );
  }

  // 銷毀
  void dispose() {
    _errorController.close();
  }
}

// 用於在 Widget 樹中提供和訪問 ErrorHandler
class ErrorHandlerProvider extends InheritedWidget {
  final ErrorHandler errorHandler;

  const ErrorHandlerProvider({
    super.key,
    required this.errorHandler,
    required super.child,
  });

  static ErrorHandler of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<ErrorHandlerProvider>();
    assert(provider != null, 'No ErrorHandlerProvider found in context');
    return provider!.errorHandler;
  }

  @override
  bool updateShouldNotify(ErrorHandlerProvider oldWidget) {
    return errorHandler != oldWidget.errorHandler;
  }
}
