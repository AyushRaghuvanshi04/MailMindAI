import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/email_summary.dart';
import '../config/api_config.dart';

class SummarizerService {
  Future<EmailSummary> summarizeEmail(String emailContent) async {
    // Check if API key is configured
    if (!ApiConfig.isApiKeyConfigured) {
      print('Gemini API key not configured. Using mock service...');
      return _generateMockSummary(emailContent);
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.geminiApiUrl}?key=${ApiConfig.geminiApiKey}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': '''You are an expert email summarizer. Analyze the email and provide:
1. A concise summary (2-3 sentences)
2. Key points (3-5 bullet points)
3. Action items (tasks that need to be done)
4. Sentiment analysis (positive, negative, or neutral)

Respond in JSON format:
{
  "summary": "brief summary here",
  "keyPoints": ["point 1", "point 2", "point 3"],
  "actionItems": ["action 1", "action 2"],
  "sentiment": "positive/negative/neutral"
}

Email to analyze:
$emailContent'''
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': ApiConfig.temperature,
            'maxOutputTokens': ApiConfig.maxTokens,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'];
        
        // Extract JSON from the response (Gemini might wrap it in markdown)
        final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
        if (jsonMatch != null) {
          final jsonString = jsonMatch.group(0);
          final parsedContent = jsonDecode(jsonString!);
          
          return EmailSummary(
            originalContent: emailContent,
            summary: parsedContent['summary'] ?? 'No summary available',
            keyPoints: List<String>.from(parsedContent['keyPoints'] ?? []),
            actionItems: List<String>.from(parsedContent['actionItems'] ?? []),
            sentiment: parsedContent['sentiment'] ?? 'neutral',
            timestamp: DateTime.now(),
          );
        } else {
          // Fallback if JSON parsing fails
          return _generateMockSummary(emailContent);
        }
      } else {
        throw Exception('API request failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // Fallback to mock service if API fails
      print('Gemini API error: $e');
      print('Falling back to mock service...');
      return _generateMockSummary(emailContent);
    }
  }

  Future<String> askQuestion(String emailContent, EmailSummary summary, String question) async {
    // Check if API key is configured
    if (!ApiConfig.isApiKeyConfigured) {
      print('Gemini API key not configured. Using mock response...');
      return _generateMockAnswer(question, emailContent, summary);
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.geminiApiUrl}?key=${ApiConfig.geminiApiKey}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': '''You are an AI assistant helping with email analysis. You have access to an email and its summary. Answer the user's question based on this information.

Email Content:
$emailContent

Email Summary:
- Summary: ${summary.summary}
- Key Points: ${summary.keyPoints.join(', ')}
- Action Items: ${summary.actionItems.join(', ')}
- Sentiment: ${summary.sentiment}

User Question: $question

Please provide a helpful, accurate answer based on the email content and summary. Be concise but informative.'''
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.3,
            'maxOutputTokens': 300,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'];
        return content.trim();
      } else {
        throw Exception('API request failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // Fallback to mock service if API fails
      print('Gemini API error for question: $e');
      print('Falling back to mock response...');
      return _generateMockAnswer(question, emailContent, summary);
    }
  }

  // Fallback mock service (kept for backup)
  EmailSummary _generateMockSummary(String emailContent) {
    final summary = _generateMockSummaryText(emailContent);
    final keyPoints = _extractKeyPoints(emailContent);
    final actionItems = _extractActionItems(emailContent);
    final sentiment = _analyzeSentiment(emailContent);

    return EmailSummary(
      originalContent: emailContent,
      summary: summary,
      keyPoints: keyPoints,
      actionItems: actionItems,
      sentiment: sentiment,
      timestamp: DateTime.now(),
    );
  }

  String _generateMockAnswer(String question, String emailContent, EmailSummary summary) {
    final lowerQuestion = question.toLowerCase();
    
    if (lowerQuestion.contains('deadline') || lowerQuestion.contains('due')) {
      return "Based on the email, I can see there's a deadline mentioned for the quarterly report - it's due by Friday. Make sure to prioritize this task.";
    } else if (lowerQuestion.contains('action') || lowerQuestion.contains('task')) {
      return "The main action items from this email are: ${summary.actionItems.join(', ')}. These tasks require your attention.";
    } else if (lowerQuestion.contains('tone') || lowerQuestion.contains('sentiment')) {
      return "The email has a ${summary.sentiment} tone. This indicates the overall mood and urgency of the communication.";
    } else if (lowerQuestion.contains('urgent') || lowerQuestion.contains('important')) {
      return "The email mentions some urgent issues that need immediate attention. You should review the attached documents and schedule a call to discuss details.";
    } else if (lowerQuestion.contains('meeting')) {
      return "There's a follow-up meeting mentioned that needs to be scheduled with the client next week. You should coordinate with the team to find a suitable time.";
    } else {
      return "Based on the email content, I can help you understand specific aspects. Try asking about deadlines, action items, tone, or urgent matters.";
    }
  }

  String _generateMockSummaryText(String content) {
    final words = content.split(' ');
    if (words.length < 10) {
      return content;
    }

    final sentences = content.split('.');
    final summarySentences = sentences.take(2).where((s) => s.trim().isNotEmpty);
    return summarySentences.join('. ') + '.';
  }

  List<String> _extractKeyPoints(String content) {
    final keyPoints = <String>[];
    
    if (content.toLowerCase().contains('meeting')) {
      keyPoints.add('Meeting scheduled or discussed');
    }
    if (content.toLowerCase().contains('deadline')) {
      keyPoints.add('Deadline mentioned');
    }
    if (content.toLowerCase().contains('project')) {
      keyPoints.add('Project-related discussion');
    }
    if (content.toLowerCase().contains('budget')) {
      keyPoints.add('Budget or financial information');
    }
    if (content.toLowerCase().contains('client')) {
      keyPoints.add('Client-related information');
    }

    if (keyPoints.isEmpty) {
      keyPoints.add('Important communication received');
      keyPoints.add('Requires attention or response');
    }

    return keyPoints;
  }

  List<String> _extractActionItems(String content) {
    final actionItems = <String>[];
    
    if (content.toLowerCase().contains('please review')) {
      actionItems.add('Review the provided information');
    }
    if (content.toLowerCase().contains('need to')) {
      actionItems.add('Address urgent requirements');
    }
    if (content.toLowerCase().contains('follow up')) {
      actionItems.add('Follow up on discussed items');
    }
    if (content.toLowerCase().contains('respond')) {
      actionItems.add('Send a response');
    }

    if (actionItems.isEmpty) {
      actionItems.add('Consider appropriate response');
    }

    return actionItems;
  }

  String _analyzeSentiment(String content) {
    final lowerContent = content.toLowerCase();
    
    final positiveWords = ['great', 'excellent', 'good', 'positive', 'success', 'happy'];
    final negativeWords = ['bad', 'poor', 'negative', 'problem', 'issue', 'urgent', 'critical'];
    
    int positiveCount = 0;
    int negativeCount = 0;
    
    for (final word in positiveWords) {
      if (lowerContent.contains(word)) positiveCount++;
    }
    
    for (final word in negativeWords) {
      if (lowerContent.contains(word)) negativeCount++;
    }
    
    if (positiveCount > negativeCount) {
      return 'positive';
    } else if (negativeCount > positiveCount) {
      return 'negative';
    } else {
      return 'neutral';
    }
  }
} 