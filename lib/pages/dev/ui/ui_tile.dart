import 'package:bugaoshan/pages/dev/ui/ui_page.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';

class UiTile extends StatelessWidget {
  const UiTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.category_outlined),
      title: Text("UI Preview"),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => popupOrNavigate(context, const UiPage()),
    );
  }
}
