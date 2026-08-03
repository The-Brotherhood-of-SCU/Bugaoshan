import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/common/third_center.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/pages/profile/login_status_card.dart';
import 'package:bugaoshan/pages/profile/profile_menu_card.dart';
import 'package:bugaoshan/pages/profile/user_info_card.dart';

final _appConfig = getIt<AppConfigProvider>();

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        const LoginStatusCard(),
        AnimatedSize(
          duration: _appConfig.cardSizeAnimationDuration.value,
          curve: appCurve,
          child: const UserInfoCard(),
        ),
        const ProfileMenuCard(),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: ThirdCenter(child: body),
          ),
        );
      },
    );
  }
}
