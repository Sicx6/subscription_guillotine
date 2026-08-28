import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'subscription.dart';

class SubscriptionRepository {
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final path = p.join(await getDatabasesPath(), 'subscription_guillotine.db');
    _database = await openDatabase(
      path,
      version: 4,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
        CREATE TABLE subscriptions(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          price REAL NOT NULL,
          billing_date TEXT NOT NULL,
          recurrence TEXT NOT NULL DEFAULT 'monthly',
          reminder_days_before INTEGER NOT NULL DEFAULT 1,
          notification_id INTEGER NOT NULL,
          category TEXT NOT NULL DEFAULT 'other', status TEXT NOT NULL DEFAULT 'active',
          trial_end_date TEXT, cancellation_date TEXT, cancellation_reference TEXT,
          cancellation_url TEXT, cancellation_notes TEXT, receipt_path TEXT, proof_path TEXT,
          is_essential INTEGER NOT NULL DEFAULT 0,
          usage_level TEXT NOT NULL DEFAULT 'unknown',
          created_at TEXT NOT NULL
        )
      ''');
        await _createEventsTable(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE subscriptions ADD COLUMN recurrence TEXT NOT NULL DEFAULT 'monthly'",
          );
          await db.execute(
            'ALTER TABLE subscriptions ADD COLUMN reminder_days_before INTEGER NOT NULL DEFAULT 1',
          );
          await db.execute(
            'ALTER TABLE subscriptions ADD COLUMN notification_id INTEGER NOT NULL DEFAULT 0',
          );
          final existing = await db.query('subscriptions', columns: ['id']);
          for (final row in existing) {
            final id = row['id']! as String;
            await db.update(
              'subscriptions',
              {'notification_id': id.hashCode & 0x7fffffff},
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
        if (oldVersion < 3) {
          const columns = [
            "category TEXT NOT NULL DEFAULT 'other'",
            "status TEXT NOT NULL DEFAULT 'active'",
            'trial_end_date TEXT',
            'cancellation_date TEXT',
            'cancellation_reference TEXT',
            'cancellation_url TEXT',
            'cancellation_notes TEXT',
            'receipt_path TEXT',
            'proof_path TEXT'
          ];
          for (final column in columns) {
            await db.execute('ALTER TABLE subscriptions ADD COLUMN $column');
          }
          await _createEventsTable(db);
        }
        if (oldVersion < 4) {
          await db.execute(
              'ALTER TABLE subscriptions ADD COLUMN is_essential INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              "ALTER TABLE subscriptions ADD COLUMN usage_level TEXT NOT NULL DEFAULT 'unknown'");
        }
      },
    );
    return _database!;
  }

  Future<List<Subscription>> getAll() async {
    final rows = await (await _db).query(
      'subscriptions',
      orderBy: 'billing_date ASC',
    );
    return rows.map(Subscription.fromMap).toList();
  }

  Future<void> insert(Subscription subscription) async {
    await (await _db).insert(
      'subscriptions',
      subscription.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> update(Subscription subscription) async {
    final affectedRows = await (await _db).update(
      'subscriptions',
      subscription.toMap(),
      where: 'id = ?',
      whereArgs: [subscription.id],
    );
    if (affectedRows != 1) {
      throw StateError('Subscription ${subscription.id} was not found.');
    }
  }

  Future<void> delete(String id) async {
    final affectedRows = await (await _db).delete(
      'subscriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (affectedRows != 1) {
      throw StateError('Subscription $id was not found.');
    }
  }

  Future<void> addEvent(SubscriptionEvent event) async =>
      (await _db).insert('subscription_events', event.toMap()..remove('id'));

  Future<List<SubscriptionEvent>> getEvents(String subscriptionId) async =>
      (await (await _db).query('subscription_events',
              where: 'subscription_id = ?',
              whereArgs: [subscriptionId],
              orderBy: 'occurred_at DESC'))
          .map(SubscriptionEvent.fromMap)
          .toList();

  Future<Map<String, Object?>> exportData() async => {
        'version': 1,
        'subscriptions': await (await _db).query('subscriptions'),
        'events': await (await _db).query('subscription_events'),
      };

  Future<void> importData(Map<String, dynamic> data) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final raw in (data['subscriptions'] as List? ?? const [])) {
        await txn.insert('subscriptions', Map<String, Object?>.from(raw as Map),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final raw in (data['events'] as List? ?? const [])) {
        await txn.insert(
            'subscription_events', Map<String, Object?>.from(raw as Map),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}

Future<void> _createEventsTable(Database db) => db.execute('''
  CREATE TABLE IF NOT EXISTS subscription_events(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    subscription_id TEXT NOT NULL,
    type TEXT NOT NULL,
    amount REAL,
    occurred_at TEXT NOT NULL,
    note TEXT,
    FOREIGN KEY(subscription_id) REFERENCES subscriptions(id) ON DELETE CASCADE
  )
''');
