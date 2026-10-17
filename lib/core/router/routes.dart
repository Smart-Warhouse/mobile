/// Every path in the app. Navigate only through these constants/builders.
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';

  // Tabs.
  static const fleet = '/fleet';
  static const map = '/map';
  static const tasks = '/tasks';
  static const inventory = '/inventory';
  static const alerts = '/alerts';

  // Pushed over the tabs (STOP ALL stays visible).
  static const move = '/move';
  static const pallet = '/pallet/:id';
  static const drive = '/drive';
  static const settings = '/settings';

  static String palletOf(int id) => '/pallet/$id';

  static String driveOf(String? robotId) => robotId == null
      ? drive
      : Uri(path: drive, queryParameters: {'robot': robotId}).toString();
}
