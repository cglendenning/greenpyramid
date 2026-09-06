import 'package:flutter/services.dart';

class Utils {
  void changeSystemColor(Brightness mode) {
    // SystemChrome.setSystemUIOverlayStyle(
    //     SystemUiOverlayStyle(statusBarBrightness: mode));
  }

  bool toBoolean(String s) {
    return s != '0' && s != 'false' && s != '';
  }
}
