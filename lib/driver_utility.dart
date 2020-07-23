import 'dart:io';

import 'package:webdriver/sync_io.dart';
import 'package:Spogit/utility.dart';

Future<WebElement> getElement(WebDriver driver, By by,
    {int duration = 5000, int checkInterval = 100}) async {
  var elements = <WebElement>[];
  do {
    try {
      elements = await driver.findElements(by);
      if (elements.isNotEmpty) return elements.first;
    } catch (_) {}
    await awaitSleep(Duration(milliseconds: checkInterval));
    duration -= checkInterval;
  } while (elements.isEmpty && duration > 0);
  return elements.safeFirst;
}
