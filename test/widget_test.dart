import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/constants.dart';

void main() {
  test('App metadata smoke test', () {
    expect(appName, 'JA_DUT_Info');
    expect(appVersion, '2.4.1');
    expect(appId, 'ja.project.l10dutinfo.v2');
  });
}
