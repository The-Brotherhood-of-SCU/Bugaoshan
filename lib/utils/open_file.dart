import 'package:bugaoshan/platform/platform_adapter.dart';
import 'package:open_filex/open_filex.dart';

export 'package:open_filex/open_filex.dart' show OpenResult, ResultType;

Future<OpenResult> openFile(String path) =>
    PlatformAdapter.instance.openFile(path);
