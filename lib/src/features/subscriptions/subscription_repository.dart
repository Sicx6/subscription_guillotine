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
      version: 2,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE subscriptions(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          price REAL NOT NULL,
          billing_date TEXT NOT NULL,
          recurrence TEXT NOT NULL DEFAULT 'monthly',
          reminder_days_before INTEGER NOT NULL DEFAULT 1,
          notification_id INTEGER NOT NULL,
          created_at TEXT NOT NULL
        )
      '''),
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
}
