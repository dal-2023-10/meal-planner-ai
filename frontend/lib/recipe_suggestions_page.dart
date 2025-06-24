import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'input_form_page.dart';

class RecipeDetailPage extends StatelessWidget {
  final Map<String, dynamic> recipe;
  const RecipeDetailPage({super.key, required this.recipe});

  static const accentColor = Color(0xFFFF8A80); // コーラルピンク
  static const shadowColor = Color(0x33FF8A80);
  static const bgColor = Color(0xFFFFF8E7); // クリーム色

  @override
  Widget build(BuildContext context) {
    final header = (recipe["header"] as List?)?.isNotEmpty == true ? recipe["header"][0] : {};
    final nutrition = (recipe["nutrition"] as List?)?.isNotEmpty == true ? recipe["nutrition"][0] : {};
    final ingredients = (recipe["ingredients"] as List?) ?? [];
    final instructions = (recipe["instructions"] as List?) ?? [];
    final imageBase64 = recipe['image_base64'];
    Uint8List? imageBytes;
    if (imageBase64 != null && imageBase64 is String && imageBase64.isNotEmpty) {
      imageBytes = base64Decode(imageBase64);
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
            child: Container(
              padding: const EdgeInsets.all(28),
              constraints: const BoxConstraints(maxWidth: 900),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: shadowColor, offset: const Offset(3, 7), blurRadius: 18),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    header["title"] ?? 'レシピ名未設定',
                    style: GoogleFonts.mPlusRounded1c(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                      letterSpacing: 1.6,
                      shadows: [
                        const Shadow(
                          color: Colors.black12,
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('基本情報'),
                            _infoRow('調理時間', '${header["total_time_min"] ?? "-"}分'),
                            _infoRow('ジャンル', header["cuisine"] ?? "-"),
                            const SizedBox(height: 28),
                            _sectionTitle('材料'),
                            _listCard(
                              ingredients
                                  .map<String>((item) =>
                                      '${item["name"] ?? ""} ${item["quantity"] ?? ""}${item["unit"] ?? ""}')
                                  .toList(),
                            ),
                            const SizedBox(height: 28),
                            _sectionTitle('栄養素'),
                            _infoRow('摂取カロリー', '${nutrition["kcal"] ?? "-"} kcal'),
                            _infoRow('タンパク質', '${nutrition["protein_g"] ?? "-"}g'),
                            _infoRow('脂質', '${nutrition["fat_g"] ?? "-"}g'),
                            _infoRow('炭水化物', '${nutrition["carb_g"] ?? "-"}g'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      SizedBox(
                        width: 380,
                        child: _buildImageCard(imageBytes),
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  // ★↓↓ここから「作り方」だけ全幅で表示★
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: _sectionTitle('作り方'),
                  ),
                  Container(
                    width: double.infinity,
                    child: _numberedSteps(
                      instructions.map<String>((step) => step["text"] ?? '').toList(),
                    ),
                  ),
                  // ★↑↑ここまで全幅で表示↑↑★
                  const SizedBox(height: 34),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 18,
                    runSpacing: 14,
                    children: [
                      _roundedFab(
                        icon: Icons.home,
                        label: 'トップに戻る',
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const InputFormPage()),
                            (route) => false,
                          );
                        },
                      ),
                      _roundedFab(
                        icon: Icons.save,
                        label: 'レシピを保存',
                        onPressed: () async {
                          final savePayload = {
                            "header": recipe["header"] ?? [],
                            "nutrition": recipe["nutrition"] ?? [],
                            "ingredients": recipe["ingredients"] ?? [],
                            "instructions": recipe["instructions"] ?? [],
                          };
                          try {
                            final response = await http.post(
                              Uri.parse("https://bq-uplode-418875428443.asia-northeast1.run.app/save_recipe"),
                              headers: {"Content-Type": "application/json"},
                              body: jsonEncode(savePayload),
                            );
                            if (response.statusCode == 200) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('レシピを保存しました', style: GoogleFonts.mPlusRounded1c())),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('保存失敗: ${response.statusCode}', style: GoogleFonts.mPlusRounded1c())),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('通信エラー: $e', style: GoogleFonts.mPlusRounded1c())),
                            );
                          }
                        },
                      ),
                      _roundedFab(
                        icon: Icons.bookmark,
                        label: 'myレシピ',
                        onPressed: () {},
                      ),
                      _roundedFab(
                        icon: Icons.health_and_safety,
                        label: '栄養管理',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 以下ウィジェットパーツ ---

  static Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(
          title,
          style: GoogleFonts.mPlusRounded1c(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
      );

  static Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Text('$label：', style: GoogleFonts.mPlusRounded1c(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(value, style: GoogleFonts.mPlusRounded1c(fontSize: 16)),
          ],
        ),
      );

  static Widget _listCard(List<String> items) => Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Color(0xFFFDF6F3),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(2, 2), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('・$e', style: GoogleFonts.mPlusRounded1c(fontSize: 16)),
                  ))
              .toList(),
        ),
      );

  static Widget _numberedSteps(List<String> steps) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: steps.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final step = entry.value;
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(0xFFFDF6F3),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(2, 2), blurRadius: 6)],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: accentColor,
                  radius: 15,
                  child: Text('$index', style: GoogleFonts.mPlusRounded1c(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step,
                    style: GoogleFonts.mPlusRounded1c(fontSize: 16),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );

  static Widget _buildImageCard(Uint8List? imageBytes) => Container(
        width: 380,
        height: 380,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33FF8A80),
              offset: Offset(2, 2),
              blurRadius: 9,
            )
          ],
        ),
        child: imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.memory(imageBytes, fit: BoxFit.cover, width: 380, height: 380),
              )
            : Center(
                child: Text(
                  '完成イメージ（画像が入ります）',
                  style: GoogleFonts.mPlusRounded1c(fontSize: 16, color: Colors.black54),
                ),
              ),
      );

  static Widget _roundedFab({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton.extended(
      backgroundColor: accentColor,
      foregroundColor: Colors.white,
      heroTag: label,
      elevation: 4,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(
        label,
        style: GoogleFonts.mPlusRounded1c(fontWeight: FontWeight.bold),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}
