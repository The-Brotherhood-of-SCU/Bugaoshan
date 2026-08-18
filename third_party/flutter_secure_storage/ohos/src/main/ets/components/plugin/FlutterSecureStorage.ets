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

import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';

import { StorageCipherFactory } from './ciphers/StorageCipherFactory';
import StorageCipher from './ciphers/StorageCipher';
import { convertObjectToMap, StringToUint8Array, Uint8ArrayToString } from './utils';

interface KeyPrefixInterface {
  get getKeyPrefix(): string;
  set setKeyPrefix(value: string);
}

const TAG: string = "SecureStorage::FlutterSecureStorage";

export default class FlutterSecureStorage implements KeyPrefixInterface {
  private context: Context | null = null;
  protected ELEMENT_PREFERENCES_KEY_PREFIX: string = "";
  public options: Map<String, Object> = new Map();
  private SHARED_PREFERENCES_NAME: string = "FlutterSecureStorage";
  private dataPreferences: preferences.Preferences | null = null;
  private storageCipher: StorageCipher | null = null;
  private storageCipherFactory: StorageCipherFactory | null = null;
  base64: util.Base64Helper = new util.Base64Helper();

  constructor(context: Context, options: Map<String, Object>) {
    this.context = context;
    this.options = options;
    this.setKeyPrefix = 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg';
  }

  public async write(key: string, value: string) {
    try {
      this.ensureInitialized();
      if(!this.dataPreferences || !this.storageCipher) return;

      let result = await this.storageCipher.encrypt({data: StringToUint8Array(value)});
      let resultStr = this.base64.encodeToStringSync(result.data);

      await this.dataPreferences.put(key, resultStr);
      await this.dataPreferences.flush();
    } catch (e) {
      console.error(TAG, 'error code ' + e.code + 'error message ' + e.message);
    }
  }

  public async read(key: string): Promise<string> {
    try {
      this.ensureInitialized();
      if (!this.dataPreferences) {
        return '';
      }
      let result: preferences.ValueType = this.dataPreferences.getSync(key, null);
      result = await this.decodeRawValue(result as string);
      return result;
    } catch (e) {
      console.error(TAG, 'error code ' + e.code + 'error message ' + e.message);
      return '';
    }
  }

  get getKeyPrefix(): string {
    return this.ELEMENT_PREFERENCES_KEY_PREFIX;
  }

  set setKeyPrefix(key: string) {
    this.ELEMENT_PREFERENCES_KEY_PREFIX = key;
  }

  public async readAll(): Promise<Map<string, string>>{
    let all: Map<string, string> =  new Map();
    try {
      this.ensureInitialized();
      if(!this.dataPreferences) return new Map();

      let raw: Object = this.dataPreferences.getAllSync();
      let rawMap = convertObjectToMap(raw);
      let promises: Promise<void>[] = [];

      if(!rawMap.size) return all;
      rawMap.forEach(async (rawVal, rawKey) => {
        const keyWithPrefix: string = rawKey;
        if (keyWithPrefix.includes(this.getKeyPrefix)) {
          const key = rawKey.split('_')[1];
          const valuePromise: Promise<string> = this.decodeRawValue(rawVal);
          promises.push(valuePromise.then((value: string) => {
            all.set(key, value);
          }))
        }
      })
      await Promise.all(promises);
    } catch (e) {
      console.error(TAG, 'readAll failure, error code ' + e.code + 'error message ' + e.message);
    }
    return all;
  }

  public async delete(key: string) {
    try {
      this.ensureInitialized();
      if(!this.dataPreferences) return;

      await this.dataPreferences.delete(key);
      await this.dataPreferences.flush();
    } catch (e) {
      console.error(TAG, 'delete failure, error code ' + e.code + 'error message ' + e.message);
    }
  }

  public async deleteAll() {
    try {
      this.ensureInitialized();
      if(!this.dataPreferences) return;

      let raw: Object = this.dataPreferences.getAllSync();
      let rawMap = convertObjectToMap(raw);

      rawMap.forEach(async (rawVal, rawKey) => {
        const keyWithPrefix: string = rawKey;
        if (keyWithPrefix.includes(this.getKeyPrefix)) {
          this.dataPreferences?.deleteSync(rawKey);
        }
      })

      await this.dataPreferences.flush();
    } catch (e) {
      console.error(TAG, 'deleteAll failure, error code ' + e.code + 'error message ' + e.message);
    }
  }

  public containsKey(key: string): boolean {
    this.ensureInitialized();
    if (this.dataPreferences) {
      return this.dataPreferences.hasSync(key);
    } else {
      return false;
    }
  }

  private ensureInitialized() {
    if(this.dataPreferences && this.storageCipher) return;
    this.ensureOptions();
    // 创建 preferences
    let nonEncryptedPreferences: preferences.Preferences = preferences.getPreferencesSync(this.context, { name: this.SHARED_PREFERENCES_NAME});
    // 初始化 storageCipher
    if (this.storageCipher == null) {
      try {
        this.initStorageCipher(nonEncryptedPreferences);
      } catch (e) {
        console.error(TAG,"StorageCipher initialization failure", e);
      }
    }
    this.dataPreferences = nonEncryptedPreferences;
  }

  protected ensureOptions() {
    if (this.options.has("sharedPreferencesName") && this.options.get("sharedPreferencesName")) {
      this.SHARED_PREFERENCES_NAME = this.options.get("sharedPreferencesName") as string;
    }

    if (this.options.has("preferencesKeyPrefix") && this.options.get("preferencesKeyPrefix")) {
      this.setKeyPrefix = this.options.get("preferencesKeyPrefix") as string;
    }
  }

  private initStorageCipher(source: preferences.Preferences) {
    this.storageCipherFactory = new StorageCipherFactory(source, this.options);

    // 如果需要重新加密
    if (this.storageCipherFactory.requiresReEncryption()) {
      this.reEncryptPreferences(this.storageCipherFactory, source);
    } else {
      this.storageCipher = this.storageCipherFactory.getCurrentStorageCipher(this.context as Context);
    }
  }

  private async reEncryptPreferences(storageCipherFactory: StorageCipherFactory, source: preferences.Preferences) {
    try {
      this.storageCipher = storageCipherFactory.getSavedStorageCipher(this.context as Context);
      let raw: Object = await source.getAll();
      let cache: Map<string, string> = new Map();
      let rawMap = convertObjectToMap(raw);
      let promises: Promise<void>[] = [];

      rawMap.forEach(async (rawVal, rawKey) => {
        if (rawKey.includes(this.getKeyPrefix) && typeof rawVal == 'string') {
          const valuePromise = this.decodeRawValue(rawVal);
          promises.push(valuePromise.then((value: string) => {
            cache.set(rawKey, value);
          }))
        }
      })

      await Promise.all(promises);

      // 如果密钥算法更新了,应该删除密钥缓存中的key,value,重新加密后存储
      await storageCipherFactory.removeSaveAlgorithms(this.context as Context);

      this.storageCipher = storageCipherFactory.getCurrentStorageCipher(this.context as Context);
      let dataPreferencesPromises: Promise<void>[] = [];
      dataPreferencesPromises = Array.from(cache.keys()).map(async (key) => {
        if(!this.storageCipher || !this.dataPreferences) return;
        let val = cache.get(key);
        if (!val) return; // 检查缓存中是否包含该键

        try {
          let result: cryptoFramework.DataBlob | undefined = await this.storageCipher.encrypt({data: StringToUint8Array(val)});
          let resultBlob = this.base64.encodeToStringSync(result?.data);
          await this.dataPreferences.put(key, resultBlob);
        } catch (e) {
          console.error(TAG, "re-encryption after modifying the algorithm failure. code =" + e.code + ", message =" + e.message);
        }
      })

      await Promise.all(dataPreferencesPromises);
      storageCipherFactory.storeCurrentAlgorithms(this.dataPreferences as preferences.Preferences);
      await this.dataPreferences?.flush();
    } catch (e) {
      console.error(TAG, "re-encryption failure. code =" + e.code + ", message =" + e.message);
      this.storageCipher = storageCipherFactory.getSavedStorageCipher(this.context as Context);
    }
  }

  public getResetOnError(): boolean {
    return this.options.has("resetOnError") && !!this.options?.get("resetOnError");
  }

  private async decodeRawValue(value: string): Promise<string> {
    try {
      if (!value || !this.storageCipher) {
        return '';
      }
      let data = this.base64.decodeSync(value);
      let result = await this.storageCipher.decrypt({
        data
      });
      return Uint8ArrayToString(result.data);
    } catch (e) {
      console.error(TAG, "decodeRawValue failure. code =" + e.code + ", message =" + e.message);
      return '';
    }
  }
}