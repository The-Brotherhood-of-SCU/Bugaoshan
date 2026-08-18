# flutter_secure_storage_ohos

A Flutter plugin to store data in secure storage:

- AES encryption is used for Ohos. AES secret key is encrypted with RSA and RSA key is stored in preferences.   
  By default following algorithms are used for AES and secret key encryption: AES/CBC/PKCS7Padding and RSA/ECB/PKCS1Padding  
  You can also use other recommendation algorithms:  
  AES/GCM/NoPadding and RSA/ECB/OAEPWithSHA-256AndMGF1Padding  
  You can set them in Ohos options like so:
```dart
  OhosOptions _getOhosOptions() => const OhosOptions(
          ohosKeyCipherAlgorithm: OhosKeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
          ohosStorageCipherAlgorithm: OhosStorageCipherAlgorithm.AES_GCM_NoPadding,
      );
```

## Usage

```pod
dependencies:
    flutter_secure_storage_ohos: ^1.0.0
```

### Example

```dart
import 'package:flutter_secure_storage_ohos/flutter_secure_storage_ohos.dart';

// Create storage
final storage = new FlutterSecureStorage();

// Read value
String value = await storage.read(key: key);

// Read all values
Map<String, String> allValues = await storage.readAll();

// Delete value
await storage.delete(key: key);

// Delete all
await storage.deleteAll();

// Write value
await storage.write(key: key, value: value);

```
