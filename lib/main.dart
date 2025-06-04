import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '献立提案AI',
      theme: ThemeData(useMaterial3: true),
      home: const RecipeDetailPage(),
    );
  }
}

class RecipeDetailPage extends StatelessWidget {
  const RecipeDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🍴豚の生姜焼き定食')),
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

            const Text('🍚 調理時間：20分'),
            const Text('💰 金額目安：450円'),
            const SizedBox(height: 16),
            const Text('🧂 材料：'),
            const Text(
              '- 豚こま肉 200g\n- 玉ねぎ 1個\n- しょうがチューブ 3cm\n- 醤油・みりん・酒 各大さじ1\n- サラダ油 適量',
            ),
            const SizedBox(height: 16),
            const Text('🔥 摂取カロリー：580 kcal'),
            const Text('💊 栄養素：'),
            // 表サイズをコンパクトに
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
                  ['タンパク質', '28g'],
                  ['脂質', '22g'],
                  ['炭水化物', '40g'],
                ].map((row) => TableRow(
                  children: row.map((cell) => Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(cell),
                  )).toList(),
                )),
              ],
            ),
            const SizedBox(height: 20),
            const Text('📝 作り方：'),
            const Text('''
1. 玉ねぎを薄切りにします
2. フライパンに油を熱し、玉ねぎを炒めます
3. 豚肉を加えて炒め、色が変わったら調味料としょうがを加えます
4. 中火で煮詰めるように炒めます
5. 火を止めて盛り付けて完成
'''),
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
