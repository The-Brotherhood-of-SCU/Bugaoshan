import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import fileuri from '@ohos.file.fileuri';
import { MethodCall, MethodResult } from '@ohos/flutter_ohos';

// Keep selected documents in the app cache: picker URIs are not Dart file paths.
export class FilePickerChannel {
  private context: common.UIAbilityContext;
  private busy: boolean = false;
  private disposed: boolean = false;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async handle(call: MethodCall, result: MethodResult): Promise<void> {
    if (call.method !== 'pickFiles') {
      result.notImplemented();
      return;
    }
    if (this.busy || this.disposed) {
      result.error('ALREADY_ACTIVE', 'File picker is unavailable or already open', null);
      return;
    }
    const raw = call.argument('allowedExtensions') as Object[] | null;
    if (!Array.isArray(raw) || raw.length === 0 || raw.length > 100) {
      result.error('INVALID_ARGUMENT', 'File extensions are required', null);
      return;
    }
    const extensions: string[] = [];
    for (const item of raw) {
      if (typeof item !== 'string' || !/^[a-zA-Z0-9]+$/.test(item)) {
        result.error('INVALID_ARGUMENT', 'Invalid file extension', null);
        return;
      }
      extensions.push(item.toLowerCase());
    }

    this.busy = true;
    let directory = '';
    try {
      const options = new picker.DocumentSelectOptions();
      options.fileSuffixFilters = [extensions.map((extension: string) => `.${extension}`).join(',')];
      options.maxSelectNumber = 100;
      const uris = await new picker.DocumentViewPicker(this.context).select(options);
      if (this.disposed) throw new Error('File picker disposed');
      if (uris.length === 0) {
        result.success([]);
        return;
      }
      directory = await fs.mkdtemp(`${this.context.cacheDir}/cloud-print-XXXXXX`);
      const files: Map<string, Object>[] = [];
      for (const uri of new Set<string>(uris)) {
        if (this.disposed) throw new Error('File picker disposed');
        const name = new fileuri.FileUri(uri).name.replace(/[\/\\\u0000-\u001f\u007f]/g, '_');
        const extension = name.substring(name.lastIndexOf('.') + 1).toLowerCase();
        if (name.length === 0 || name === '.' || name === '..' || !extensions.includes(extension)) {
          throw new Error('Unsupported selected file');
        }
        // A separate directory preserves same-named documents from different sources.
        const fileDirectory = `${directory}/${files.length}`;
        await fs.mkdir(fileDirectory);
        const destination = `${fileDirectory}/${name}`;
        const source = await fs.open(uri, fs.OpenMode.READ_ONLY);
        try {
          const stat = await fs.stat(source.fd);
          if (!stat.isFile() || stat.size === 0) throw new Error('Empty or unsupported selected file');
          await fs.copyFile(source.fd, destination);
          const file = new Map<string, Object>();
          file.set('name', name);
          file.set('path', destination);
          files.push(file);
        } finally {
          await fs.close(source);
        }
      }
      if (this.disposed) throw new Error('File picker disposed');
      // The print queue owns these snapshots until the app cache is cleared.
      result.success(files);
    } catch (error) {
      if (directory.length > 0) {
        try {
          await fs.rmdir(directory);
        } catch (cleanupError) {
          hilog.error(0x0000, 'FilePicker', 'Unable to remove incomplete selection: %{public}s',
            `${(cleanupError as BusinessError).code ?? 'unknown'}`);
        }
      }
      // Do not pass user document names or URIs to application logs.
      result.error('PICK_FAILED', `Unable to read selected documents (${(error as BusinessError).code ?? 'unknown'})`, null);
    } finally {
      this.busy = false;
    }
  }

  dispose(): void {
    this.disposed = true;
  }
}
