import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const Color bgColor = Color(0xFFFFF8E7); // クリーム色
  static const Color accentColor = Color(0xFFFF8A80); // コーラルピンク

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
    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.18),
                blurRadius: 22,
                offset: const Offset(2, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "🍳",
                style: TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 14),
              Text(
                "献立を考えています…",
                style: GoogleFonts.mPlusRounded1c(
                  fontSize: 22,
                  color: accentColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  shadows: [
                    Shadow(
                      color: accentColor.withOpacity(0.13),
                      blurRadius: 5,
                      offset: const Offset(1, 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                width: 52,
                child: CircularProgressIndicator(
                  strokeWidth: 6,
                  color: accentColor,
                  backgroundColor: accentColor.withOpacity(0.1),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "栄養バランスなどをチェック中…\nしばらくお待ちください",
                textAlign: TextAlign.center,
                style: GoogleFonts.mPlusRounded1c(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
