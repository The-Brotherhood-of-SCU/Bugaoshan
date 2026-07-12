import 'package:bugaoshan/services/download_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same file name from different URLs creates independent tasks', () {
    final manager = DownloadManager();

    final first = manager.enqueue(
      'https://example.com/notices/1/attachment.pdf',
      'notice_attachments',
      'attachment.pdf',
    );
    final second = manager.enqueue(
      'https://example.com/notices/2/attachment.pdf',
      'notice_attachments',
      'attachment.pdf',
    );

    expect(first, isNot(same(second)));
    expect(manager.tasks, hasLength(2));
    expect(
      manager.taskFor(
        'https://example.com/notices/1/attachment.pdf',
        'notice_attachments',
      ),
      same(first),
    );
    expect(
      manager.taskFor(
        'https://example.com/notices/2/attachment.pdf',
        'notice_attachments',
      ),
      same(second),
    );
  });

  test('removing a downloaded path only removes its owning task', () {
    final manager = DownloadManager();
    final first = manager.enqueue(
      'https://example.com/first',
      'notice_attachments',
      'attachment.pdf',
    );
    final second = manager.enqueue(
      'https://example.com/second',
      'notice_attachments',
      'attachment.pdf',
    );
    manager.updateTask(
      first,
      status: DownloadStatus.done,
      downloadedPath: '/downloads/attachment.pdf',
    );
    manager.updateTask(
      second,
      status: DownloadStatus.done,
      downloadedPath: '/downloads/attachment (1).pdf',
    );

    manager.removeByDownloadedPath('/downloads/attachment (1).pdf');

    expect(manager.tasks.values, contains(first));
    expect(manager.tasks.values, isNot(contains(second)));
  });
}
