import 'dart:io';

import 'package:webdriver/sync_io.dart';

Future<WebElement> getElement(WebDriver driver, By by,
    {int duration = 5000, int checkInterval = 100}) async {
  var element;
  do {
    try {
      element = await driver.findElement(by);
      if (element != null) return element;
    } catch (_) {}
    sleep(Duration(milliseconds: checkInterval));
    duration -= checkInterval;
  } while (element == null && duration > 0);
  return element;
}
