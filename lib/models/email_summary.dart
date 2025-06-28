class EmailSummary {
  final String originalContent;
  final String summary;
  final List<String> keyPoints;
  final List<String> actionItems;
  final String sentiment;
  final DateTime timestamp;

  EmailSummary({
    required this.originalContent,
    required this.summary,
    required this.keyPoints,
    required this.actionItems,
    required this.sentiment,
    required this.timestamp,
  });

  factory EmailSummary.fromJson(Map<String, dynamic> json) {
    return EmailSummary(
      originalContent: json['originalContent'] ?? '',
      summary: json['summary'] ?? '',
      keyPoints: List<String>.from(json['keyPoints'] ?? []),
      actionItems: List<String>.from(json['actionItems'] ?? []),
      sentiment: json['sentiment'] ?? 'neutral',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'originalContent': originalContent,
      'summary': summary,
      'keyPoints': keyPoints,
      'actionItems': actionItems,
      'sentiment': sentiment,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'EmailSummary(summary: $summary, keyPoints: $keyPoints, actionItems: $actionItems, sentiment: $sentiment)';
  }
} 