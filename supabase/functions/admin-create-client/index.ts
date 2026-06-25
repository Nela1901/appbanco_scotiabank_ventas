/// <reference types="https://esm.sh/@supabase/functions-js/src/edge-runtime.d.ts" />

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Faltan variables de entorno (SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY)')
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)
    const { nombres, email, codigo, password, perfil } = await req.json()

    if (!nombres || !email || !codigo || !password) {
      throw new Error('Faltan campos obligatorios (nombres, email, codigo, password)')
    }

    const dni = String(codigo).trim()
    const emailVirtual = `${dni}@clientes.scotiabank.com.pe`
    const nombreCompleto = nombres.toUpperCase()
    const partesNombre = nombreCompleto.split(/\s+/)
    const primerNombre = partesNombre[0] ?? nombreCompleto
    const apellidos = partesNombre.length > 1 ? partesNombre.slice(1).join(' ') : ''

    const { data: existingClient } = await supabaseAdmin
      .from('clientes')
      .select('id')
      .or(`dni.eq.${dni},numero_documento.eq.${dni}`)
      .maybeSingle()

    if (existingClient) {
      throw new Error('El DNI ingresado ya se encuentra registrado como cliente.')
    }

    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: emailVirtual,
      password: password,
      email_confirm: true,
      user_metadata: {
        display_name: nombreCompleto,
        dni: dni,
        real_email: email,
        rol: perfil ?? 'cliente',
      },
    })

    if (authError) throw authError

    const { error: dbError } = await supabaseAdmin
      .from('clientes')
      .insert({
        id: authData.user.id,
        user_id: authData.user.id,
        nombre: nombreCompleto,
        nombres: primerNombre,
        apellidos: apellidos,
        dni: dni,
        numero_documento: dni,
        email: email,
        rol: perfil ?? 'cliente',
        fecha_registro: new Date().toISOString(),
      })

    if (dbError) {
      await supabaseAdmin.auth.admin.deleteUser(authData.user.id)
      throw dbError
    }

    return new Response(
      JSON.stringify({ message: 'Cliente creado exitosamente', user_id: authData.user.id }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Error desconocido'
    return new Response(
      JSON.stringify({ error: message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    )
  }
})
