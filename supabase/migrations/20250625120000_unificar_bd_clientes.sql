-- =============================================================================
-- Unificación BD Clientes → BD Ventas (appbanco_scotiabank_ventas)
-- Ejecutar en el SQL Editor de Supabase (proyecto ventas) o via: supabase db push
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. EXTENDER tabla clientes (ventas usa nombres/numero_documento; clientes usa nombre/dni)
-- -----------------------------------------------------------------------------
ALTER TABLE public.clientes
  ADD COLUMN IF NOT EXISTS dni              TEXT,
  ADD COLUMN IF NOT EXISTS nombre           TEXT,
  ADD COLUMN IF NOT EXISTS email            TEXT,
  ADD COLUMN IF NOT EXISTS rol              TEXT DEFAULT 'cliente',
  ADD COLUMN IF NOT EXISTS fecha_registro   TIMESTAMPTZ DEFAULT now(),
  ADD COLUMN IF NOT EXISTS user_id          UUID REFERENCES auth.users(id);

-- Sincronizar datos existentes entre convenciones de ventas y clientes
UPDATE public.clientes SET dni = numero_documento
  WHERE dni IS NULL AND numero_documento IS NOT NULL;

UPDATE public.clientes SET numero_documento = dni
  WHERE numero_documento IS NULL AND dni IS NOT NULL;

UPDATE public.clientes SET nombre = trim(concat_ws(' ', nombres, apellidos))
  WHERE nombre IS NULL AND (nombres IS NOT NULL OR apellidos IS NOT NULL);

UPDATE public.clientes SET nombres = split_part(nombre, ' ', 1)
  WHERE nombres IS NULL AND nombre IS NOT NULL;

UPDATE public.clientes SET user_id = id
  WHERE user_id IS NULL
    AND id IN (SELECT id FROM auth.users);

CREATE UNIQUE INDEX IF NOT EXISTS clientes_dni_unique
  ON public.clientes (dni) WHERE dni IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS clientes_numero_documento_unique
  ON public.clientes (numero_documento) WHERE numero_documento IS NOT NULL;

-- Trigger: mantener dni ↔ numero_documento y nombre ↔ nombres sincronizados
CREATE OR REPLACE FUNCTION public.sync_cliente_campos()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.dni IS NOT NULL AND (NEW.numero_documento IS NULL OR NEW.numero_documento = '') THEN
    NEW.numero_documento := NEW.dni;
  ELSIF NEW.numero_documento IS NOT NULL AND (NEW.dni IS NULL OR NEW.dni = '') THEN
    NEW.dni := NEW.numero_documento;
  END IF;

  IF NEW.nombre IS NOT NULL AND (NEW.nombres IS NULL OR NEW.nombres = '') THEN
    NEW.nombres := NEW.nombre;
  ELSIF NEW.nombres IS NOT NULL AND (NEW.nombre IS NULL OR NEW.nombre = '') THEN
    NEW.nombre := trim(concat_ws(' ', NEW.nombres, NEW.apellidos));
  END IF;

  IF NEW.user_id IS NULL AND NEW.id IN (SELECT id FROM auth.users) THEN
    NEW.user_id := NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_cliente_campos ON public.clientes;
CREATE TRIGGER trg_sync_cliente_campos
  BEFORE INSERT OR UPDATE ON public.clientes
  FOR EACH ROW EXECUTE FUNCTION public.sync_cliente_campos();

-- -----------------------------------------------------------------------------
-- 2. TABLAS BANCARIAS (esquema idéntico a appbanco_scotiabank_cliente)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cuentas (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id    UUID REFERENCES public.clientes(id) ON DELETE CASCADE,
  tipo          TEXT NOT NULL,
  saldo         NUMERIC DEFAULT 0.00,
  moneda        TEXT DEFAULT 'PEN',
  numero_cuenta TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS public.movimientos (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cuenta_id   UUID REFERENCES public.cuentas(id) ON DELETE CASCADE,
  descripcion TEXT NOT NULL,
  monto       NUMERIC NOT NULL,
  tipo        TEXT NOT NULL,
  fecha       TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.prestamos (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id       UUID REFERENCES public.clientes(id) ON DELETE CASCADE,
  monto_total      NUMERIC NOT NULL,
  saldo_pendiente  NUMERIC NOT NULL,
  cuotas_totales   INTEGER NOT NULL,
  cuotas_pagadas   INTEGER DEFAULT 0,
  tasa_interes     NUMERIC,
  estado           TEXT DEFAULT 'Activo'
);

CREATE TABLE IF NOT EXISTS public.cuotas_prestamo (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prestamo_id       UUID REFERENCES public.prestamos(id) ON DELETE CASCADE,
  numero_cuota      INTEGER NOT NULL,
  monto_cuota       NUMERIC NOT NULL,
  fecha_vencimiento DATE NOT NULL,
  estado            TEXT DEFAULT 'Pendiente',
  fecha_pago        TIMESTAMPTZ
);

-- Vincular préstamos con solicitudes de crédito (flujo end-to-end)
ALTER TABLE public.prestamos
  ADD COLUMN IF NOT EXISTS solicitud_id UUID REFERENCES public.solicitudes_credito(id);

-- -----------------------------------------------------------------------------
-- 3. FLUJO: solicitud desde App Clientes → cartera_diaria del asesor
-- -----------------------------------------------------------------------------
ALTER TABLE public.solicitudes_credito
  ADD COLUMN IF NOT EXISTS canal_origen TEXT DEFAULT 'asesor';

CREATE OR REPLACE FUNCTION public.asignar_solicitud_a_cartera()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.estado IN ('enviado', 'ENVIADO') AND NEW.canal_origen = 'cliente' THEN
    INSERT INTO public.cartera_diaria (
      cliente_id,
      asesor_id,
      solicitud_id,
      tipo_gestion,
      prioridad,
      score_prioridad,
      monto,
      fecha_asignacion,
      estado_visita
    )
    SELECT
      NEW.cliente_id,
      NEW.asesor_id,
      NEW.id,
      'NUEVA SOLICITUD',
      COALESCE(NEW.prioridad, 'NORMAL'),
      5,
      COALESCE(NEW.monto_solicitado, NEW.monto, 0),
      CURRENT_DATE,
      'pendiente'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.cartera_diaria cd
      WHERE cd.solicitud_id = NEW.id
        AND cd.fecha_asignacion = CURRENT_DATE
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_solicitud_a_cartera ON public.solicitudes_credito;
CREATE TRIGGER trg_solicitud_a_cartera
  AFTER INSERT OR UPDATE OF estado, canal_origen ON public.solicitudes_credito
  FOR EACH ROW EXECUTE FUNCTION public.asignar_solicitud_a_cartera();

-- -----------------------------------------------------------------------------
-- 4. RLS básico (cliente solo ve sus productos; asesor solo su cartera)
-- -----------------------------------------------------------------------------
ALTER TABLE public.cuentas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimientos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prestamos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cuotas_prestamo ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cliente_cuentas ON public.cuentas;
CREATE POLICY cliente_cuentas ON public.cuentas
  FOR SELECT USING (
    cliente_id IN (
      SELECT id FROM public.clientes
      WHERE user_id = auth.uid() OR id = auth.uid()
    )
  );

DROP POLICY IF EXISTS cliente_movimientos ON public.movimientos;
CREATE POLICY cliente_movimientos ON public.movimientos
  FOR SELECT USING (
    cuenta_id IN (
      SELECT c.id FROM public.cuentas c
      JOIN public.clientes cl ON cl.id = c.cliente_id
      WHERE cl.user_id = auth.uid() OR cl.id = auth.uid()
    )
  );

DROP POLICY IF EXISTS cliente_prestamos ON public.prestamos;
CREATE POLICY cliente_prestamos ON public.prestamos
  FOR SELECT USING (
    cliente_id IN (
      SELECT id FROM public.clientes
      WHERE user_id = auth.uid() OR id = auth.uid()
    )
  );

DROP POLICY IF EXISTS cliente_cuotas ON public.cuotas_prestamo;
CREATE POLICY cliente_cuotas ON public.cuotas_prestamo
  FOR SELECT USING (
    prestamo_id IN (
      SELECT p.id FROM public.prestamos p
      JOIN public.clientes cl ON cl.id = p.cliente_id
      WHERE cl.user_id = auth.uid() OR cl.id = auth.uid()
    )
  );

-- -----------------------------------------------------------------------------
-- 5. MIGRACIÓN DE DATOS (ejecutar manualmente después de exportar CSV desde cliente)
-- -----------------------------------------------------------------------------
-- En Supabase Dashboard → proyecto CLIENTE → Table Editor → Export CSV de cada tabla.
-- Luego importar en proyecto VENTAS respetando el orden:
--   1) clientes  2) cuentas  3) movimientos  4) prestamos  5) cuotas_prestamo
--
-- Si hay conflicto de UUID en clientes que ya existen en ventas, usar:
-- INSERT INTO clientes (id, nombre, dni, email, rol, fecha_registro, nombres, numero_documento, user_id)
-- SELECT id, nombre, dni, email, rol, fecha_registro, split_part(nombre,' ',1), dni, id
-- FROM staging_clientes
-- ON CONFLICT (id) DO UPDATE SET
--   dni = EXCLUDED.dni, email = EXCLUDED.email, nombre = EXCLUDED.nombre;
