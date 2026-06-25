/// <reference types="https://raw.githubusercontent.com/supabase/functions-js/main/src/edge-runtime.d.ts" />

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.1?bundle&target=deno'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  // Manejo de pre-flight CORS (necesario para llamadas desde Flutter)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Inicializamos el cliente con la Service Role Key para tener permisos de ADMIN
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Obtenemos los datos enviados desde la App (AuthService.crearAsesor)
    const body = await req.json()
    const { codigo, nombres, apellidos, perfil, agencia_id, solicitud_id } = body

    const cleanCodigo = String(codigo).trim().toUpperCase();

    if (!cleanCodigo || !nombres || !apellidos || !perfil) {
      throw new Error('Faltan campos requeridos')
    }


    // 0. Verificar si el código de empleado ya existe en nuestra tabla
    const { data: existingAsesor, error: checkError } = await supabaseAdmin
      .from('asesores_negocio')
      .select('id, user_id') // Seleccionamos user_id para el retorno
      .eq('codigo_empleado', cleanCodigo)
      .maybeSingle();

    if (checkError) console.error('Error checking existing asesor:', checkError);

    if (existingAsesor) {
      // Si el usuario ya existe, verificamos si hay una solicitud pendiente para completar
      if (solicitud_id) {
        await supabaseAdmin
          .from('solicitudes_acceso')
          .update({ estado: 'completada' })
          .eq('id', solicitud_id);
        
        return new Response(
          JSON.stringify({ message: `El usuario con código ${cleanCodigo} ya existía. Solicitud marcada como completada.`, user_id: existingAsesor.user_id }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        );
      } else {
        // Si no hay solicitud, es un intento directo de crear un duplicado
        return new Response(
          JSON.stringify({ error: `El código ${cleanCodigo} ya está en uso en la tabla de asesores.` }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        );
      }
    }
    
    // Formateamos el email institucional
    const email = `${cleanCodigo}@scotiabank.com.pe`
    // Supabase Auth requiere mínimo 6 caracteres. Si el código es más corto, lo rellenamos.
    const temporaryPassword = cleanCodigo.length < 6 ? cleanCodigo.padEnd(6, '0') : cleanCodigo;

    // 1. Crear el usuario en Supabase Authentication
    const { data, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: email,
      password: temporaryPassword,
      email_confirm: true,
      user_metadata: { 
        nombres: nombres, 
        apellidos: apellidos,
        codigo: cleanCodigo // Enviamos el código también en metadata por si hay un trigger
      }
    })

    if (authError) {
      console.error('CRITICAL: Supabase Auth Error:', authError);
      // Si el error es que el usuario ya existe en Auth, lo atrapamos aquí
      if (authError.message.includes("already registered") || authError.status === 422) {
         return new Response(
          JSON.stringify({ error: 'Este correo ya tiene una cuenta de autenticación activa.' }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        );
      }
      throw authError; // Esto caerá en el catch general
    }
    const user = data.user;

    // 1.1 Disparar el envío de correo de recuperación para que el usuario defina su clave
    await supabaseAdmin.auth.resetPasswordForEmail(email);

    // 2. Vincular el nuevo usuario con la tabla 'asesores_negocio'
    const { error: dbError } = await supabaseAdmin
      .from('asesores_negocio')
      .insert({
        user_id: user.id,
        codigo_empleado: cleanCodigo,
        nombres: nombres,
        apellidos: apellidos,
        perfil: perfil,
        agencia_id: (agencia_id === '' || agencia_id === null || agencia_id === 'AG-001') ? null : agencia_id
      })

    if (dbError) {
      // Si falla la inserción en la tabla, borramos el usuario de Auth para evitar duplicados huérfanos
      await supabaseAdmin.auth.admin.deleteUser(user.id)
      throw dbError
    }

    // 3. Si existe una solicitud previa, marcarla como completada
    if (solicitud_id) {
      await supabaseAdmin
        .from('solicitudes_acceso')
        .update({ estado: 'completada' })
        .eq('id', solicitud_id)
    }

    return new Response(
      JSON.stringify({ 
        message: `Acceso concedido. El asesor ya puede ingresar. Usuario: ${cleanCodigo}. Contraseña temporal: ${temporaryPassword}`, 
        user_id: user.id 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('Function execution error:', error.message || error);
    return new Response(
      JSON.stringify({ 
        error: error.message || 'Error inesperado en el servidor',
        details: error.toString()
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})

/* 
  To invoke locally:
  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/admin-create-user' \
    --header 'Authorization: Bearer TU_ANON_KEY' \
    --header 'Content-Type: application/json' \
    --data '{"codigo":"EMP001","nombres":"Juan","apellidos":"Perez","perfil":"operador"}'
*/
