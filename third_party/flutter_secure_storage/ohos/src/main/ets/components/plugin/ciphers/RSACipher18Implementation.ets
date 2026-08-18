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
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

import KeyCipher from './KeyCipher';

const TAG = 'SecureStorage::RSACipher18Implementation';

export default class RSACipher18Implementation implements KeyCipher {
  private SECRET_RSA_KEY_PREFERENCES_NAME: string = 'FlutterSecureRSAKeyStorage';
  private TYPE_RSA: string = "RSA2048";
  protected context: Context | null = null;
  protected cipher: cryptoFramework.Cipher | null = null;
  base64: util.Base64Helper = new util.Base64Helper();
  preferences: preferences.Preferences | null = null;

  constructor(context: Context) {
    this.context = context;
    this.preferences = this.getPreferences();
  }

  async RSAEncrypt(key: cryptoFramework.Key): Promise<Uint8Array> {
    this.createRSAKeysIfNeeded();

    let data: Uint8Array = key.getEncoded().data;
    let publicKey = this.getPublicKey();

    let cipher: cryptoFramework.Cipher = this.getRSACipher();
    cipher.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, publicKey, null);
    const finalRes = cipher.doFinalSync({
      data
    });
    return finalRes.data;
  }

  async RSADecrypt(wrappedKey: Uint8Array, algorithm: string): Promise<cryptoFramework.Key> {
    this.createRSAKeysIfNeeded();
    let privateKey = this.getPrivateKey();

    let cipher: cryptoFramework.Cipher = this.getRSACipher();
    cipher.initSync(cryptoFramework.CryptoMode.DECRYPT_MODE, privateKey, null);
    const finalRes = cipher.doFinalSync({
      data: wrappedKey
    });
    let res: cryptoFramework.Key = this.getKey(finalRes, algorithm);
    return res;
  }

  // 把 DataBlob 转为 Key
  protected getKey(keyBlob: cryptoFramework.DataBlob, algorithm: string): cryptoFramework.Key {
    let symKeyGenerator = cryptoFramework.createSymKeyGenerator(algorithm);
    let symKey: cryptoFramework.Key = symKeyGenerator.convertKeySync(keyBlob);
    return symKey;
  }

  protected getRSACipher() {
    return cryptoFramework.createCipher('RSA2048|PKCS1');
  }

  protected async createRSAKeysIfNeeded() {
    if(!this.preferences) {
      this.preferences = this.getPreferences();
    };
    let rsaPreferencesPubKey: string = this.getRSAPreferencesPubKey();
    let rsaPreferencesPriKey: string = this.getRSAPreferencesPriKey();

    let pubKey = this.preferences.getSync(rsaPreferencesPubKey, null);
    let priKey = this.preferences.getSync(rsaPreferencesPriKey, null);
    if(pubKey && priKey) return;

    let keyPair = this.getAsyKey();
    if(keyPair) {
      let valuePub: string = this.base64.encodeToStringSync(keyPair.pubKey.getEncoded().data);
      let valuePri: string = this.base64.encodeToStringSync(keyPair.priKey.getEncoded().data);
      
      this.preferences.putSync(rsaPreferencesPubKey, valuePub);
      this.preferences.putSync(rsaPreferencesPriKey, valuePri);
      await this.preferences.flush();
    } else {
      console.error(TAG, 'createRSAKey failure .')
    }
  }

  protected getPublicKey(): cryptoFramework.PubKey | undefined {
    if(!this.preferences) {
      this.preferences = this.getPreferences();
    };
    let pubKey: cryptoFramework.PubKey | undefined = undefined;

    let rsaPreferencesPubKey: string = this.getRSAPreferencesPubKey();

    let value = this.preferences?.getSync(rsaPreferencesPubKey, null);
    let encrypted: Uint8Array = this.base64.decodeSync(value as string);
    let rsaGenerator = cryptoFramework.createAsyKeyGenerator(this.TYPE_RSA);
    let keyPair: cryptoFramework.KeyPair = rsaGenerator.convertKeySync({ data: encrypted }, null);
    pubKey = keyPair.pubKey;

    return pubKey;
  }

  protected getPrivateKey(): cryptoFramework.PriKey | undefined {
    if(!this.preferences) {
      this.preferences = this.getPreferences();
    };
    let priKey: cryptoFramework.PriKey | undefined = undefined;

    let rsaPreferencesPriKey: string = this.getRSAPreferencesPriKey();
    let value = this.preferences?.getSync(rsaPreferencesPriKey, null);
    let encrypted: Uint8Array = this.base64.decodeSync(value as string);
    let rsaGenerator = cryptoFramework.createAsyKeyGenerator(this.TYPE_RSA);
    let keyPair: cryptoFramework.KeyPair = rsaGenerator.convertKeySync(null, { data: encrypted });
    priKey = keyPair.priKey;

    return priKey;
  }

  getPreferences() {
    return preferences.getPreferencesSync(this.context, { name: this.SECRET_RSA_KEY_PREFERENCES_NAME });
  }

  protected getRSAPreferencesPubKey(): string {
    return "e8cM5mqNRf85XYNjoJiFAj7B9ZBU1co7nsz1Wt3R0wV7ovlwcpkzCRq";
  }

  protected getRSAPreferencesPriKey(): string {
    return "Mcem8fwdn4IhqqCmHCc+5vnRjoWlYvTSGNl1/5UN2hLo5uJdb60A4Eo+P8J8pvAfG9ibI2pUeazCaPjk0Dg7r1FI4jv8tF4bgQqKOe7h0BKfN";
  }

  async removePreferencesKey() {
    if(this.preferences) {
      const pubPreferenceKey = this.getRSAPreferencesPubKey();
      const priPreferenceKey = this.getRSAPreferencesPriKey();
      const pubKey = this.preferences.getSync(pubPreferenceKey, null);
      const priKey = this.preferences.getSync(priPreferenceKey, null);
      if(pubKey && priKey) {
        this.preferences.deleteSync(pubPreferenceKey);
        this.preferences.deleteSync(priPreferenceKey);
        await this.preferences.flush();
      };
    }
  }

  private getAsyKey(): cryptoFramework.KeyPair | undefined {
    try {
      let keyPair: cryptoFramework.KeyPair;
      let asyKeyGenerator = cryptoFramework.createAsyKeyGenerator(this.TYPE_RSA);
      keyPair = asyKeyGenerator.generateKeyPairSync();
      return keyPair;
    } catch (e) {
      console.error(TAG, `getPublicKey sync error, ${e.code}, ${e.message}`);
      return undefined;
    }
  }
}