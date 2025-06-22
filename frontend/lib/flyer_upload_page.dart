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

  /// 画像あり: チラシ情報アリAPI
  Future<Map<String, dynamic>?> _fetchRecipeWithFlyer(List<String> flyerUrls) async {
    try {
      final response = await http.post(
        Uri.parse('https://flyer-menu-generate-418875428443.asia-northeast1.run.app/generate_menu_from_flyer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'flyer_urls': flyerUrls}),
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

  /// 画像なし: デモグラだけAPI
  Future<Map<String, dynamic>?> _fetchRecipeWithoutFlyer() async {
    try {
      final response = await http.post(
        Uri.parse('https://non-flyer-menu-generate-418875428443.asia-northeast1.run.app/generate_with_image'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': '（ここに適宜フォームの内容など渡す）'}),
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
                // チラシ画像アリ: アップロードしてAPI
                ElevatedButton(
                  onPressed: _selectedImages.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LoadingPage(
                                onProcess: () async {
                                  final urls = await _uploadImagesToFirebase(_selectedImages);
                                  return await _fetchRecipeWithFlyer(urls);
                                },
                                onComplete: (recipeJson) {
                                  if (recipeJson != null) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RecipeDetailPage(recipe: recipeJson),
                                      ),
                                    );
                                  } else {
                                    // エラー時の表示（任意で改良）
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('メニュー生成に失敗しました')),
                                    );
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                  child: const Text('画像でメニュー生成'),
                ),
                // チラシ登録しない: デモグラのみAPI
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoadingPage(
                          onProcess: () async => await _fetchRecipeWithoutFlyer(),
                          onComplete: (recipeJson) {
                            if (recipeJson != null) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RecipeDetailPage(recipe: recipeJson),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('メニュー生成に失敗しました')),
                              );
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('画像なしで生成'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
