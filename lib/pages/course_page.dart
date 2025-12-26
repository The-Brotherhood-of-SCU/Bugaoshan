import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rubbish_plan/widgets/common/text.dart';

class CoursePage extends StatefulWidget {
  const CoursePage({super.key});

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  @override
  Widget build(BuildContext context) {
    String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Column(
      children: [
        Row(
          spacing: 8,
          children: [
            SizedBox(width: 8),
            TitleText(date),
            SizedBox(width: 8),
            Expanded(child: Container()),
            IconButton(onPressed: () {}, icon: Icon(Icons.add)),
            IconButton(onPressed: () {}, icon: Icon(Icons.download)),
            IconButton(onPressed: () {}, icon: Icon(Icons.send)),
          ],
        ),
        SizedBox(height: 8),
        Expanded(child: Placeholder()),
      ],
    );
  }
}
