import 'package:flutter/material.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'flyer_upload_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

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
    '1〜2歳','3〜5歳','6〜7歳','8〜9歳','10〜11歳','12〜14歳',
    '15〜17歳','18〜29歳','30〜49歳','50〜64歳','65〜74歳','75歳以上',
  ];

  final List<String> allergyOptions = [
    '卵','乳製品','小麦','そば','落花生','えび','かに','あわび','いか','いくら','オレンジ','キウイ','牛肉','くるみ','さけ','さば','大豆','鶏肉','バナナ','まつたけ','もも','やまいも','りんご','ゼラチン','ごま','カシューナッツ','アーモンド',
  ];

  final List<String> preferenceOptions = [
    'ベジタリアン','グルテンフリー','ヴィーガン','イスラム教','ヒンドゥー教',
  ];

  final List<String> cookingTimeOptions = ['15分以内','30分以内','1時間以内','1時間以上'];

  String selectedCookingTime = '30分以内';
  String todayFeeling = '';

  // ここで色やフォントなどを統一定義
  static const Color accentColor = Color(0xFFFF8A80); // コーラルピンク
  static const Color shadowColor = Color(0x33FF8A80);
  static const Color bgColor = Color(0xFFFFF8E7); // クリーム色背景

  @override
  Widget build(BuildContext context) {
    final allergyItems = allergyOptions.map((e) => MultiSelectItem(e, e)).toList();
    final preferenceItems = preferenceOptions.map((e) => MultiSelectItem(e, e)).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bgColor,
        title: Text(
          'おなかプランナー',
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
          constraints: const BoxConstraints(maxWidth: 600),
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 20,
                offset: const Offset(4, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('人数を選択 (1〜10)'),
                DropdownButton<int>(
                  value: selectedPeopleCount,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  style: GoogleFonts.mPlusRounded1c(fontSize: 16, color: Colors.black87),
                  iconEnabledColor: accentColor,
                  items: List.generate(10, (index) => index + 1)
                      .map((e) => DropdownMenuItem(value: e, child: Text('$e人')))
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
                const SizedBox(height: 18),
                ...List.generate(
                  selectedPeopleCount,
                  (i) => _buildMemberInput(i, allergyItems, preferenceItems),
                ),
                const SizedBox(height: 18),
                _sectionTitle('料理時間'),
                _buildCookingTime(),
                const SizedBox(height: 18),
                _sectionTitle('今日の気分（50文字以内）'),
                _buildFeelingInput(),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitForm,
                    icon: const Icon(Icons.restaurant, color: Colors.white),
                    label: Text(
                      'メニューをつくる',
                      style: GoogleFonts.mPlusRounded1c(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      shadowColor: shadowColor,
                      elevation: 4,
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

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          title,
          style: GoogleFonts.mPlusRounded1c(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: accentColor,
            letterSpacing: 1.1,
          ),
        ),
      );

  Widget _buildMemberInput(
    int i,
    List<MultiSelectItem<String>> allergyItems,
    List<MultiSelectItem<String>> preferenceItems,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'メンバー ${i + 1}',
            style: GoogleFonts.mPlusRounded1c(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('性別：', style: GoogleFonts.mPlusRounded1c(fontWeight: FontWeight.w600)),
              DropdownButton<String>(
                value: genders[i],
                items: ['男性', '女性']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) => setState(() => genders[i] = value!),
                dropdownColor: Colors.white,
                style: GoogleFonts.mPlusRounded1c(),
                iconEnabledColor: accentColor,
              ),
            ],
          ),
          Row(
            children: [
              Text('年齢：', style: GoogleFonts.mPlusRounded1c(fontWeight: FontWeight.w600)),
              DropdownButton<String>(
                value: ages[i],
                items: ageOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) => setState(() => ages[i] = value!),
                dropdownColor: Colors.white,
                style: GoogleFonts.mPlusRounded1c(),
                iconEnabledColor: accentColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('アレルギー', style: GoogleFonts.mPlusRounded1c(fontWeight: FontWeight.w600)),
          MultiSelectDialogField<String>(
            items: allergyItems,
            initialValue: selectedAllergy[i],
            title: const Text("アレルギー"),
            buttonText: Text("アレルギーを選択", style: GoogleFonts.mPlusRounded1c()),
            chipDisplay: MultiSelectChipDisplay.none(),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withOpacity(0.3)),
            ),
            onConfirm: (values) => setState(() => selectedAllergy[i] = values),
          ),
          const SizedBox(height: 4),
          Text('趣向・宗教', style: GoogleFonts.mPlusRounded1c(fontWeight: FontWeight.w600)),
          MultiSelectDialogField<String>(
            items: preferenceItems,
            initialValue: selectedPreference[i],
            title: const Text("趣向・宗教"),
            buttonText: Text("趣向・宗教を選択", style: GoogleFonts.mPlusRounded1c()),
            chipDisplay: MultiSelectChipDisplay.none(),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withOpacity(0.3)),
            ),
            onConfirm: (values) => setState(() => selectedPreference[i] = values),
          ),
        ],
      ),
    );
  }

  Widget _buildCookingTime() {
    return DropdownButton<String>(
      value: selectedCookingTime,
      isExpanded: true,
      dropdownColor: Colors.white,
      style: GoogleFonts.mPlusRounded1c(fontSize: 16, color: Colors.black87),
      iconEnabledColor: accentColor,
      items: cookingTimeOptions
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (value) => setState(() => selectedCookingTime = value!),
    );
  }

  Widget _buildFeelingInput() {
    return TextField(
      maxLength: 50,
      decoration: InputDecoration(
        hintText: '例：お肉の気分',
        hintStyle: GoogleFonts.mPlusRounded1c(color: Colors.black26),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor.withOpacity(0.15)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      style: GoogleFonts.mPlusRounded1c(),
      onChanged: (value) => todayFeeling = value,
    );
  }

  Future<void> _submitForm() async {
    final data = {
      'genders': genders,
      'ages': ages,
      'preferences': selectedPreference,
      'selectedCookingTime': selectedCookingTime,
      'todayFeeling': todayFeeling,
    };

    try {
      final response = await http.post(
        Uri.parse('https://submit-demo-418875428443.us-central1.run.app/submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FlyerUploadPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('送信失敗: ${response.statusCode}', style: GoogleFonts.mPlusRounded1c())),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('通信エラーが発生しました', style: GoogleFonts.mPlusRounded1c())),
      );
    }
  }
}
