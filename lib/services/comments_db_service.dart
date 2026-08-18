// lib/services/comments_db_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class CommentsDBService {
  static final CommentsDBService _instance = CommentsDBService._internal();
  factory CommentsDBService() => _instance;
  CommentsDBService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> deleteComment(String fixtureId, String commentId) async {
    final db = await database;
    await db.delete(
      'comments',
      where: 'fixtureId = ? AND id = ?',
      whereArgs: [fixtureId, commentId],
    );
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'comments_cache.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE comments(
            id TEXT PRIMARY KEY,
            fixtureId TEXT NOT NULL,
            userId TEXT NOT NULL,
            username TEXT NOT NULL,
            comment TEXT NOT NULL,
            selection TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            isSynced INTEGER DEFAULT 1
          )
        ''');
        await db.execute('CREATE INDEX idx_fixture ON comments(fixtureId)');
        await db.execute(
          'CREATE INDEX idx_timestamp ON comments(timestamp DESC)',
        );
      },
    );
  }

  Future<void> saveComments(
    String fixtureId,
    List<Map<String, dynamic>> comments,
  ) async {
    final db = await database;
    Batch batch = db.batch();

    for (var comment in comments) {
      batch.insert('comments', {
        'id': comment['id'],
        'fixtureId': fixtureId,
        'userId': comment['userId'],
        'username': comment['username'],
        'comment': comment['comment'],
        'selection': comment['selection'],
        'timestamp': comment['timestamp'],
        'isSynced': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getCachedComments(String fixtureId) async {
    final db = await database;
    return await db.query(
      'comments',
      where: 'fixtureId = ?',
      whereArgs: [fixtureId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<void> addComment(
    String fixtureId,
    Map<String, dynamic> comment,
  ) async {
    final db = await database;
    await db.insert('comments', {
      'id': comment['id'],
      'fixtureId': fixtureId,
      'userId': comment['userId'],
      'username': comment['username'],
      'comment': comment['comment'],
      'selection': comment['selection'],
      'timestamp': comment['timestamp'],
      'isSynced': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> cleanOldComments(String fixtureId) async {
    final db = await database;
    await db.delete(
      'comments',
      where:
          'fixtureId = ? AND id NOT IN (SELECT id FROM comments WHERE fixtureId = ? ORDER BY timestamp DESC LIMIT 500)',
      whereArgs: [fixtureId, fixtureId],
    );
  }
}
