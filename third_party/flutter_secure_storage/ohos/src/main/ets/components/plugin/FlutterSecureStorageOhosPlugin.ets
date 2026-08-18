/*
 * Copyright (C) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  BinaryMessenger,
  StandardMethodCodec,
} from '@ohos/flutter_ohos';
import FlutterSecureStorage from './FlutterSecureStorage';

const TAG: string = "SecureStorage::FlutterSecureStoragePlugin";

/** FlutterSecureStorageOhosPlugin **/
export default class FlutterSecureStorageOhosPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private secureStorage: FlutterSecureStorage | null = null;
  private ELEMENT_PREFERENCES_KEY_PREFIX: string = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg";

  public initInstance(messenger: BinaryMessenger, context: Context) {
    try {
      this.secureStorage = new FlutterSecureStorage(context, new Map());
      this.channel = new MethodChannel(messenger, "plugins.it_nomads.com/flutter_secure_storage", StandardMethodCodec.INSTANCE);
      this.channel.setMethodCallHandler(this);
    } catch (e) {
      console.error(TAG, "Registration failed", e);
    }
  }

  getUniqueClassName(): string {
    return TAG;
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.initInstance(binding.getBinaryMessenger(), binding.getApplicationContext());
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
  }

  private getKeyFromCall(call: MethodCall): string {
    if (this.secureStorage != null) {
      let map: ESObject = call.args;
      let key: string = this.ELEMENT_PREFERENCES_KEY_PREFIX + '_' + (map.get("key"));
      return key;
    } else {
      return '';
    }
  }

  private getValueFromCall(call: MethodCall): string {
    let map: ESObject = call.args;
    return map.get("value");
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method == "getPlatformVersion") {
      result.success("OpenHarmony ^ ^ ");
    } else {
      let resetOnError: boolean = false;
      if(!this.secureStorage) return;
      this.secureStorage.options = call.args.get("options");
      resetOnError = this.secureStorage.getResetOnError();
      try {
        switch (call.method) {
          case 'write': {
            let key: string = this.getKeyFromCall(call);
            let value: string = this.getValueFromCall(call);
            if (value != null) {
              this.secureStorage?.write(key, value).then(() => {
                result.success(null);
              }).catch(() => {
                result.success(null);
              });
            } else {
              result.error("null", null, null);
            }
            break;
          }
          case "read": {
            let key: string = this.getKeyFromCall(call);

            if (this.secureStorage.containsKey(key)) {
              this.secureStorage.read(key).then(res => {
                let value: string = res;
                result.success(value);
              }).catch(() => {
                result.success(null);
              });
            } else {
              result.success(null);
            }
            break;
          }
          case "readAll": {
            this.secureStorage.readAll().then((all: Map<string, string>) => {
              result.success(all);
            }).catch(() => {
              result.success(null);
            });
            break;
          }
          case "containsKey": {
            let key: string = this.getKeyFromCall(call);

            let containsKey: boolean = this.secureStorage.containsKey(key);
            result.success(containsKey);
            break;
          }
          case "delete": {
            let key: string = this.getKeyFromCall(call);

            this.secureStorage?.delete(key).then(() => {
              result.success(null);
            }).catch(() => {
              result.success(null);
            });
            break;
          }
          case "deleteAll": {
            this.secureStorage.deleteAll().then(() => {
              result.success(null);
            }).catch(() => {
              result.success(null);
            });
            break;
          }
          default:
            result.notImplemented();
            break;
        }
      } catch (e) {
        if (resetOnError) {
          try {
            this.secureStorage.deleteAll();
            result.success("Data has been reset");
          } catch (e) {
            console.error(TAG, 'resetOnError and deleteAll failure,  error code is ' + e.code + ', error message is ' +  e.message);
          }
        } else {
          console.error(TAG, 'resetOnError is false,  error code is ' + e.code + ', error message is ' +  e.message);
        }
      }
    }
  }
}