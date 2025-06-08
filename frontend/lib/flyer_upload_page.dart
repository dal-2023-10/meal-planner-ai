import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
                  onPressed: () => Navigator.pop(context),
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
