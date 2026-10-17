// JSON payloads copied from docs/02-api-contract.md §2 (Shapes).

const userJson = {
  'id': 1,
  'username': 'operator',
  'name': 'Floor Operator',
  'role': 'operator',
};

const viewerJson = {
  'id': 3,
  'username': 'viewer',
  'name': 'Floor Viewer',
  'role': 'viewer',
};

const eventJson = {
  'id': 551,
  'robot_id': 'fl1',
  'type': 'safety',
  'severity': 'critical',
  'code': 'person_detected',
  'message': 'Person detected 0.8 m ahead, stopped',
  'x': 2.1,
  'y': 1.3,
  'created_at': '2026-10-16T19:50:00Z',
};

const robotJson = {
  'id': 'fl1',
  'name': 'Forklift 1',
  'ip': '192.168.50.11',
  'online': true,
  'enabled': true,
  'mode': 'busy',
  'safety_state': 'normal',
  'battery_pct': 82.5,
  'x': 1.20,
  'y': 0.45,
  'yaw': 1.57,
  'speed': 0.22,
  'fork_height_mm': 0,
  'carrying_pallet_id': 7,
  'current_task_id': 'T-0042',
  'route': ['N3', 'N4', 'N7'],
  'path': [
    [1.2, 0.45],
    [1.2, 1.0],
  ],
  'last_event': eventJson,
  'last_seen': '2026-10-16T19:50:00Z',
  'simulated': true,
};

const spareRobotJson = {
  'id': 'fl4',
  'name': 'Forklift 4',
  'online': false,
  'enabled': false,
  'mode': 'offline',
  'safety_state': 'normal',
  'battery_pct': 100,
  'x': 0,
  'y': 0,
  'yaw': 0,
  'speed': 0,
  'fork_height_mm': 0,
  'carrying_pallet_id': null,
  'current_task_id': null,
  'route': <String>[],
  'path': <List<double>>[],
  'last_event': null,
  'last_seen': null,
  'simulated': true,
};

const taskJson = {
  'id': 'T-0042',
  'type': 'move_pallet',
  'pallet_id': 7,
  'pallet_sku': 'SKU-0007',
  'from_location_id': 3,
  'from_code': 'R1-L2',
  'to_location_id': 12,
  'to_code': 'DOCK-OUT-1',
  'robot_id': 'fl2',
  'priority': 2,
  'status': 'to_pickup',
  'route': ['N3', 'N4', 'N7'],
  'created_at': '2026-10-16T19:40:00Z',
  'started_at': '2026-10-16T19:41:00Z',
  'finished_at': null,
  'fail_reason': null,
  'created_by': 'operator',
};

const locationJson = {
  'id': 3,
  'code': 'R1-L2',
  'type': 'rack',
  'x': 1.20,
  'y': 0.45,
  'yaw': 1.57,
  'level': 1,
  'height_mm': 60,
  'aruco_id': 23,
  'node_id': 'N3',
  'occupied': true,
  'pallet_id': 7,
};

const palletJson = {
  'id': 7,
  'aruco_id': 7,
  'sku': 'SKU-0007',
  'product_name': 'Bottled water',
  'quantity': 24,
  'weight_g': 180,
  'location_id': 3,
  'location_code': 'R1-L2',
  'status': 'stored',
};

const moveJson = {
  'id': 90,
  'pallet_id': 7,
  'from_code': 'R1-L2',
  'to_code': 'DOCK-OUT-1',
  'task_id': 'T-0042',
  'moved_at': '2026-10-16T19:45:00Z',
};

const fleetJson = {
  'estop': false,
  'estop_by': null,
  'estop_at': null,
  'robots_online': 3,
  'robots_total': 4,
  'queued_tasks': 2,
  'active_tasks': 3,
};

const reservationJson = {
  'segment_id': 'A11--R1-W1',
  'robot_id': 'fl1',
  'since': '2026-10-16T19:49:00Z',
};

const mapJson = {
  'width_m': 4.0,
  'height_m': 3.0,
  'resolution_m': 0.05,
  'nodes': [
    {'id': 'A11', 'x': 0.5, 'y': 0.5},
    {'id': 'R1-W1', 'x': 1.5, 'y': 0.5},
  ],
  'edges': [
    {
      'id': 'A11--R1-W1',
      'a': 'A11',
      'b': 'R1-W1',
      'length': 1.0,
      'bidirectional': true,
    },
  ],
  'zones': [
    {
      'id': 'Z1',
      'kind': 'pedestrian',
      'label': 'Walkway',
      'polygon': [
        [0, 2.5],
        [4, 2.5],
        [4, 3],
        [0, 3],
      ],
    },
  ],
  'locations': [locationJson],
};

Map<String, dynamic> snapshotFrame({
  List<Map<String, dynamic>> robots = const [robotJson, spareRobotJson],
  Map<String, dynamic> fleet = fleetJson,
}) => {
  'type': 'snapshot',
  'ts': '2026-10-16T19:50:00Z',
  'data': {
    'robots': robots,
    'reservations': [reservationJson],
    'fleet': fleet,
  },
};
