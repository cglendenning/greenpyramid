import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:life_ops/setup/setup1.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class Utils {

  void changeSystemColor(Brightness mode) {
    SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(statusBarBrightness: mode));
  }

  String taskPrompt(String cat) {
    String blacklist = '';

    for (var element in tasks) {
      blacklist += '${element.taskdescription},';
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

  Future<bool> isUserSubscribed() async {
    try {
      await Purchases.invalidateCustomerInfoCache();
      CustomerInfo ci = await Purchases.getCustomerInfo();
      return ci.activeSubscriptions.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking subscription status: $e');
      }
      return false;
    }
  }
}
