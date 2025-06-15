import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'recipe_suggestions_page.dart';
import 'loading_page.dart';

class FlyerUploadPage extends StatefulWidget {
  const FlyerUploadPage({super.key});

  @override
  State<FlyerUploadPage> createState() => _FlyerUploadPageState();
}

class _FlyerUploadPageState extends State<FlyerUploadPage> {
  List<XFile> _selectedImages = [];

  /// 画像を複数選択する
  Future<void> _pickImages() async {
    final pickedFiles = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages = pickedFiles;
      });
    }
  }

  /// Firebase Storage に画像をアップロードし、URLのリストを返す
  Future<List<String>> _uploadImagesToFirebase(List<XFile> images) async {
    final storage = FirebaseStorage.instance;
    List<String> downloadUrls = [];

    for (final image in images) {
      final fileName = '${DateTime.now()}.jpg';
      final ref = storage.ref().child('flyers/$fileName');

      try {
        debugPrint('アップロード中: ${image.name}');

        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          final uploadTask = await ref.putData(
            bytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          final url = await uploadTask.ref.getDownloadURL();
          downloadUrls.add(url);
          debugPrint('アップロード成功: $url');
        }
      } on FirebaseException catch (e) {
        debugPrint('Firebaseエラー: ${e.code} - ${e.message}');
      } catch (e) {
        debugPrint('その他のエラー: $e');
      }
    }

    return downloadUrls;
  }

  /// Cloud Run API からレシピを生成
  Future<Map<String, dynamic>?> _fetchRecipeSuggestions() async {
    try {
      final response = await http.post(
        // Uri.parse('https://meal-planner-ai-418875428443.asia-northeast1.run.app/generate'),
        Uri.parse('https://menu-image-generate-418875428443.asia-northeast1.run.app/generate_with_image'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': 'ユーザー入力をもとに適当にpromptを組み立てて渡す（またはそのままinputDataを送るなど）',
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('API成功: ${response.body}');
        return jsonDecode(response.body);
      } else {
        debugPrint('APIエラー: ${response.statusCode}, ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('通信エラー: $e');
      return null;
    }
  }

  /// アップロード後に遷移
  Future<void> _handleUploadAndNavigate() async {
    debugPrint('選択された画像枚数: ${_selectedImages.length}');

    final urls = await _uploadImagesToFirebase(_selectedImages);
    debugPrint('アップロードされたURL: $urls');

    final recipeJson = await _fetchRecipeSuggestions();

    if (recipeJson != null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailPage(recipe: recipeJson),
          ),
        );
      }
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
            _selectedImages.isNotEmpty
                ? Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _selectedImages
                        .map((img) => Image.network(img.path, height: 100))
                        .toList(),
                  )
                : const Text('画像が選択されていません'),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _selectedImages.isEmpty
                      ? null
                      : () => _handleUploadAndNavigate(),
                  child: const Text('送信'),
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoadingPage(
                          onProcess: () async {
                            return await _fetchRecipeSuggestions();
                          },
                          onComplete: (recipeJson) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecipeDetailPage(recipe: recipeJson),
                              ),
                            );
                          },
                        ),
                      ),
                    );
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
