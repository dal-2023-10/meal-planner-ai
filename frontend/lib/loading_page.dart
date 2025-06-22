import 'package:flutter/material.dart';

class LoadingPage extends StatefulWidget {
  final Future<dynamic> Function() onProcess;
  final void Function(dynamic result) onComplete;

  const LoadingPage({
    super.key,
    required this.onProcess,
    required this.onComplete,
  });

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  void initState() {
    super.initState();
    // 非同期処理開始
    widget.onProcess().then((result) {
      widget.onComplete(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFE0F2F1), // teal[50] 風
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "調理中・・・",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
