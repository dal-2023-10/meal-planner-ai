import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // サンプルデータ（本番はAPIレスポンスで受け取ったMapを渡すだけ）
    final sampleRecipe = {
      "header": [
        {"title": "豚の生姜焼き定食", "cuisine": "和食", "total_time_min": 20}
      ],
      "nutrition": [
        {"kcal": 580, "protein_g": 28, "fat_g": 22, "carb_g": 40}
      ],
      "ingredients": [
        {"name": "豚こま肉", "quantity": "200", "unit": "g"},
        {"name": "玉ねぎ", "quantity": "1", "unit": "個"},
        {"name": "しょうがチューブ", "quantity": "3", "unit": "cm"},
        {"name": "醤油", "quantity": "1", "unit": "大さじ"},
        {"name": "みりん", "quantity": "1", "unit": "大さじ"},
        {"name": "酒", "quantity": "1", "unit": "大さじ"},
        {"name": "サラダ油", "quantity": "適量", "unit": ""},
      ],
      "instructions": [
        {"step": 1, "text": "玉ねぎを薄切りにします"},
        {"step": 2, "text": "フライパンに油を熱し、玉ねぎを炒めます"},
        {"step": 3, "text": "豚肉を加えて炒め、色が変わったら調味料としょうがを加えます"},
        {"step": 4, "text": "中火で煮詰めるように炒めます"},
        {"step": 5, "text": "火を止めて盛り付けて完成"},
      ]
    };

    return MaterialApp(
      title: '献立提案AI',
      theme: ThemeData(useMaterial3: true),
      home: RecipeDetailPage(recipe: sampleRecipe),
    );
  }
}

class RecipeDetailPage extends StatelessWidget {
  final Map<String, dynamic> recipe;
  const RecipeDetailPage({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    // データを安全に取り出し
    final header = (recipe["header"] as List?)?.isNotEmpty == true ? recipe["header"][0] : {};
    final nutrition = (recipe["nutrition"] as List?)?.isNotEmpty == true ? recipe["nutrition"][0] : {};
    final ingredients = (recipe["ingredients"] as List?) ?? [];
    final instructions = (recipe["instructions"] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: Text('🍴${header["title"] ?? ""}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // 完成イメージを先頭へ & 高さ調整
            Container(
              height: 160,
              color: Colors.grey[300],
              alignment: Alignment.center,
              child: const Text('📸 完成イメージ'),
            ),
            const SizedBox(height: 20),

            Text('🍚 調理時間：${header["total_time_min"] ?? "-"}分', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            if (header["cuisine"] != null)
              Text('ジャンル：${header["cuisine"]}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),

            const Text('🧂 材料：', style: TextStyle(fontWeight: FontWeight.bold)),
            ...ingredients.map<Widget>((item) => Text(
              '- ${item["name"] ?? ""} ${item["quantity"] ?? ""}${item["unit"] ?? ""}'
            )),
            const SizedBox(height: 16),

            if (nutrition.isNotEmpty) ...[
              Text('🔥 摂取カロリー：${nutrition["kcal"] ?? "-"} kcal'),
              const Text('💊 栄養素：'),
              Table(
                border: TableBorder.all(color: Colors.grey),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFFE0E0E0)),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(6),
                        child: Text('項目', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(6),
                        child: Text('量', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...[
                    ['タンパク質', '${nutrition["protein_g"] ?? "-"}g'],
                    ['脂質', '${nutrition["fat_g"] ?? "-"}g'],
                    ['炭水化物', '${nutrition["carb_g"] ?? "-"}g'],
                  ].map((row) => TableRow(
                    children: row.map((cell) => Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(cell),
                    )).toList(),
                  )),
                ],
              ),
            ],
            const SizedBox(height: 20),

            const Text('📝 作り方：', style: TextStyle(fontWeight: FontWeight.bold)),
            ...instructions.map<Widget>((step) =>
              Text('${step["step"] ?? ""}. ${step["text"] ?? ""}')
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "back",
            icon: const Icon(Icons.home),
            label: const Text('トップに戻る'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TopPage()),
              );
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: "save",
            icon: const Icon(Icons.save),
            label: const Text('レシピを保存'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('レシピを保存しました（仮）')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class TopPage extends StatelessWidget {
  const TopPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('トップページ')),
      body: const Center(child: Text('ここがトップページです')),
    );
  }
}
