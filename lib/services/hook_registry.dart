import 'package:bugaoshan/utils/app_log.dart';

/// 一个可被订阅的「时机」。
///
/// 用常量对象而不是字符串作为标识：订阅方写错名字会在编译期报错
/// （`CourseProvider.courseChangedTypo` 不存在），而不是运行期静默收不到通知。
class Hook<T> {
  const Hook(this.name);

  /// 时机名，仅用于日志和调试快照，不参与匹配（匹配用的是该常量对象的自身身份）。
  final String name;

  @override
  String toString() => name;
}

/// 取消订阅句柄，调用一次即退订。
typedef Cancel = void Function();

/// 全局「时机」注册中心。
///
/// 职责只有两条：
/// 1. 拥有者（Provider / Service）在这里声明自己会在哪些时机发出通知；
/// 2. 把「某个拥有者的某个时机」广播给所有订阅者。
///
/// 与单一回调字段的区别：同一个时机可以挂任意多个订阅者，后订阅者不会覆盖先订阅者。
/// 与裸事件总线的区别：订阅一个从未声明过的时机（通常是笔误或漏了 `register`）
/// 会立即抛错，而不是静默收不到通知。
class HookRegistry {
  HookRegistry();

  /// App 级共享实例。测试可自行 `HookRegistry()` 新建一个，避免用例间互相污染。
  static final HookRegistry instance = HookRegistry();

  static const String _tag = 'HookRegistry';

  /// owner -> (时机名 -> 订阅者列表)
  final Map<Object, Map<String, List<void Function(Object?)>>> _subscribers =
      {};

  /// 声明 [owner] 提供的所有时机。重复声明是幂等的。
  void register(Object owner, List<Hook<dynamic>> hooks) {
    final perOwner = _subscribers.putIfAbsent(owner, () => {});
    for (final hook in hooks) {
      perOwner.putIfAbsent(hook.name, () => <void Function(Object?)>[]);
    }
    AppLog.i(
      _tag,
      '注册时机：${owner.runtimeType} → ${hooks.map((h) => h.name).join(', ')}',
    );
  }

  /// 订阅 [owner] 的 [hook]，返回取消句柄。
  Cancel on<T>(Object owner, Hook<T> hook, void Function(T value) listener) {
    final bucket = _requireBucket(owner, hook);
    void wrapper(Object? value) => listener(value as T);
    bucket.add(wrapper);
    AppLog.d(
      _tag,
      '订阅时机：${owner.runtimeType}.${hook.name}（当前 ${bucket.length} 个订阅者）',
    );
    return () => bucket.remove(wrapper);
  }

  /// 拥有者发出通知：同步分发给该时机的全部订阅者。
  ///
  /// 逐个隔离异常：某个订阅者写崩了不能阻断其余订阅者。
  void fire<T>(Object owner, Hook<T> hook, T value) {
    final bucket = _requireBucket(owner, hook);
    if (bucket.isEmpty) {
      // 不是错误：拥有者可能在订阅者就绪前就发出了通知。留一条 debug 线索，
      // 便于排查「明明有事件、界面却没反应」这类问题。
      AppLog.d(_tag, '${owner.runtimeType}.${hook.name} 无订阅者，本次通知被丢弃');
      return;
    }
    // 拷贝后遍历：允许订阅者在回调内部退订自己。
    for (final listener in List<void Function(Object?)>.of(bucket)) {
      try {
        listener(value);
      } catch (error, stackTrace) {
        AppLog.e(
          _tag,
          '${owner.runtimeType}.${hook.name} 订阅者执行失败',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// 调试快照：`'CourseProvider.courseChanged': 2` 表示当前有几个订阅者。
  Map<String, int> debugSnapshot() {
    final snapshot = <String, int>{};
    for (final owner in _subscribers.entries) {
      for (final hook in owner.value.entries) {
        snapshot['${owner.key.runtimeType}.${hook.key}'] = hook.value.length;
      }
    }
    return snapshot;
  }

  List<void Function(Object?)> _requireBucket(
    Object owner,
    Hook<dynamic> hook,
  ) {
    final bucket = _subscribers[owner]?[hook.name];
    if (bucket == null) {
      // 未声明的时机几乎总是笔误或漏了 register：直接抛出而不是静默无通知，
      // 同时记一条错误日志，避免异常被上层吞掉后毫无线索。
      final message =
          '未注册的时机：${owner.runtimeType}.${hook.name}，'
          '请先在拥有者构造时调用 register() 声明该时机';
      AppLog.e(_tag, message);
      throw StateError('HookRegistry: $message');
    }
    return bucket;
  }
}
