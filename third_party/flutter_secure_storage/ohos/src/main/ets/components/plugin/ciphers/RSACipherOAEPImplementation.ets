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

import RSACipher18Implementation from './RSACipher18Implementation';

const TAG = 'SecureStorage::RSACipherOAEPImplementation';

export default class RSACipherOAEPImplementation extends RSACipher18Implementation {

  constructor(context: Context) {
    super(context);
  }

  protected override getRSACipher(): cryptoFramework.Cipher {
    return cryptoFramework.createCipher('RSA2048|PKCS1_OAEP|SHA256|MGF1_SHA1');
  }

  override async RSAEncrypt(key: cryptoFramework.Key): Promise<Uint8Array> {
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

  override async RSADecrypt(wrappedKey: Uint8Array, algorithm: string): Promise<cryptoFramework.Key> {
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
}