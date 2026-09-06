import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:life_ops/services/ai_guard.dart';
import 'package:life_ops/screens/setup/setup1.dart';

class Utils {
  void changeSystemColor(Brightness mode) {
    // SystemChrome.setSystemUIOverlayStyle(
    //     SystemUiOverlayStyle(statusBarBrightness: mode));
  }

  String taskPrompt(String cat) {
    // Category names and existing task descriptions are user-entered
    // ("Enter My Own..."), so they are sanitized before being embedded in
    // the prompt to keep injected instructions out of it.
    cat = AiGuard.sanitizeField(cat, maxChars: 60);
    String blacklist = '';

    for (var element in tasks) {
      blacklist += '${AiGuard.sanitizeField(element.taskdescription, maxChars: 40)},';
    }

    // HACK to remove the trailing comma
    if (blacklist.isNotEmpty) {
      blacklist = blacklist.substring(0, blacklist.length - 1);
    }

    if (kDebugMode) {
      print('blacklist is $blacklist');
    }

    String prompt = "Generate a list of 10 daily tasks that support the "
        "value $cat. Use no more than 20 characters for each daily task. "
        "Do not include a time duration for each task. "
        "Make each task measurable by a boolean response."
        "Remove double quotes from the response."
        "Remove apostrophes from the response. "
        "Remove single quotes from the response. "
        "Remove commas from the response. "
        "Separate each field with |. "
        "Remove items similar to those in this comma separated list: $blacklist  ";

    if (kDebugMode) {
      print(prompt);
    }

    return prompt;
  }

  bool toBoolean(String s) {
    return s != '0' && s != 'false' && s != '';
  }
}
