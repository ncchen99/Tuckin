/// 數字格式化工具函數
class NumberFormatter {
  /// 將數字轉換為中文數字
  ///
  /// 支持範圍：0-999
  ///
  /// 範例：
  /// - 0 → '零'
  /// - 3 → '三'
  /// - 10 → '十'
  /// - 15 → '十五'
  /// - 23 → '二十三'
  /// - 100 → '一百'
  static String toChinese(int number) {
    if (number == 0) return '零';

    final List<String> digits = [
      '零',
      '一',
      '二',
      '三',
      '四',
      '五',
      '六',
      '七',
      '八',
      '九',
    ];
    final List<String> units = ['', '十', '百', '千'];

    if (number < 10) {
      return digits[number];
    } else if (number < 20) {
      return '十${number == 10 ? '' : digits[number % 10]}';
    } else if (number < 100) {
      int tens = number ~/ 10;
      int ones = number % 10;
      return '${digits[tens]}十${ones == 0 ? '' : digits[ones]}';
    } else if (number < 1000) {
      int hundreds = number ~/ 100;
      int remainder = number % 100;
      String result = '${digits[hundreds]}百';
      if (remainder == 0) {
        return result;
      } else if (remainder < 10) {
        return '$result零${digits[remainder]}';
      } else {
        return result + toChinese(remainder);
      }
    }

    // 對於更大的數字，直接返回阿拉伯數字
    return number.toString();
  }
}
