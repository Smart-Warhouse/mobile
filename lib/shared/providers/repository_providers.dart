import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../features/alerts/data/events_repository.dart';
import '../../features/fleet/data/fleet_repository.dart';
import '../../features/map/data/map_repository.dart';
import '../../features/pallets/data/pallets_repository.dart';
import '../../features/tasks/data/tasks_repository.dart';

final fleetRepositoryProvider = Provider<FleetRepository>(
  (ref) => FleetRepository(ref.watch(apiDioProvider)),
);

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(ref.watch(apiDioProvider)),
);

final tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) => TasksRepository(ref.watch(apiDioProvider)),
);

final palletsRepositoryProvider = Provider<PalletsRepository>(
  (ref) => PalletsRepository(ref.watch(apiDioProvider)),
);

final mapRepositoryProvider = Provider<MapRepository>(
  (ref) => MapRepository(ref.watch(apiDioProvider)),
);
