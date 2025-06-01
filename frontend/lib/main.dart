import 'package:flutter/material.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show File, Platform;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

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

class InputFormPage extends StatefulWidget {
  const InputFormPage({super.key});

  @override
  State<InputFormPage> createState() => _InputFormPageState();
}

class _InputFormPageState extends State<InputFormPage> {
  int selectedPeopleCount = 1;
  List<String> genders = ['男性'];
  List<String> ages = ['1~2歳'];
  List<List<String>> selectedAllergy = [[]];
  List<List<String>> selectedPreference = [[]];

  final List<String> ageOptions = [
    '1~2歳',
    '3~5歳',
    '6~7歳',
    '8~9歳',
    '10~11歳',
    '12~14歳',
    '15~17歳',
    '18~29歳',
    '30~49歳',
    '50~64歳',
    '65~74歳',
    '75歳以上',
  ];

  final List<String> allergyOptions = [
    '卵',
    '乳製品',
    '小麦',
    'そば',
    '落花生',
    'えび',
    'かに',
    'あわび',
    'いか',
    'いくら',
    'オレンジ',
    'キウイ',
    '牛肉',
    'くるみ',
    'さけ',
    'さば',
    '大豆',
    '鶏肉',
    'バナナ',
    'まつたけ',
    'もも',
    'やまいも',
    'りんご',
    'ゼラチン',
    'ごま',
    'カシューナッツ',
    'アーモンド',
  ];

  final List<String> preferenceOptions = [
    'ベジタリアン',
    'グルテンフリー',
    'ヴィーガン',
    'イスラム教',
    'ヒンドゥー教',
  ];

  String selectedCookingTime = '30分以内';
  String todayFeeling = '';

  @override
  Widget build(BuildContext context) {
    final allergyItems = allergyOptions
        .map((e) => MultiSelectItem(e, e))
        .toList();
    final preferenceItems = preferenceOptions
        .map((e) => MultiSelectItem(e, e))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('献立提案入力フォーム')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '人数を選択（1〜10）',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButton<int>(
                value: selectedPeopleCount,
                items: List.generate(10, (index) => index + 1)
                    .map((e) => DropdownMenuItem(value: e, child: Text('$e人')))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedPeopleCount = value!;
                    genders = List.generate(value, (_) => '男性');
                    ages = List.generate(value, (_) => ageOptions[0]);
                    selectedAllergy = List.generate(value, (_) => []);
                    selectedPreference = List.generate(value, (_) => []);
                  });
                },
              ),
              const SizedBox(height: 16),
              for (int i = 0; i < selectedPeopleCount; i++)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'メンバー ${i + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      '性別',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value: genders[i],
                      items: ['男性', '女性']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => genders[i] = value!);
                      },
                    ),
                    const Text(
                      '年齢',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value: ages[i],
                      items: ageOptions
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => ages[i] = value!);
                      },
                    ),
                    const Text(
                      'アレルギー',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    MultiSelectDialogField<String>(
                      items: allergyItems,
                      initialValue: selectedAllergy[i],
                      onConfirm: (values) {
                        setState(() {
                          selectedAllergy[i] = values;
                        });
                      },
                      title: const Text("アレルギー"),
                      buttonText: const Text("アレルギーを選択"),
                    ),
                    const Text(
                      '趣向・宗教',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    MultiSelectDialogField<String>(
                      items: preferenceItems,
                      initialValue: selectedPreference[i],
                      onConfirm: (values) {
                        setState(() {
                          selectedPreference[i] = values;
                        });
                      },
                      title: const Text("趣向・宗教"),
                      buttonText: const Text("趣向・宗教を選択"),
                    ),
                    const Divider(),
                  ],
                ),
              const Text('料理時間', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: selectedCookingTime,
                items: ['15分以内', '30分以内', '1時間以内', '1時間以上']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedCookingTime = value!);
                },
              ),
              const SizedBox(height: 16),
              const Text(
                '今日の気分（50文字以内）',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextField(
                maxLength: 50,
                decoration: const InputDecoration(hintText: 'お肉の気分'),
                onChanged: (value) => todayFeeling = value,
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    debugPrint('人数: $selectedPeopleCount');
                    debugPrint('性別: $genders');
                    debugPrint('年齢: $ages');
                    debugPrint('アレルギー: $selectedAllergy');
                    debugPrint('趣向・宗教: $selectedPreference');
                    debugPrint('料理時間: $selectedCookingTime');
                    debugPrint('今日の気分: $todayFeeling');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FlyerUploadPage(),
                      ),
                    );
                  },
                  child: const Text('送信'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
