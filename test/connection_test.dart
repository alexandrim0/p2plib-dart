import 'dart:core';
import 'package:p2plib/p2plib.dart';
import 'package:test/test.dart';

main() async {
  test('restart connection', () async {
    final connection = UdpConnection(ipv4Port: 4232, ipv6Port: 4233);
    await connection.start();
    await connection.stop();

    await connection.start();
    await connection.stop();
  });
}
