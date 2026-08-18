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

import { preferences } from '@kit.ArkData';

import KeyCipher from './KeyCipher';
import RSACipher18Implementation from './RSACipher18Implementation';
import RSACipherOAEPImplementation from './RSACipherOAEPImplementation';
import StorageCipher18Implementation from './StorageCipher18Implementation';
import StorageCipherGCMImplementation from './StorageCipherGCMImplementation';

export enum OhosKeyCipherAlgorithm {
  RSA_ECB_PKCS1Padding = "RSA_ECB_PKCS1Padding",
  RSA_ECB_OAEPwithSHA_256andMGF1Padding = "RSA_ECB_OAEPwithSHA_256andMGF1Padding"
}

export type KeyCipherFunction = (context: Context) => RSACipher18Implementation;

export class KeyCipherAlgorithmInfo {
  public keyCipher: KeyCipherFunction | null = null;
  public minVersionCode: number | null = null;
  public name: string = '';

  constructor(keyCipher: KeyCipherFunction, minVersionCode: number, name: string) {
    this.keyCipher = keyCipher;
    this.minVersionCode = minVersionCode;
    this.name = name;
  }

  static keyCipherAlgorithms: Record<OhosKeyCipherAlgorithm, KeyCipherAlgorithmInfo> = {
    [OhosKeyCipherAlgorithm.RSA_ECB_PKCS1Padding]: new KeyCipherAlgorithmInfo(
      (context: Context) => new RSACipher18Implementation(context),
      1,
      OhosKeyCipherAlgorithm.RSA_ECB_PKCS1Padding
    ),
    [OhosKeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding]: new KeyCipherAlgorithmInfo(
      (context: Context) => new RSACipherOAEPImplementation(context),
      1,
      OhosKeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding
    )
  };
}

export enum OhosStorageCipherAlgorithm {
  AES_CBC_PKCS7Padding = "AES_CBC_PKCS7Padding",
  AES_GCM_NoPadding = "AES_GCM_NoPadding"
}

export type StorageCipherFunction = (context: Context, keyCipher: KeyCipher) => StorageCipher18Implementation;

export class StorageCipherAlgorithmInfo {
  public storageCipher: StorageCipherFunction | null = null;
  public minVersionCode: number | null = null;
  public name: string = '';

  constructor(storageCipher: StorageCipherFunction, minVersionCode: number, name: string) {
    this.storageCipher = storageCipher;
    this.minVersionCode = minVersionCode;
    this.name = name;
  }

  static storageCipherAlgorithms: Record<OhosStorageCipherAlgorithm, StorageCipherAlgorithmInfo> = {
    [OhosStorageCipherAlgorithm.AES_CBC_PKCS7Padding]: new StorageCipherAlgorithmInfo(
      (context: Context, rsaCipher: KeyCipher) => new StorageCipher18Implementation(context, rsaCipher),
      1,
      OhosStorageCipherAlgorithm.AES_CBC_PKCS7Padding
    ),
    [OhosStorageCipherAlgorithm.AES_GCM_NoPadding]: new StorageCipherAlgorithmInfo(
      (context: Context, rsaCipher: KeyCipher) => new StorageCipherGCMImplementation(context, rsaCipher),
      1,
      OhosStorageCipherAlgorithm.AES_GCM_NoPadding
    )
  };
}

const TAG: string = 'SecureStorage::StorageCipherFactory';

export class StorageCipherFactory {
  private ELEMENT_PREFERENCES_ALGORITHM_PREFIX: string = "FlutterSecureSAlgorithm";
  private ELEMENT_PREFERENCES_ALGORITHM_KEY: string = this.ELEMENT_PREFERENCES_ALGORITHM_PREFIX + "Key";
  private ELEMENT_PREFERENCES_ALGORITHM_STORAGE: string = this.ELEMENT_PREFERENCES_ALGORITHM_PREFIX + "Storage";
  private DEFAULT_KEY_ALGORITHM: OhosKeyCipherAlgorithm = OhosKeyCipherAlgorithm.RSA_ECB_PKCS1Padding;
  private DEFAULT_STORAGE_ALGORITHM: OhosStorageCipherAlgorithm = OhosStorageCipherAlgorithm.AES_CBC_PKCS7Padding;

  private savedKeyAlgorithm: KeyCipherAlgorithmInfo | null = null;
  private currentKeyAlgorithm: KeyCipherAlgorithmInfo | null = null;
  private savedStorageAlgorithm: StorageCipherAlgorithmInfo | null = null;
  private currentStorageAlgorithm: StorageCipherAlgorithmInfo | null = null;

  constructor(source: preferences.Preferences , options: Map<String, Object>) {
    let algorithmKey: preferences.ValueType = source.getSync(this.ELEMENT_PREFERENCES_ALGORITHM_KEY, this.DEFAULT_KEY_ALGORITHM);
    this.savedKeyAlgorithm = KeyCipherAlgorithmInfo.keyCipherAlgorithms[algorithmKey as OhosKeyCipherAlgorithm];

    let storageAlgorithmKey: preferences.ValueType = source.getSync(this.ELEMENT_PREFERENCES_ALGORITHM_STORAGE, this.DEFAULT_STORAGE_ALGORITHM);
    this.savedStorageAlgorithm = StorageCipherAlgorithmInfo.storageCipherAlgorithms[storageAlgorithmKey as OhosStorageCipherAlgorithm];

    let currAlgorithmKey: preferences.ValueType = this.getFromOptionsWithDefault(options, "ohosKeyCipherAlgorithm", this.DEFAULT_KEY_ALGORITHM);
    this.currentKeyAlgorithm = KeyCipherAlgorithmInfo.keyCipherAlgorithms[currAlgorithmKey as OhosKeyCipherAlgorithm];

    let currStorageAlgorithmKey: preferences.ValueType = this.getFromOptionsWithDefault(options, "ohosStorageCipherAlgorithm", this.DEFAULT_STORAGE_ALGORITHM);
    this.currentStorageAlgorithm = StorageCipherAlgorithmInfo.storageCipherAlgorithms[currStorageAlgorithmKey as OhosStorageCipherAlgorithm];
  }

  private getFromOptionsWithDefault(options: Map<String, Object>, key: string, defaultValue: string): string {
    const value: Object | undefined = options.get(key);
    return value ? value.toString() : defaultValue;
  }

  requiresReEncryption(): boolean {
    return this.savedKeyAlgorithm != this.currentKeyAlgorithm || this.savedStorageAlgorithm != this.currentStorageAlgorithm;
  }

  getSavedStorageCipher(context: Context): StorageCipher18Implementation | null {
    if(this.savedKeyAlgorithm?.keyCipher && this.savedStorageAlgorithm?.storageCipher) {
      let keyCipher: RSACipher18Implementation = this.savedKeyAlgorithm.keyCipher(context);
      let cipher: StorageCipher18Implementation = this.savedStorageAlgorithm.storageCipher(context, keyCipher);
      return cipher;
    } else {
      console.error(TAG, " getSavedStorageCipher failure.");
      return null;
    }
  }

  getCurrentStorageCipher(context: Context): StorageCipher18Implementation | null {
    if(this.currentKeyAlgorithm?.keyCipher && this.currentStorageAlgorithm?.storageCipher) {
      let keyCipher: RSACipher18Implementation = this.currentKeyAlgorithm?.keyCipher(context);
      let cipher: StorageCipher18Implementation = this.currentStorageAlgorithm.storageCipher(context, keyCipher);
      return cipher;
    } else {
      console.error(TAG, " getCurrentStorageCipher failure.");
      return null;
    }
  }

  storeCurrentAlgorithms(preferences: preferences.Preferences) {
    preferences.putSync(this.ELEMENT_PREFERENCES_ALGORITHM_KEY, this.currentKeyAlgorithm?.name);
    preferences.putSync(this.ELEMENT_PREFERENCES_ALGORITHM_STORAGE, this.currentStorageAlgorithm?.name);
  }

  async removeSaveAlgorithms(context: Context) {
    if(this.savedKeyAlgorithm?.keyCipher && this.savedStorageAlgorithm?.storageCipher) {
      let keyCipher: RSACipher18Implementation = this.savedKeyAlgorithm?.keyCipher(context);
      let cipher: StorageCipher18Implementation = this.savedStorageAlgorithm.storageCipher(context, keyCipher);
      await keyCipher.removePreferencesKey();
      await cipher.removePreferencesKey();
    }
  }
}