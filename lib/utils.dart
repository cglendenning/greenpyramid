import 'package:flutter/services.dart';
import 'package:life_ops/setup/setup1.dart';

class Utils {

  void changeSystemColor(Brightness mode) {
    SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(statusBarBrightness: mode));
  }

  String taskPrompt(String cat) {
    String blacklist = '';

    tasks.forEach((element) {
      blacklist += element.taskdescription + ',';
    });

    // HACK to remove the trailing comma
    if (blacklist.isNotEmpty) {
      blacklist = blacklist.substring(0, blacklist.length - 1);
    }

    print('blacklist is $blacklist');

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

    print(prompt);

    return prompt;
  }

  bool toBoolean(String s) {
    return s != '0' && s != 'false' && s != '';
  }
}
