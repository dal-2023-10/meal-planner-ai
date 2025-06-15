import 'package:flutter/material.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'flyer_upload_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class InputFormPage extends StatefulWidget {
  const InputFormPage({super.key});

  @override
  State<InputFormPage> createState() => _InputFormPageState();
}

class _InputFormPageState extends State<InputFormPage> {
  int selectedPeopleCount = 1;
  List<String> genders = ['男性'];
  List<String> ages = ['1〜2歳'];
  List<List<String>> selectedAllergy = [[]];
  List<List<String>> selectedPreference = [[]];

  final List<String> ageOptions = [
    '1〜2歳',
    '3〜5歳',
    '6〜7歳',
    '8〜9歳',
    '10〜11歳',
    '12〜14歳',
    '15〜17歳',
    '18〜29歳',
    '30〜49歳',
    '50〜64歳',
    '65〜74歳',
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

  final List<String> cookingTimeOptions = ['15分以内', '30分以内', '1時間以内', '1時間以上'];

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
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('献立提案入力フォーム')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '人数を選択 (1〜10)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                DropdownButton<int>(
                  value: selectedPeopleCount,
                  isExpanded: true,
                  items: List.generate(10, (index) => index + 1)
                      .map(
                        (e) => DropdownMenuItem(value: e, child: Text('$e人')),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedPeopleCount = value;
                        genders = List.generate(value, (_) => '男性');
                        ages = List.generate(value, (_) => ageOptions[0]);
                        selectedAllergy = List.generate(value, (_) => []);
                        selectedPreference = List.generate(value, (_) => []);
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                ...List.generate(
                  selectedPeopleCount,
                  (i) => _buildMemberInput(i, allergyItems, preferenceItems),
                ),
                const SizedBox(height: 16),
                _buildCookingTime(),
                const SizedBox(height: 16),
                _buildFeelingInput(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF02A764),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      '送信',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberInput(
    int i,
    List<MultiSelectItem<String>> allergyItems,
    List<MultiSelectItem<String>> preferenceItems,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'メンバー ${i + 1}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text('性別', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          value: genders[i],
          items: [
            '男性',
            '女性',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (value) => setState(() => genders[i] = value!),
        ),
        const Text('年齢', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          value: ages[i],
          items: ageOptions
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (value) => setState(() => ages[i] = value!),
        ),
        const Text('アレルギー', style: TextStyle(fontWeight: FontWeight.bold)),
        MultiSelectDialogField<String>(
          items: allergyItems,
          initialValue: selectedAllergy[i],
          title: const Text("アレルギー"),
          buttonText: const Text("アレルギーを選択"),
          onConfirm: (values) => setState(() => selectedAllergy[i] = values),
        ),
        const Text('趣向・宗教', style: TextStyle(fontWeight: FontWeight.bold)),
        MultiSelectDialogField<String>(
          items: preferenceItems,
          initialValue: selectedPreference[i],
          title: const Text("趣向・宗教"),
          buttonText: const Text("趣向・宗教を選択"),
          onConfirm: (values) => setState(() => selectedPreference[i] = values),
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildCookingTime() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('料理時間', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          value: selectedCookingTime,
          isExpanded: true,
          items: cookingTimeOptions
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (value) => setState(() => selectedCookingTime = value!),
        ),
      ],
    );
  }

  Widget _buildFeelingInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今日の気分（50文字以内）',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        TextField(
          maxLength: 50,
          decoration: const InputDecoration(hintText: 'お肉の気分'),
          onChanged: (value) => todayFeeling = value,
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    final data = {
      // 'selectedPeopleCount': selectedPeopleCount,
      'genders': genders,
      'ages': ages,
      // 'selectedAllergy': selectedAllergy,
      'preferences': selectedPreference,
      // 'selectedCookingTime': selectedCookingTime,
      // 'todayFeeling': todayFeeling,
    };

    try {
      final response = await http.post(
        Uri.parse(
          'https://submit-demo-418875428443.us-central1.run.app/submit',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FlyerUploadPage()),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('送信失敗: ${response.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('通信エラーが発生しました')));
    }
  }
}
