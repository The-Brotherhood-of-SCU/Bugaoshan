part of 'app_logger.dart';

/// 每次开关操作截断批次，后续日志在新的操作之后写入，避免被旧清理任务删除。
class _LogWriteBatch {
  int through;

  _LogWriteBatch(this.through);
}

extension _AppLoggerFileSink on AppLogger {
  Future<T> _serializeFileOperation<T>(Future<T> Function() action) {
    final operation = _fileOperations.then((_) => action());
    // 一个操作失败不能阻断后续关闭、清理或用户手动重试。
    _fileOperations = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }

  int _endWriteBatch() {
    _pendingDrain = null;
    return _writeSequence;
  }

  Future<void> _enableFileSink({
    String? overridePath,
    bool includeBufferedEntries = false,
  }) {
    if (_disposed) return Future<void>.value();
    final replayBuffer = includeBufferedEntries && !_fileSinkEnabled;
    _fileSinkEnabled = true;
    if (replayBuffer) {
      for (final entry in _buffer) {
        if (entry.level.index >= AppLogger._minPersistedLevel.index &&
            entry.tag != AppLogger._tag) {
          _appendToFile(entry.format(includeDate: true), scheduleDrain: false);
        }
      }
    }
    final through = _endWriteBatch();
    final operation = _serializeFileOperation(() async {
      try {
        final path =
            overridePath ?? _logDirPath ?? (await resolveLogDir()).path;
        if (_fileSink == null || !_fileSinkHealthy || _logDirPath != path) {
          await _closeFileSink();
          _logDirPath = path;
          _sinkRecoveryAttempts = 0;
          await _openCurrentLogFile();
        }
        await _drainQueue(() => through);
      } catch (error, stackTrace) {
        _recordSinkFailure('开启日志落盘失败', error, stackTrace);
        await _closeFileSink();
      }
    });
    _notify();
    return operation;
  }

  Future<void> _flushFileSink() {
    final through = _endWriteBatch();
    return _serializeFileOperation(() => _drainQueue(() => through));
  }

  Future<void> _disableFileSink() {
    _fileSinkEnabled = false;
    final through = _endWriteBatch();
    final operation = _serializeFileOperation(() async {
      await _drainQueue(() => through, allowRecovery: false);
      await _closeFileSink();
      _discardQueuedThrough(through);
      _fileSinkError = null;
      _sinkRecoveryAttempts = 0;
      _notify();
    });
    _notify();
    return operation;
  }

  Future<void> _openCurrentLogFile() async {
    final dir = Directory(_logDirPath!);
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '${AppLogger._logFileBaseName}.log'));
    _bytesWritten = await file.exists() ? await file.length() : 0;
    final sink = file.openWrite(mode: FileMode.append, encoding: utf8);
    _fileSink = sink;
    _fileSinkPath = file.path;
    // openWrite 异步打开文件：立即监听，并等待 flush 验证句柄实际可用。
    unawaited(
      sink.done.catchError((Object error, StackTrace stackTrace) {
        if (identical(_fileSink, sink)) {
          _recordSinkFailure('日志文件写入失败', error, stackTrace);
        }
      }),
    );
    // 空 sink 的 flush 会立即返回；提交空字节块让它等待异步文件打开。
    sink.add(const <int>[]);
    await sink.flush();
    _fileSinkHealthy = true;
    _fileSinkError = null;
    _notify();
  }

  void _recordSinkFailure(String message, Object error, StackTrace stackTrace) {
    final detail = LogRedactor.apply(error.toString());
    if (!_fileSinkHealthy && _fileSinkError == detail) return;
    _fileSinkHealthy = false;
    _fileSinkError = detail;
    _reportingSinkFailure = true;
    try {
      e(
        AppLogger._tag,
        message,
        error: error,
        stackTrace: stackTrace,
        category: LogCategory.business,
      );
    } finally {
      _reportingSinkFailure = false;
    }
  }

  Future<void> _closeFileSink() async {
    final sink = _fileSink;
    // 先摘掉句柄，旧 sink.done 的失败不会干扰下一次打开。
    _fileSink = null;
    _fileSinkPath = null;
    _fileSinkHealthy = false;
    if (sink == null) return;
    try {
      await sink.flush();
    } catch (error, stackTrace) {
      _recordSinkFailure('刷新日志文件失败', error, stackTrace);
    }
    try {
      await sink.close();
    } catch (error, stackTrace) {
      _recordSinkFailure('关闭日志文件失败', error, stackTrace);
    }
  }

  Future<bool> _recoverSink() async {
    if (_disposed || !_fileSinkEnabled || _logDirPath == null) return false;
    if (_sinkRecoveryAttempts >= AppLogger._maxSinkRecoveryAttempts) {
      return false;
    }
    _sinkRecoveryAttempts++;
    await _closeFileSink();
    try {
      await _openCurrentLogFile();
      // 只有实际记录成功 flush 才重置次数。空文件打开成功后写入仍可能失败。
      return true;
    } catch (error, stackTrace) {
      _recordSinkFailure('重建日志文件失败', error, stackTrace);
      await _closeFileSink();
      return false;
    }
  }

  void _appendToFile(String line, {bool scheduleDrain = true}) {
    if (_writeQueue.length >= AppLogger._maxWriteQueue) {
      _droppedLines++;
      return;
    }
    _writeQueue.add((sequence: ++_writeSequence, line: line));
    if (scheduleDrain) _ensureDraining();
  }

  void _ensureDraining() {
    if (_writeQueue.isEmpty) return;
    if (_pendingDrain case final batch?) {
      batch.through = _writeSequence;
      return;
    }
    final batch = _LogWriteBatch(_writeSequence);
    _pendingDrain = batch;
    unawaited(
      _serializeFileOperation(() async {
        try {
          await _drainQueue(() => batch.through);
        } finally {
          if (identical(_pendingDrain, batch)) _pendingDrain = null;
        }
      }),
    );
  }

  Future<void> _drainQueue(
    int Function() through, {
    bool allowRecovery = true,
  }) async {
    while (_writeQueue.isNotEmpty && _writeQueue.first.sequence <= through()) {
      try {
        // POSIX 上缓存被清理后旧句柄仍可写，不能只依赖 flush 抛错来恢复。
        // 每批次检查一次路径，不为每条记录单独做文件系统调用。
        if (_fileSink != null &&
            _fileSinkHealthy &&
            !await File(_fileSinkPath!).exists()) {
          await _closeFileSink();
        }
        if (_fileSink == null || !_fileSinkHealthy) {
          if (!allowRecovery ||
              !_fileSinkEnabled ||
              _disposed ||
              _logDirPath == null) {
            return;
          }
          if (_sinkRecoveryAttempts >= AppLogger._maxSinkRecoveryAttempts) {
            return;
          }
          if (!await _recoverSink()) continue;
        }
        if (_bytesWritten > 0 && _bytesWritten >= maxBytesPerFile) {
          await _rotate();
        }
        final sink = _fileSink!;
        final path = _fileSinkPath!;
        var count = 0;
        for (final record in _writeQueue) {
          if (record.sequence > through()) break;
          sink.writeln(record.line);
          _bytesWritten += utf8.encode('${record.line}\n').length;
          count++;
          if (_bytesWritten >= maxBytesPerFile) break;
        }
        await sink.flush();
        // 写入期间被清理时仍保留本批记录，交给下一次重开补写。
        if (!await File(path).exists()) {
          throw FileSystemException('日志文件在写入时被清理', path);
        }
        // flush 成功前保留记录，失败重开后仍可补写（部分写入时可能重复）。
        _writeQueue.removeRange(0, count);
        _sinkRecoveryAttempts = 0;
      } catch (error, stackTrace) {
        _recordSinkFailure('日志落盘失败', error, stackTrace);
        await _closeFileSink();
      }
    }
  }

  Future<void> _rotate() async {
    final dir = Directory(_logDirPath!);
    final current = File(p.join(dir.path, '${AppLogger._logFileBaseName}.log'));
    await _closeFileSink();
    File history(int index) =>
        File(p.join(dir.path, '${AppLogger._logFileBaseName}.$index.log'));
    if (maxFileCount > 0) {
      final oldest = history(maxFileCount);
      if (await oldest.exists()) await oldest.delete();
      for (var i = maxFileCount - 1; i >= 1; i--) {
        final file = history(i);
        if (await file.exists()) await file.rename(history(i + 1).path);
      }
      if (await current.exists()) await current.rename(history(1).path);
    } else if (await current.exists()) {
      await current.delete();
    }
    await _openCurrentLogFile();
  }

  void _discardQueuedThrough(int through) {
    _writeQueue.removeWhere((record) => record.sequence <= through);
  }

  RegExp get _persistedFilePattern => RegExp(
    '^${RegExp.escape(AppLogger._logFileBaseName)}(\\.\\d+)?'
    '${RegExp.escape(AppLogger._logFileExtension)}\$',
  );

  Future<void> _deletePersistedFiles({
    String? overridePath,
    required bool preserveEnabled,
  }) {
    final reopen = preserveEnabled && _fileSinkEnabled;
    if (!preserveEnabled) _fileSinkEnabled = false;
    final through = _endWriteBatch();
    final operation = _serializeFileOperation(() async {
      await _closeFileSink();
      _discardQueuedThrough(through);
      try {
        final path =
            overridePath ?? _logDirPath ?? (await resolveLogDir()).path;
        final dir = Directory(path);
        if (await dir.exists()) {
          await for (final entity in dir.list()) {
            if (entity is File &&
                _persistedFilePattern.hasMatch(p.basename(entity.path))) {
              try {
                await entity.delete();
              } catch (error, stackTrace) {
                _recordSinkFailure('删除日志文件失败', error, stackTrace);
              }
            }
          }
        }
        _sinkRecoveryAttempts = 0;
        if (reopen && _fileSinkEnabled && !_disposed) {
          _logDirPath = path;
          await _openCurrentLogFile();
        }
      } catch (error, stackTrace) {
        _recordSinkFailure('清理日志文件失败', error, stackTrace);
        await _closeFileSink();
      }
      _notify();
    });
    _notify();
    return operation;
  }

  Future<String> _exportToFile(Directory targetDir) {
    final through = _endWriteBatch();
    return _serializeFileOperation(() async {
      await _drainQueue(() => through);
      await targetDir.create(recursive: true);
      final sourceDir = Directory(_logDirPath ?? targetDir.path);
      final files = <File>[];
      if (await sourceDir.exists()) {
        await for (final entity in sourceDir.list()) {
          if (entity is File &&
              _persistedFilePattern.hasMatch(p.basename(entity.path))) {
            files.add(entity);
          }
        }
      }
      int generation(File file) =>
          int.tryParse(
            _persistedFilePattern
                    .firstMatch(p.basename(file.path))!
                    .group(1)
                    ?.substring(1) ??
                '',
          ) ??
          0;
      files.sort((a, b) => generation(b).compareTo(generation(a)));
      final content = StringBuffer('# Bugaoshan persisted logs\n');
      for (final file in files) {
        content.writeln('# file: ${p.basename(file.path)}');
        content.writeln(LogRedactor.apply(await file.readAsString()));
      }
      content.writeln('# Current in-memory context');
      content.write(exportToText());
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final file = File(p.join(targetDir.path, 'bugaoshan-export-$stamp.log'));
      await file.writeAsString(content.toString(), encoding: utf8);
      try {
        await _trimExportSnapshots(targetDir, file.path);
      } catch (error, stackTrace) {
        // 快照清理失败不代表活动日志不可写，也不能让已成功的导出失败。
        _reportingSinkFailure = true;
        try {
          e(
            AppLogger._tag,
            '清理旧日志快照失败',
            error: error,
            stackTrace: stackTrace,
            category: LogCategory.business,
          );
        } finally {
          _reportingSinkFailure = false;
        }
      }
      return file.path;
    });
  }

  Future<void> _trimExportSnapshots(
    Directory directory,
    String currentPath,
  ) async {
    final pattern = RegExp(r'^bugaoshan-export-(\d+)\.log$');
    final snapshots = <({File file, int timestamp})>[];
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      if (p.equals(entity.path, currentPath)) continue;
      final match = pattern.firstMatch(p.basename(entity.path));
      final timestamp = match == null ? null : int.tryParse(match[1]!);
      if (timestamp != null) {
        snapshots.add((file: entity, timestamp: timestamp));
      }
    }
    snapshots.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    // 始终保留本次导出，系统时间回拨也不能删除即将分享的文件。
    for (final snapshot in snapshots.skip(AppLogger._maxExportSnapshots - 1)) {
      await snapshot.file.delete();
    }
  }
}
