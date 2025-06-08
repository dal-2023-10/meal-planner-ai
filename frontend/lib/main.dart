import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'input_form_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '献立提案',
      theme: ThemeData(
        textTheme: GoogleFonts.notoSansJpTextTheme(),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const InputFormPage(),
    );
  }
}
