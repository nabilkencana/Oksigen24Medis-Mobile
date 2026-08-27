import 'package:flutter_test/flutter_test.dart';
import 'package:oksigen24medis_mobile2/core/services/printer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrinterService Unit Tests', () {
    test('Singleton instance test', () {
      final instance1 = PrinterService();
      final instance2 = PrinterService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('Initial connection status is disconnected', () async {
      final service = PrinterService();
      expect(service.status, equals(PrinterConnectionStatus.disconnected));
      expect(service.selectedDevice, isNull);
    });

    test('AppPrinterDevice compatibility getters', () {
      final dev = AppPrinterDevice(
        name: 'RPP02N',
        address: '00:11:22:33:44:55',
        nativeDevice: null,
        isBle: true,
      );

      expect(dev.name, equals('RPP02N'));
      expect(dev.address, equals('00:11:22:33:44:55'));
      expect(dev.macAdress, equals('00:11:22:33:44:55'));
      expect(dev.macAddress, equals('00:11:22:33:44:55'));
      expect(dev.isBle, isTrue);
    });
  });
}
