import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/message_model.dart';
import '../services/message_service.dart';
import '../services/api_service.dart';

class SentimentDashboard extends StatefulWidget {
  final String userId;

  const SentimentDashboard({super.key, required this.userId});

  @override
  State<SentimentDashboard> createState() => _SentimentDashboardState();
}

class _SentimentDashboardState extends State<SentimentDashboard> {
  List<MessageModel> _messages = [];
  bool _loading = true;

  Map<String, int> _sentimentCounts = {
    'Positive': 0,
    'Negative': 0,
    'Neutral': 0,
  };

  List<FlSpot> _lineData = [];

  @override
  void initState() {
    super.initState();
    _loadSentimentData();
  }

  Future<void> _loadSentimentData() async {
    try {
      String token = ApiService.token ?? '';
      if (token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('jwt') ?? '';
      }

      final messages =
          await MessageService().getMessagesByUser(widget.userId, token);

      final sentimentCounts = {
        'Positive': 0,
        'Negative': 0,
        'Neutral': 0,
      };
      final List<FlSpot> lineData = [];

      for (int i = 0; i < messages.length; i++) {
        final rawSentiment = messages[i].sentiment ?? 'neutral';
        final sentiment = rawSentiment.toLowerCase();

        switch (sentiment) {
          case 'positive':
            sentimentCounts['Positive'] = sentimentCounts['Positive']! + 1;
            lineData.add(FlSpot(i.toDouble(), 1));
            break;
          case 'negative':
            sentimentCounts['Negative'] = sentimentCounts['Negative']! + 1;
            lineData.add(FlSpot(i.toDouble(), -1));
            break;
          default:
            sentimentCounts['Neutral'] = sentimentCounts['Neutral']! + 1;
            lineData.add(FlSpot(i.toDouble(), 0));
        }
      }

      setState(() {
        _messages = messages;
        _sentimentCounts = sentimentCounts;
        _lineData = lineData;
        _loading = false;
      });
    } catch (e) {
      print('Error loading sentiment data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sentiment Dashboard')),
      body: _messages.isEmpty
          ? const Center(child: Text("No messages yet."))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sentiment Distribution (Pie)',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: _buildPieSections(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _sentimentCounts.entries.map((e) {
                      return Column(
                        children: [
                          Text(e.key,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(e.value.toString(),
                              style: const TextStyle(fontSize: 12)),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  const Text('Sentiment Over Time (Line)',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            color: Colors.blue,
                            spots: _lineData,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blue.withOpacity(0.2),
                            ),
                          ),
                        ],
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    final total =
        _sentimentCounts.values.fold<int>(0, (sum, count) => sum + count);

    return _sentimentCounts.entries.map((entry) {
      final percentage = total > 0 ? (entry.value / total) * 100 : 0;
      final color = entry.key == 'Positive'
          ? Colors.green
          : entry.key == 'Negative'
              ? Colors.red
              : Colors.grey;

      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${entry.key} (${percentage.toStringAsFixed(1)}%)',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      );
    }).toList();
  }
}
