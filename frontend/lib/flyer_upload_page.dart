import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'recipe_suggestions_page.dart';

class FlyerUploadPage extends StatefulWidget {
  const FlyerUploadPage({super.key});

  @override
  State<FlyerUploadPage> createState() => _FlyerUploadPageState();
}

class _FlyerUploadPageState extends State<FlyerUploadPage> {
  List<XFile> _images = [];

  Future<void> _pickImages() async {
    final pickedFiles = await ImagePicker().pickMultiImage(
      imageQuality: 85,
    ); // JPEG・PNG 両対応
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _images = pickedFiles;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('チラシの登録')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _pickImages,
              child: const Text('画像を選択（複数可）'),
            ),
            const SizedBox(height: 16),
            _images.isNotEmpty
                ? Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _images
                        .map(
                          (img) => kIsWeb || Platform.isIOS
                              ? Image.network(img.path, height: 100)
                              : Image.file(File(img.path), height: 100),
                        )
                        .toList(),
                  )
                : const Text('画像が選択されていません'),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _images.isEmpty
                      ? null
                      : () {
                          debugPrint('画像枚数: ${_images.length}');
                          // TODO: Cloud Storage 等へのアップロード処理
                          Navigator.pop(context);
                        },
                  child: const Text('送信'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    // 例: APIリクエスト
                    final response = await http.post(
                      Uri.parse('https://meal-planner-ai-418875428443.asia-northeast1.run.app/generate'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'prompt': 'ユーザー入力をもとに適当にpromptを組み立てて渡す（またはそのままinputDataを送るなど）',
                      }),
                    );

                    debugPrint('API status: ${response.statusCode}');
                    debugPrint('API body: ${response.body}');

                    if (response.statusCode == 200) {
                      final recipeJson = jsonDecode(response.body);

                      // 👇 ここで型も出す
                      debugPrint('runtimeType: ${recipeJson.runtimeType}');
                      debugPrint('recipeJson: $recipeJson');

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecipeDetailPage(recipe: recipeJson),
                        ),
                      );
                    } else {
                      debugPrint('API error: ${response.statusCode}, body: ${response.body}');
                      // エラー処理
                    }
                  },
                  child: const Text('登録しない'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
