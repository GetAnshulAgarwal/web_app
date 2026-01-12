
enum WarehouseMode {
  testing,
  production,
}

class WarehouseModeController {
  static const WarehouseMode CURRENT_MODE = WarehouseMode.production;
  static bool get isTestingMode => CURRENT_MODE == WarehouseMode.testing;
  static bool get isProductionMode => CURRENT_MODE == WarehouseMode.production;

  static String get modeDisplayName => isTestingMode ? ' TESTING' : ' PRODUCTION';

  static void printCurrentMode() {
    print('=' * 50);
    print(' WAREHOUSE MODE: ${modeDisplayName}');
    print('=' * 50);
  }
}