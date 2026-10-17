import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/alerts/presentation/alerts_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/providers/session_controller.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/drive/presentation/drive_screen.dart';
import '../../features/fleet/presentation/fleet_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/pallets/data/models/pallet_models.dart';
import '../../features/pallets/presentation/inventory_screen.dart';
import '../../features/pallets/presentation/pallet_detail_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/tasks/presentation/move_pallet_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../shared/widgets/floor_frame.dart';
import '../../shared/widgets/tab_shell.dart';
import 'routes.dart';

/// The single auth guard: bootstrapping → splash, signed out → login,
/// signed in → never on splash/login.
String? authRedirect(SessionState session, String location) {
  final public = location == Routes.login || location == Routes.splash;
  return switch (session) {
    SessionBootstrapping() => location == Routes.splash ? null : Routes.splash,
    SignedOut() => location == Routes.login ? null : Routes.login,
    SignedIn() => public ? Routes.fleet : null,
  };
}

/// Bridges session changes to GoRouter's refreshListenable.
class _SessionListenable extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable();
  ref.listen(sessionControllerProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      ref.read(sessionControllerProvider),
      state.matchedLocation,
    ),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => FloorFrame(child: child),
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => TabShell(shell: shell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: Routes.fleet,
                    builder: (_, _) => const FleetScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: Routes.map,
                    builder: (_, _) => const MapScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: Routes.tasks,
                    builder: (_, _) => const TasksScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: Routes.inventory,
                    builder: (_, _) => const InventoryScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: Routes.alerts,
                    builder: (_, _) => const AlertsScreen(),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: Routes.move,
            builder: (_, state) => MovePalletScreen(
              initialPallet: state.extra is Pallet
                  ? state.extra as Pallet
                  : null,
            ),
          ),
          GoRoute(
            path: Routes.pallet,
            builder: (_, state) => PalletDetailScreen(
              palletId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              pallet: state.extra is Pallet ? state.extra as Pallet : null,
            ),
          ),
          GoRoute(
            path: Routes.drive,
            builder: (_, state) =>
                DriveScreen(initialRobotId: state.uri.queryParameters['robot']),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (_, _) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
