import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import 'recipe_suggestions_page.dart';
import 'loading_page.dart';

class FlyerUploadPage extends StatefulWidget {
  const FlyerUploadPage({super.key});

  @override
  State<FlyerUploadPage> createState() => _FlyerUploadPageState();
}

class _FlyerUploadPageState extends State<FlyerUploadPage> {
  List<XFile> _selectedImages = [];

  static const Color accentColor = Color(0xFFFF8A80);
  static const Color shadowColor = Color(0x33FF8A80);
  static const Color bgColor = Color(0xFFFFF8E7);

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
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
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
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bgColor,
        title: Text(
          'チラシ画像でメニュー作成',
          style: GoogleFonts.mPlusRounded1c(
            fontWeight: FontWeight.bold,
            color: accentColor,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 18,
                offset: const Offset(3, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "手元のスーパーのチラシ画像をアップロードすると、\n特売食材を活かした献立を提案します🍅",
                textAlign: TextAlign.center,
                style: GoogleFonts.mPlusRounded1c(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              _ImageSelectButton(
                onPressed: _pickImages,
                accentColor: accentColor,
              ),
              const SizedBox(height: 16),
              _selectedImages.isNotEmpty
                  ? Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _selectedImages
                          .map(
                            (img) => ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                img.path,
                                height: 110,
                                width: 110,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                          .toList(),
                    )
                  : Text(
                      '画像が選択されていません',
                      style: GoogleFonts.mPlusRounded1c(color: Colors.black54),
                    ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    label: '画像でメニュー生成',
                    icon: Icons.image_search,
                    accentColor: accentColor,
                    enabled: _selectedImages.isNotEmpty,
                    onTap: () {
                      if (_selectedImages.isEmpty) return;
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('メニュー生成に失敗しました', style: GoogleFonts.mPlusRounded1c()),
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 18),
                  _ActionButton(
                    label: '画像なしで生成',
                    icon: Icons.lightbulb_outline,
                    accentColor: accentColor,
                    outlined: true,
                    enabled: true,
                    onTap: () {
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
                                  SnackBar(
                                    content: Text('メニュー生成に失敗しました', style: GoogleFonts.mPlusRounded1c()),
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 柔らかい画像選択ボタン
class _ImageSelectButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color accentColor;

  const _ImageSelectButton({
    required this.onPressed,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 3,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: GoogleFonts.mPlusRounded1c(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      icon: const Icon(Icons.add_photo_alternate),
      label: const Text('画像を選択'),
      onPressed: onPressed,
    );
  }
}

/// やさしいアクションボタン
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final bool enabled;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.enabled,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = outlined
        ? OutlinedButton.styleFrom(
            side: BorderSide(color: accentColor, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            textStyle: GoogleFonts.mPlusRounded1c(fontWeight: FontWeight.bold, fontSize: 16),
            foregroundColor: accentColor,
            backgroundColor: Colors.transparent,
          )
        : ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            textStyle: GoogleFonts.mPlusRounded1c(fontWeight: FontWeight.bold, fontSize: 16),
          );

    return outlined
        ? OutlinedButton.icon(
            onPressed: enabled ? onTap : null,
            style: buttonStyle,
            icon: Icon(icon, color: accentColor),
            label: Text(label),
          )
        : ElevatedButton.icon(
            onPressed: enabled ? onTap : null,
            style: buttonStyle,
            icon: Icon(icon),
            label: Text(label),
          );
  }
}
