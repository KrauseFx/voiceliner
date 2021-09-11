import 'package:binder/binder.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:voice_outliner/data/outline.dart';

final dbRepositoryRef = LogicRef((scope) => DBRepository(scope));
final dbReadyRef = StateRef(false);
final dbRef = StateRef<Database?>(null);

final Uuid uuid = Uuid();

class DBRepository with Logic implements Loadable, Disposable {
  DBRepository(this.scope);

  Database? get _database => read(dbRef);

  @override
  Future<void> dispose() async {
    await _database?.close();
  }

  Future<void> _onCreate(Database db, int version) async {
    final Batch batch = db.batch();
    batch.execute('''
CREATE TABLE outline (
      id TEXT PRIMARY KEY NOT NULL, 
      name TEXT NOT NULL,
      date_created INTEGER NOT NULL
)''');
    batch.execute('''
CREATE TABLE note (
      id TEXT PRIMARY KEY NOT NULL, 
      file_path TEXT NOT NULL,
      date_created INTEGER NOT NULL,
      duration INTEGER,
      transcript TEXT,
      parent_note_id TEXT,
      outline_id TEXT NOT NULL,
      index INTEGER NOT NULL,
      FOREIGN KEY(parent_note_id) REFERENCES note,
      FOREIGN KEY(outline_id) REFERENCES outline
)''');
    await batch.commit(noResult: true);
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute("PRAGMA foreign_keys=ON");
  }

  Future<void> _onOpen(Database db) async {
    write(dbReadyRef, true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    throw ("Need to upgrade db version $oldVersion to $newVersion");
  }

  Future<List<Map<String, dynamic>>> getOutlines() async {
    final result = await _database!.query("outline");
    return result;
  }

  Future<List<Map<String, dynamic>>> getNotesForOutline(Outline outline) async {
    final result = await _database!
        .query("note", where: "outline_id = ?", whereArgs: [outline.id]);
    return result;
  }

  @override
  Future<void> load() async {
    final db = await openDatabase("voice_outliner.db",
        version: 1,
        onCreate: _onCreate,
        onConfigure: _onConfigure,
        onOpen: _onOpen,
        onUpgrade: _onUpgrade);
    write(dbRef, db);
  }

  @override
  final Scope scope;
}
