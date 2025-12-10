import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';

class ProgressChartScreen extends StatelessWidget {
  const ProgressChartScreen({
    super.key,
    required this.milestones,
    required this.totalSkills,
  });

  final List<ProgressMilestone> milestones;
  final int totalSkills;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = milestones.isNotEmpty;
    final charts = hasData ? _buildChartSections(theme) : const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Analytics'),
      ),
      body: SafeArea(
        child: hasData
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    charts,
                    const SizedBox(height: 24),
                    const Text(
                      'Milestone Timeline',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ocean,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: milestones.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final milestone = milestones[index];
                          return _MilestoneTile(milestone: milestone);
                        },
                      ),
                    ),
                  ],
                ),
              )
            : _buildEmptyState(context),
      ),
    );
  }

  Widget _buildChartSections(ThemeData theme) {
    final sorted = milestones.toList()
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    final firstDate = sorted.first.completedAt;
    final minX = 0.0;
    final maxX =
        sorted.last.completedAt.difference(firstDate).inDays.toDouble();
    final total = totalSkills == 0 ? sorted.length : totalSkills;

    final spots = <FlSpot>[];
    double progress = 0;
    for (final entry in sorted) {
      progress += 1;
      final days = entry.completedAt.difference(firstDate).inDays.toDouble();
      spots.add(FlSpot(days, progress / total * 100));
    }

    return AspectRatio(
      aspectRatio: 1.4,
      child: Card(
        elevation: 0,
        color: AppColors.ocean.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LineChart(
            LineChartData(
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      final date = firstDate.add(Duration(days: value.toInt()));
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat.Md().format(date),
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                    interval: (sorted.length <= 1 || maxX == 0)
                        ? 1
                        : (maxX / (sorted.length.clamp(2, 6))).ceilToDouble(),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toInt()}%',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    interval: 20,
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              minX: minX,
              maxX: maxX == 0 ? 1 : maxX,
              minY: 0,
              maxY: 100,
              gridData: FlGridData(
                show: true,
                horizontalInterval: 20,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withOpacity(0.2),
                  strokeWidth: 1,
                ),
                drawVerticalLine: false,
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.ocean,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 4,
                      color: AppColors.ocean,
                      strokeColor: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.ocean.withOpacity(0.3),
                        AppColors.ocean.withOpacity(0.05),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => Colors.white,
                  getTooltipItems: (spots) => spots.map((spot) {
                    final date = firstDate.add(Duration(days: spot.x.toInt()));
                    return LineTooltipItem(
                      '${DateFormat.yMMMd().format(date)}\nProgress: ${spot.y.toStringAsFixed(1)}%',
                      const TextStyle(
                        color: AppColors.ocean,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insights_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'No progress data yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.ocean,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Complete a few lessons to unlock your analytics.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ProgressMilestone {
  const ProgressMilestone({
    required this.title,
    required this.description,
    required this.completedAt,
  });

  final String title;
  final String description;
  final DateTime completedAt;
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.milestone});

  final ProgressMilestone milestone;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('EEEE, MMM d - h:mm a');
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.ocean.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.ocean,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestone.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatter.format(milestone.completedAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (milestone.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      milestone.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

