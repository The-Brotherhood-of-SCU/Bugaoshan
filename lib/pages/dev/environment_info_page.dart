import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/version_info.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';

class EnvironmentInfoPage extends StatefulWidget {
  const EnvironmentInfoPage({super.key});

  @override
  State<EnvironmentInfoPage> createState() => _EnvironmentInfoPageState();
}

class _EnvironmentInfoPageState extends State<EnvironmentInfoPage> {
  final _provider = getIt<AppInfoProvider>();
  late Future<VersionInfo> _future;
  late Future<Map<String, dynamic>> _deviceInfoFuture;
  VersionInfo? _info;

  @override
  void initState() {
    super.initState();
    _future = _provider.getVersionInfo().then((v) => _info = v);
    _deviceInfoFuture = _getDeviceInfo();
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return {
        'brand': androidInfo.brand,
        'model': androidInfo.model,
        'device': androidInfo.device,
        'manufacturer': androidInfo.manufacturer,
        'supported32BitAbis': androidInfo.supported32BitAbis.join(', '),
        'supported64BitAbis': androidInfo.supported64BitAbis.join(', '),
        'supportedAbis': androidInfo.supportedAbis.join(', '),
        'isPhysicalDevice': androidInfo.isPhysicalDevice.toString(),
      };
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return {
        'name': iosInfo.name,
        'model': iosInfo.model,
        'localizedModel': iosInfo.localizedModel,
        'systemName': iosInfo.systemName,
        'systemVersion': iosInfo.systemVersion,
        'isPhysicalDevice': iosInfo.isPhysicalDevice.toString(),
      };
    }
    return {};
  }

  void _copyAll() {
    final info = _info;
    if (info == null) return;
    Clipboard.setData(ClipboardData(text: info.toString()));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Environment Info'),
        actions: [
          IconButton(icon: const Icon(Icons.copy), onPressed: _copyAll),
        ],
      ),
      body: FutureBuilder<VersionInfo>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final info = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(title: 'APP', content: info.app),
              _SectionCard(title: 'Environment', content: info.environment),
              _SectionCard(title: 'Flag', content: info.flag),
              _SectionCard(title: 'Build', content: info.build),
              FutureBuilder<Map<String, dynamic>>(
                future: _deviceInfoFuture,
                builder: (context, deviceSnapshot) {
                  if (deviceSnapshot.connectionState != ConnectionState.done) {
                    return const Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  final deviceInfo = deviceSnapshot.data ?? {};
                  if (deviceInfo.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final content = deviceInfo.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('\n');
                  return _SectionCard(title: 'Device', content: content);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String content;

  const _SectionCard({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            SelectableText(
              content,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}
