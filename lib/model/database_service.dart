import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'scotia_ventas_v3.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tabla local para Borradores (HU-18 / RF-49)
        await db.execute('''
          CREATE TABLE solicitudes_borrador (
            id TEXT PRIMARY KEY,
            cliente_id TEXT,
            cliente_nombre TEXT,
            paso_actual INTEGER,
            datos_json TEXT,
            monto_solicitado REAL,
            asesor_id TEXT,
            updated_at INTEGER
          )
        ''');

        // Tabla local para Cola Offline (Flujo 3)
        await db.execute('''
          CREATE TABLE visitas_pendientes (
            id TEXT PRIMARY KEY,
            cartero_id TEXT,
            resultado TEXT,
            observacion TEXT,
            timestamp_visita TEXT,
            lat REAL,
            lng REAL,
            pendiente_sync INTEGER DEFAULT 1
          )
        ''');

        // Tabla local para Cola de Solicitudes (Flujo 3)
        await db.execute('''
          CREATE TABLE solicitudes_pendientes (
            id TEXT PRIMARY KEY,
            datos_json TEXT,
            created_at TEXT
          )
        ''');
      },
    );
  }

  // --- GESTIÓN DE BORRADORES (HU-18) ---

  Future<void> saveBorrador(Map<String, dynamic> borrador) async {
    final db = await database;
    await db.insert(
      'solicitudes_borrador',
      borrador,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getBorradores(String asesorId) async {
    final db = await database;
    return await db.query(
      'solicitudes_borrador',
      where: 'asesor_id = ?',
      whereArgs: [asesorId],
      orderBy: 'updated_at DESC',
    );
  }

  Future<void> deleteBorrador(String id) async {
    final db = await database;
    await db.delete('solicitudes_borrador', where: 'id = ?', whereArgs: [id]);
  }

  // --- GESTIÓN DE COLA OFFLINE (Flujo 3) ---

  Future<void> saveVisitaPendiente(Map<String, dynamic> visita) async {
    final db = await database;
    await db.insert('visitas_pendientes', visita);
  }

  Future<List<Map<String, dynamic>>> getVisitasPendientes() async {
    final db = await database;
    return await db.query('visitas_pendientes', where: 'pendiente_sync = 1');
  }

  Future<void> marcarSincronizada(String id) async {
    final db = await database;
    await db.delete('visitas_pendientes', where: 'id = ?', whereArgs: [id]);
  }

  // --- GESTIÓN DE SOLICITUDES PENDIENTES ---

  Future<void> saveSolicitudPendiente(Map<String, dynamic> solicitud) async {
    final db = await database;
    await db.insert('solicitudes_pendientes', solicitud);
  }

  Future<List<Map<String, dynamic>>> getSolicitudesPendientes() async {
    final db = await database;
    return await db.query('solicitudes_pendientes');
  }

  Future<void> marcarSolicitudSincronizada(String id) async {
    final db = await database;
    await db.delete('solicitudes_pendientes', where: 'id = ?', whereArgs: [id]);
  }
}