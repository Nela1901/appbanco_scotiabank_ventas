import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';

/// Script para cargar prospectos/clientes rápidamente
/// Ejecución: dart scripts/seed_data.dart
void main() async {
  final supabase = SupabaseClient(ApiConfig.supabaseUrl, ApiConfig.supabaseAnonKey);

  print('Iniciando carga masiva...');

  final listadoClientes = [
    {'nombre': 'Carlos Alcántara', 'tipo_gestion': 'renovacion', 'estado': 'pendiente'},
    {'nombre': 'Gianella Neyra', 'tipo_gestion': 'nuevo', 'estado': 'visitado'},
    {'nombre': 'Ricardo Morán', 'tipo_gestion': 'cobranza', 'estado': 'pendiente'},
    {'nombre': 'Wendy Ramos', 'tipo_gestion': 'renovacion', 'estado': 'visitado'},
    {'nombre': 'Carlos Carlín', 'tipo_gestion': 'nuevo', 'estado': 'pendiente'},
    {'nombre': 'Johanna San Miguel', 'tipo_gestion': 'cobranza', 'estado': 'visitado'},
  ];

  try {
    await supabase.from('clientes').insert(listadoClientes);
    print('✅ ¡Éxito! Se insertaron ${listadoClientes.length} registros.');
  } catch (e) {
    print('❌ Error al insertar: $e');
  }
}