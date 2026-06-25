import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:appbanco_scotiabank_ventas/config/api_config.dart';
import 'package:appbanco_scotiabank_ventas/viewmodel/auth_oficial_viewmodel.dart';
import 'package:appbanco_scotiabank_ventas/viewmodel/cartera_viewmodel.dart';
import 'package:appbanco_scotiabank_ventas/navigation/app_routes.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// RF-02: Implementación de almacenamiento seguro para tokens de Supabase
class SecureLocalStorage extends LocalStorage {
  final _storage = const FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> removePersistedSession() => _storage.delete(key: 'supabase_auth_token');

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: 'supabase_auth_token');

  @override
  Future<String?> accessToken() => _storage.read(key: 'supabase_auth_token');

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: 'supabase_auth_token', value: persistSessionString);
}

// RF-13: Tarea programada de sincronización nocturna
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Inicializar Supabase en el isolate de background
      await Supabase.initialize(
        url: ApiConfig.supabaseUrl,
        anonKey: ApiConfig.supabaseAnonKey,
      );

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return Future.value(true);

      // RF-09/HU-05: Descarga de datos para "mañana"
      final response = await supabase
          .from('clientes')
          .select()
          .eq('oficial_id', user.id);

      final clientesCount = (response as List).length;

      // RF-14: Notificación local al completar
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'sync_channel', 'Sincronización',
        importance: Importance.high, priority: Priority.high,
      );
      const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
      
      await FlutterLocalNotificationsPlugin().show(
        0, 
        'Cartera Lista', 
        'Tu cartera de mañana está lista: $clientesCount clientes.', 
        platformDetails
      );

      return Future.value(true);
    } catch (e) {
      return Future.value(false); // Workmanager reintentará según política
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Validación de seguridad: Verificar que las variables de entorno se cargaron correctamente
  if (ApiConfig.supabaseUrl.isEmpty || ApiConfig.supabaseAnonKey.isEmpty) {
    throw Exception(
      'ERROR: No se detectaron las credenciales de Supabase.\n'
      'Asegúrate de tener el archivo env.json y de iniciar la app usando el perfil "App Banco (Dev)" en VS Code.'
    );
  }

  await Supabase.initialize(
    url: ApiConfig.supabaseUrl,
    anonKey: ApiConfig.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(localStorage: SecureLocalStorage()), // RF-02
  );

  // Inicializar Workmanager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  
  // Calcular delay inicial para las 22:00 horas
  final now = DateTime.now();
  var scheduledTime = DateTime(now.year, now.month, now.day, 22, 0);
  if (scheduledTime.isBefore(now)) {
    scheduledTime = scheduledTime.add(const Duration(days: 1));
  }
  final initialDelay = scheduledTime.difference(now);

  // Registrar tarea diaria
  await Workmanager().registerPeriodicTask(
    "sync-nocturno-cartera",
    "syncTask",
    frequency: const Duration(days: 1),
    initialDelay: initialDelay,
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
    backoffPolicy: BackoffPolicy.exponential,
  );

  // Verificamos si ya existe una sesión activa para decidir la ruta inicial
  final session = Supabase.instance.client.auth.currentSession;

  runApp(MyApp(isLoggedIn: session != null));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthOficialViewModel()),
        ChangeNotifierProvider(create: (_) => CarteraViewModel()),
      ],
      child: MaterialApp(
        title: 'Scotiabank Ventas',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFED1C24)),
          useMaterial3: true,
        ),
        // Si está logueado, vamos directo a la cartera (asumiendo que '/' o AppRoutes.home es la cartera)
        initialRoute: isLoggedIn ? AppRoutes.home : AppRoutes.login, 
        routes: AppRoutes.routes,
        // HU-01: Detector de inactividad global
        builder: (context, child) {
          final authVM = Provider.of<AuthOficialViewModel>(context, listen: false);
          
          // Optimizamos: Solo escuchamos el cambio de 'isOffline' para el banner
          // y no a todo el ViewModel de la cartera, evitando rebuilds globales innecesarios.
          final isOffline = context.select<CarteraViewModel, bool>((vm) => vm.isOffline);

          return Column(
            children: [
              if (isOffline) // Flujo 3: Banner de Modo offline
                Container(
                  color: Colors.orange,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: const Center(child: Text("Modo offline activo", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                ),
              Expanded(
                child: Listener(
                  onPointerDown: (_) => authVM.recordActivity(),
                  child: child!,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
