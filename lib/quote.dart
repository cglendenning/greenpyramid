import "dart:math";
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:life_ops/secrets.dart';
import 'package:life_ops/services/ai_guard.dart';

class Quote {
  String randomQuote() {
    List<String> quotes = [
      '"The best way to predict the future is to create it." - Peter Drucker',
      '"Trust the process."',
      '"Relentlessly chase excellence."',
      '"Do today what others won\'t, so tomorrow you can do what others can\'t."',
      '"Fail Forward Fast."',
      '"We don\'t see things as they are; we see them as we are." - Anaïs Nin',
      '"Winners never quit and quitters never win" - Vince Lombardi',
      '"You can not be brave if you are not afraid. There is no courage without fear." - Tony Blauer',
      '"Whether you believe you can do a thing or not, you are right." - Henry Ford',
      '"Master the art of showing up consistently." - James Clear',
      '"It is not about how hard you hit. It is about how hard you can get hit and keep moving forward." - Rocky'
    ];

    final random = Random();

    return quotes[random.nextInt(quotes.length)];
  }

  Future<String> getCommentary(String quote, String cType) async {
    OpenAI.apiKey = openAIApiKey;

    String system = '';
    String prompt = '';

    switch (cType) {
      case 'inspiration':
        system = "You are Tony Robbins. But do not identify yourself.";
        prompt = "Generate no more than 50 words expanding upon "
            "this quote: $quote. End with a quip about winning the day.";
      case 'motivation':
        system = "You are Jocko Willink. But do not identify yourself.";
        prompt = "Generate no more than 50 words expanding upon "
            "this quote: $quote. End with a quip about winning the day.";
      case 'information':
        system = "You are James Clear. But do not identify yourself.";
        prompt = "Generate no more than 50 words expanding upon "
            "this quote: $quote. End with a quip about winning the day.";
      case 'encouragement':
        system =
            "You are a fear management expert. But do not identify yourself.";
        prompt = "Generate no more than 50 words expanding upon "
            "this quote: $quote. End with a quip about winning the day.";
    }

    const int timeout = 45;

    String chatResult = "You've got this.";

    try {
      await AiGuard.instance.acquire();
      OpenAIChatCompletionModel chatCompletion =
          await OpenAI.instance.chat.create(
        model: "gpt-4o",
        maxTokens: 150,
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(system),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
            ],
          ),
        ],
      ).timeout(const Duration(seconds: timeout));

      chatResult =
          (chatCompletion.choices[0].message.content?.first.text ?? '');
    } on AiBudgetException catch (e) {
      chatResult = e.message;
    } catch (e, s) {
      if (kDebugMode) {
        print(e);
      }
      if (kDebugMode) {
        print(s);
      }
    }

    return chatResult;
  }
}
