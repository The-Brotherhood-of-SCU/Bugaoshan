import {
  FlutterAbility,
  FlutterEngine,
  MethodCall,
  MethodChannel,
  MethodResult
} from '@ohos/flutter_ohos';
import { Want, wantConstant } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import fileuri from '@ohos.file.fileuri';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { DynamicIconChannel } from '../platform/DynamicIconChannel';
import { EnvironmentInfoChannel } from '../platform/EnvironmentInfoChannel';
import { CourseCardChannel } from '../cards/CourseCardChannel';

const CHANNEL = 'bugaoshan/update';

export default class EntryAbility extends FlutterAbility {
  private methodChannel: MethodChannel | null = null;
  private iconChannel: MethodChannel | null = null;
  private environmentChannel: MethodChannel | null = null;
  private fileSaveChannel: MethodChannel | null = null;
  private savingFile: boolean = false;
  private cards: CourseCardChannel | null = null;

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);

    const icons = new DynamicIconChannel();
    this.iconChannel = new MethodChannel(flutterEngine.getDartExecutor(), 'bugaoshan/dynamic_icon');
    this.iconChannel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        icons.handle(call, result);
      }
    });
    const environment = new EnvironmentInfoChannel();
    this.environmentChannel = new MethodChannel(flutterEngine.getDartExecutor(), 'bugaoshan/environment_info');
    this.environmentChannel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        environment.handle(call, result);
      }
    });
    this.fileSaveChannel = new MethodChannel(flutterEngine.getDartExecutor(), 'bugaoshan/file_save');
    this.fileSaveChannel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method === 'save') {
          this.saveFile(call, result);
        } else {
          result.notImplemented();
        }
      }
    });
    this.cards = new CourseCardChannel(this.context);
    this.methodChannel = new MethodChannel(flutterEngine.getDartExecutor(), CHANNEL);
    this.methodChannel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method === 'importIcsToCalendar') {
          this.importIcsToCalendar(call.argument('path') as string, result);
        } else if (this.cards?.handle(call, result)) {
          // The card handler completes its own result.
        } else {
          result.notImplemented();
        }
      }
    });
  }

  cleanUpFlutterEngine(flutterEngine: FlutterEngine): void {
    this.cards?.dispose();
    this.methodChannel?.setMethodCallHandler(null);
    this.iconChannel?.setMethodCallHandler(null);
    this.environmentChannel?.setMethodCallHandler(null);
    this.fileSaveChannel?.setMethodCallHandler(null);
    this.methodChannel = null;
    this.iconChannel = null;
    this.environmentChannel = null;
    this.fileSaveChannel = null;
    this.cards = null;
    super.cleanUpFlutterEngine(flutterEngine);
  }

  private async saveFile(call: MethodCall, result: MethodResult): Promise<void> {
    const fileName = call.argument('fileName') as string;
    const bytes = call.argument('bytes') as Uint8Array;
    if (typeof fileName !== 'string' || fileName.length === 0 || !(bytes instanceof Uint8Array)) {
      result.error('INVALID_ARGUMENT', 'File name and bytes are required', null);
      return;
    }
    if (this.savingFile) {
      result.error('ALREADY_ACTIVE', 'File save dialog is already active', null);
      return;
    }

    this.savingFile = true;
    try {
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [fileName];
      const uris = await new picker.DocumentViewPicker(this.context).save(options);
      if (uris.length === 0) {
        result.success(null);
        return;
      }
      const file = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(file.fd, new Uint8Array(bytes).buffer);
        fs.fsyncSync(file.fd);
      } finally {
        fs.closeSync(file.fd);
      }
      result.success(uris[0]);
    } catch (error) {
      result.error('SAVE_FAILED', (error as Error).message, null);
    } finally {
      this.savingFile = false;
    }
  }

  private async importIcsToCalendar(path: string, result: MethodResult): Promise<void> {
    if (typeof path !== 'string' || path.length === 0) {
      result.error('INVALID_ARGUMENT', 'Path is empty', null);
      return;
    }

    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: fileuri.getUriFromPath(path),
        type: 'text/calendar',
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION,
        parameters: {
          mimeType: 'text/calendar'
        }
      };

      await this.context.startAbility(want);
      // 这里只确认打开了接收端，实际导入由用户在日历应用中确认。
      result.success('opened');
    } catch (error) {
      result.error('OPEN_FAILED', (error as Error).message, null);
    }
  }
}
