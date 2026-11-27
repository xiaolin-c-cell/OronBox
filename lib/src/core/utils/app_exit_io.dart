import 'dart:io';

import 'package:flutter/services.dart';

bool get canExitApp => true;

void exitApp() {
  if (Platform.isAndroid || Platform.isIOS) {
    SystemNavigator.pop();
  } else {
    exit(0);
  }
}
