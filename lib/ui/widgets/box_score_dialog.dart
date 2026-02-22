import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/player.dart';
import '../../models/action_type.dart';
import '../../providers/stats_provider.dart';

class BoxScoreDialog extends ConsumerWidget {
  const BoxScoreDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homePlayers = ref.watch(homeTeamPlayersProvider);
    final awayPlayers = ref.watch(awayTeamPlayersProvider);

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Box Score'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IntrinsicWidth(child: _buildTeamSection(context, ref, 'HOME', homePlayers, TeamType.home)),
                const VerticalDivider(width: 32, thickness: 1),
                IntrinsicWidth(child: _buildTeamSection(context, ref, 'AWAY', awayPlayers, TeamType.away)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamSection(BuildContext context, WidgetRef ref, String title, List<Player> players, TeamType team) {
    final playerStatsList = players.map((p) => ref.watch(playerStatsProvider(p.id))).toList();
    final teamStats = ref.watch(playerStatsProvider('TEAM_${team.name}'));
    
    // Calculate Totals (Players + Team)
    int totalPts = teamStats.pts, total2m = teamStats.p2m, total2a = teamStats.p2a;
    int total3m = teamStats.p3m, total3a = teamStats.p3a, totalftm = teamStats.ftm, totalfta = teamStats.fta;
    int totalOreb = teamStats.oreb, totalDreb = teamStats.dreb, totalAst = teamStats.ast;
    int totalStl = teamStats.stl, totalBlk = teamStats.blk, totalTo = teamStats.turnover, totalF = teamStats.fouls;

    for (var s in playerStatsList) {
      totalPts += s.pts;
      total2m += s.p2m; total2a += s.p2a;
      total3m += s.p3m; total3a += s.p3a;
      totalftm += s.ftm; totalfta += s.fta;
      totalOreb += s.oreb; totalDreb += s.dreb;
      totalAst += s.ast; totalStl += s.stl; totalBlk += s.blk;
      totalTo += s.turnover; totalF += s.fouls;
    }

    const headerStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.bold);
    const cellStyle = TextStyle(fontSize: 13);
    const smallCellStyle = TextStyle(fontSize: 12);
    const totalLabelStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3)),
        ),
        DataTable(
          columnSpacing: 16,
          horizontalMargin: 8,
          headingRowHeight: 48,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 56,
          columns: const [
            DataColumn(label: Text('#', style: headerStyle)),
            DataColumn(label: Text('Name', style: headerStyle)),
            DataColumn(label: Text('PTS', style: headerStyle)),
            DataColumn(label: Text('2P', style: headerStyle)),
            DataColumn(label: Text('3P', style: headerStyle)),
            DataColumn(label: Text('FT', style: headerStyle)),
            DataColumn(label: Text('REB', style: headerStyle)),
            DataColumn(label: Text('AS', style: headerStyle)),
            DataColumn(label: Text('ST', style: headerStyle)),
            DataColumn(label: Text('BL', style: headerStyle)),
            DataColumn(label: Text('TO', style: headerStyle)),
            DataColumn(label: Text('F', style: headerStyle)),
          ],
          rows: [
            ...players.asMap().entries.map((entry) {
              final p = entry.value;
              final stats = playerStatsList[entry.key];
              return DataRow(cells: [
                DataCell(Text(p.number, style: cellStyle)),
                DataCell(SizedBox(width: 110, child: Text(p.name, overflow: TextOverflow.ellipsis, style: cellStyle))),
                DataCell(Text('${stats.pts}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataCell(Text('${stats.p2m}/${stats.p2a}', style: smallCellStyle)),
                DataCell(Text('${stats.p3m}/${stats.p3a}', style: smallCellStyle)),
                DataCell(Text('${stats.ftm}/${stats.fta}', style: smallCellStyle)),
                DataCell(Text('${stats.oreb}/${stats.dreb}', style: smallCellStyle)),
                DataCell(Text('${stats.ast}', style: cellStyle)),
                DataCell(Text('${stats.stl}', style: cellStyle)),
                DataCell(Text('${stats.blk}', style: cellStyle)),
                DataCell(Text('${stats.turnover}', style: cellStyle)),
                DataCell(Text('${stats.fouls}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: stats.fouls >= 5 ? Colors.red : (stats.fouls >= 4 ? Colors.orange : null)))),
              ]);
            }),
            // TEAM Row
            DataRow(
              color: WidgetStateProperty.all(Colors.blueGrey.withOpacity(0.05)),
              cells: [
                const DataCell(Text('-')),
                const DataCell(Text('TEAM', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 14))),
                DataCell(Text('${teamStats.pts}', style: cellStyle)),
                DataCell(Text('${teamStats.p2m}/${teamStats.p2a}', style: smallCellStyle)),
                DataCell(Text('${teamStats.p3m}/${teamStats.p3a}', style: smallCellStyle)),
                DataCell(Text('${teamStats.ftm}/${teamStats.fta}', style: smallCellStyle)),
                DataCell(Text('${teamStats.oreb}/${teamStats.dreb}', style: smallCellStyle)),
                DataCell(Text('${teamStats.ast}', style: cellStyle)),
                DataCell(Text('${teamStats.stl}', style: cellStyle)),
                DataCell(Text('${teamStats.blk}', style: cellStyle)),
                DataCell(Text('${teamStats.turnover}', style: cellStyle)),
                DataCell(Text('${teamStats.fouls}', style: cellStyle)),
              ],
            ),
            // Total Row
            DataRow(
              color: WidgetStateProperty.all(Colors.amber.withOpacity(0.1)),
              cells: [
                const DataCell(Text('')),
                const DataCell(Text('TOTAL', style: totalLabelStyle)),
                DataCell(Text('$totalPts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber))),
                DataCell(Text('$total2m/$total2a', style: totalLabelStyle)),
                DataCell(Text('$total3m/$total3a', style: totalLabelStyle)),
                DataCell(Text('$totalftm/$totalfta', style: totalLabelStyle)),
                DataCell(Text('$totalOreb/$totalDreb', style: totalLabelStyle)),
                DataCell(Text('$totalAst', style: totalLabelStyle)),
                DataCell(Text('$totalStl', style: totalLabelStyle)),
                DataCell(Text('$totalBlk', style: totalLabelStyle)),
                DataCell(Text('$totalTo', style: totalLabelStyle)),
                DataCell(Text('$totalF', style: totalLabelStyle)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
