/// 用于更新检查的语义版本号。
///
/// 主、次、修订版本号及纯数字预发布字段按数值比较，构建元数据不参与排序。
/// 支持 `v` 前缀，并将历史的 `pre7`、`rc2` 等后缀按 `pre.7`、`rc.2` 比较。
class ReleaseVersion implements Comparable<ReleaseVersion> {
  ReleaseVersion._(this._core, this._prerelease);

  final List<String> _core;
  final List<String> _prerelease;

  bool get isPrerelease => _prerelease.isNotEmpty;

  static final _pattern = RegExp(
    r'^[vV]?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
    r'(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$',
  );
  static final _digits = RegExp(r'^\d+$');
  static final _legacyPrerelease = RegExp(
    r'^(alpha|beta|pre|preview|rc|snapshot)(\d+)$',
  );

  /// 将 [value] 解析为用于更新比较的语义版本号。
  ///
  /// 支持 `v1.2.3`、`1.2.3+4`、`1.2.3-preview.12` 及历史预发布格式。
  /// 无法解析为有效版本号时返回 `null`。
  static ReleaseVersion? tryParse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null || match.end != value.length) return null;
    final prerelease = <String>[];
    for (final field in match.group(4)?.split('.') ?? <String>[]) {
      if (_digits.hasMatch(field) &&
          field.length > 1 &&
          field.startsWith('0')) {
        return null;
      }
      // 将历史的 `pre7`、`rc2` 规范为 `pre.7`、`rc.2`，以按数值比较序号。
      final legacy = _legacyPrerelease.firstMatch(field);
      if (legacy == null) {
        prerelease.add(field);
      } else {
        prerelease.add(legacy.group(1)!);
        prerelease.add(legacy.group(2)!.replaceFirst(RegExp(r'^0+(?=\d)'), ''));
      }
    }
    return ReleaseVersion._([
      match.group(1)!,
      match.group(2)!,
      match.group(3)!,
    ], prerelease);
  }

  /// 比较当前版本与 [other] 的优先级。
  ///
  /// 先比较主、次、修订版本号，再比较预发布字段；同一基础版本的正式版更高。
  /// 返回负数、零或正数，分别表示当前版本更低、相同或更高。
  @override
  int compareTo(ReleaseVersion other) {
    for (int i = 0; i < _core.length; i++) {
      final result = _compareNumber(_core[i], other._core[i]);
      if (result != 0) return result;
    }
    if (!isPrerelease || !other.isPrerelease) {
      if (isPrerelease == other.isPrerelease) return 0;
      return isPrerelease ? -1 : 1;
    }
    for (int i = 0; i < _prerelease.length; i++) {
      if (i >= other._prerelease.length) return 1;
      final left = _prerelease[i];
      final right = other._prerelease[i];
      final leftNumeric = _digits.hasMatch(left);
      final rightNumeric = _digits.hasMatch(right);
      final int result;
      if (leftNumeric && rightNumeric) {
        result = _compareNumber(left, right);
      } else if (leftNumeric != rightNumeric) {
        result = leftNumeric ? -1 : 1;
      } else {
        result = left.compareTo(right);
      }
      if (result != 0) return result;
    }
    return _prerelease.length.compareTo(other._prerelease.length);
  }

  /// 按数值大小比较两个纯数字字段。
  ///
  /// 先比较长度，再比较字典序，避免使用 `int.parse` 时溢出。
  static int _compareNumber(String left, String right) {
    final length = left.length.compareTo(right.length);
    return length == 0 ? left.compareTo(right) : length;
  }
}
