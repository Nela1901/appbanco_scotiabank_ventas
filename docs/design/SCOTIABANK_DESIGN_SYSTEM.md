# Scotiabank Ventas — Design System

> Extraído de **appbanco_scotiabank_ventas** (Flutter) para replicar identidad visual en **core_frontend_scotiabank** (React + Vite).  
> Solo estética de marca; no incluye lógica, Supabase ni patrones móviles.

---

## 1. Resumen de marca

| Aspecto | Valor |
|---------|-------|
| Color primario | `#ED1C24` (Scotiabank Red) |
| Estilo general | Material 3, limpio, rojo dominante + acentos semánticos Material |
| Tipografía | Roboto (Flutter default) → en web: `Segoe UI`, Roboto, Helvetica Neue |
| Fondo app | Blanco / grises claros |
| Fondo login | Oscuro `#1A1A1A` (no gradiente multicolor) |
| Tema global | `ColorScheme.fromSeed(seedColor: #ED1C24)` en `main.dart` |

**Diferencia clave vs template actual (Banco Andino):** eliminar gradientes multicolor (`--hb-grad`, `--hb-franja`), magenta, turquesa y naranja como colores de marca. Scotiabank Ventas es **monocromático rojo + grises + semánticos funcionales**.

---

## 2. Design tokens

Ver también: [`design-tokens-scotiabank.json`](./design-tokens-scotiabank.json)

### 2.1 Colores

| Token | Valor | Origen Flutter | Uso React |
|-------|-------|----------------|-----------|
| `--scotia-red` | `#ED1C24` | `scotiaRed` en todas las pantallas | Botones, AppBar, acentos, montos |
| `--scotia-red-dark` | `#C4161D` | Derivado (hover) | `:hover` en botones primarios |
| `--scotia-red-light` | `#FDE8E9` | `scotiaRed.withOpacity(0.1–0.2)` | Chips seleccionados, avatares |
| `--scotia-red-tint` | `rgba(237,28,36,0.2)` | ChoiceChip `selectedColor` | Filtros activos |
| `--scotia-blue` | `#1976D2` | `Colors.blue[700]` | Chips asesor, acciones secundarias |
| `--scotia-blue-light` | `#E3F2FD` | `Colors.blue[50]` | Fondo chips asesor, campañas |
| `--scotia-bg` | `#FFFFFF` | Scaffold default | Fondo principal |
| `--scotia-bg-alt` | `#F5F5F5` | `Colors.grey[100]` | Cards visitadas, barra stepper |
| `--scotia-bg-login` | `#1A1A1A` | `login_oficial_screen.dart` | Pantalla login |
| `--scotia-bg-sheet` | `#2A2A2A` | Bottom sheet login | Modal "Problemas para ingresar" |
| `--scotia-text` | `rgba(0,0,0,0.87)` | `Colors.black87` | Texto principal |
| `--scotia-text-secondary` | `#757575` | `Colors.grey[600]` | Subtítulos, DNI |
| `--scotia-muted` | `#9E9E9E` | `Colors.grey` | Labels sección, placeholders |
| `--scotia-text-on-red` | `#FFFFFF` | AppBar, header rojo | Texto sobre primario |
| `--scotia-text-on-red-muted` | `rgba(255,255,255,0.7)` | Contadores, tabs | Subtexto sobre rojo |
| `--scotia-border` | `#E0E0E0` | `Colors.grey[300]` | Bordes inputs, cards |
| `--scotia-green` | `#4CAF50` | `Colors.green` | Éxito, visitado, aprobada |
| `--scotia-error` | `#F44336` | `Colors.red` | Errores, rechazada |
| `--scotia-warning` | `#FF9800` | `Colors.orange` | Bloqueo login, en comité |
| `--scotia-offline` | `#FF9800` | `main.dart` banner | **No replicar** en Core |

### 2.2 Tipografía

| Rol | Tamaño | Peso | Ejemplo origen |
|-----|--------|------|----------------|
| Hero login | 24px | 700 | "SCOTIABANK" |
| Subtítulo login | 16px | 400 | "Portal Oficial de Credito" |
| Título pantalla (AppBar) | ~20px (M3 default) | 400–500 | AppBar title |
| Título sección | 18px | 700 | "Paso 1: Datos del Solicitante" |
| Título card/modal | 20–22px | 700 | Detalle cliente, bottom sheet |
| Nombre cliente (lista) | 16px | 700 | `cartera_diaria_screen.dart` |
| Body | 14–15px | 400 | Detalle filas |
| Body pequeño | 13px | 400–500 | DNI, resumen header |
| Caption / badge | 10–12px | 600–700 | Prioridad, chips gestión |
| Monto destacado | 15px | 700 | `S/ XXXX` en rojo |
| Contador dashboard | 20px | 700 | Total / Visitados / Pendientes |

**Familia:** sin fuentes custom en `pubspec.yaml` → usar stack web estándar.

### 2.3 Espaciado

| Token | px | Uso frecuente |
|-------|-----|---------------|
| `--scotia-space-xs` | 4 | Separadores mínimos |
| `--scotia-space-sm` | 8 | Padding lista, chips horizontales |
| `--scotia-space-md` | 12 | Entre progreso y buscador, chips |
| `--scotia-space-base` | 16 | Padding pantalla, cards, drawer labels |
| `--scotia-space-lg` | 20 | Header mora, stepper bar |
| `--scotia-space-xl` | 24 | Login, formularios, modales |
| `--scotia-space-2xl` | 32 | Antes del botón login |
| `--scotia-space-3xl` | 40 | Tras subtítulo login |

### 2.4 Border radius

| Token | px | Uso |
|-------|-----|-----|
| `--scotia-radius-xs` | 4 | Chips gestión |
| `--scotia-radius-sm` | 8 | Badges estado solicitud |
| `--scotia-radius-md` | 10 | Progress bar |
| `--scotia-radius-base` | 12 | Inputs, cards tablero, semáforo SBS |
| `--scotia-radius-lg` | 15 | Cards cartera |
| `--scotia-radius-xl` | 20 | Header curvo cartera, bottom sheet top |
| `--scotia-radius-sheet` | 25 | Modal detalle cliente |
| `--scotia-radius-pill` | 999px | Badges pill (equivalente web) |

### 2.5 Sombras y elevación

| Estado | Flutter | CSS sugerido |
|--------|---------|--------------|
| Card pendiente | `elevation: 4`, `shadowColor: black26` | `0 2px 8px rgba(0,0,0,0.12)` |
| Card visitada | `elevation: 0` | Sin sombra, fondo `#F5F5F5` |
| Card tablero | `elevation: 2` | `0 1px 4px rgba(0,0,0,0.08)` |
| AppBar | `elevation: 0` | Sin sombra |
| Monitor map overlay | `blurRadius: 10`, `black12` | `0 4px 10px rgba(0,0,0,0.12)` |

---

## 3. CSS variables — bloque `:root` listo para pegar

Pegar en `core_frontend_scotiabank/src/index.css` **reemplazando** las variables `--hb-*` de Banco Andino, o añadiendo `--scotia-*` y mapeando clases existentes.

```css
:root {
  /* ===== Marca Scotiabank Ventas ===== */
  --scotia-red: #ED1C24;
  --scotia-red-dark: #C4161D;
  --scotia-red-light: #FDE8E9;
  --scotia-red-tint: rgba(237, 28, 36, 0.2);

  --scotia-blue: #1976D2;
  --scotia-blue-light: #E3F2FD;

  --scotia-bg: #FFFFFF;
  --scotia-bg-alt: #F5F5F5;
  --scotia-bg-login: #1A1A1A;
  --scotia-bg-sheet: #2A2A2A;

  --scotia-text: rgba(0, 0, 0, 0.87);
  --scotia-text-secondary: #757575;
  --scotia-muted: #9E9E9E;
  --scotia-text-on-red: #FFFFFF;
  --scotia-text-on-red-muted: rgba(255, 255, 255, 0.7);

  --scotia-border: #E0E0E0;
  --scotia-green: #4CAF50;
  --scotia-green-bg: #E8F5E9;
  --scotia-error: #F44336;
  --scotia-error-dark: #D32F2F;
  --scotia-warning: #FF9800;
  --scotia-warning-dark: #EF6C00;
  --scotia-info: #2196F3;

  --scotia-shadow: 0 1px 3px rgba(0, 0, 0, 0.08), 0 1px 2px rgba(0, 0, 0, 0.06);
  --scotia-shadow-card: 0 2px 8px rgba(0, 0, 0, 0.12);
  --scotia-radius: 12px;
  --scotia-radius-lg: 15px;

  /* Espaciado */
  --scotia-space-xs: 4px;
  --scotia-space-sm: 8px;
  --scotia-space-md: 12px;
  --scotia-space-base: 16px;
  --scotia-space-lg: 20px;
  --scotia-space-xl: 24px;

  /* Tipografía base (alinear con body existente) */
  --scotia-font: Roboto, "Segoe UI", "Helvetica Neue", Arial, sans-serif;

  /* ===== Mapeo desde template Banco Andino (--hb-* → --scotia-*) ===== */
  --hb-red: var(--scotia-red);
  --hb-red-dark: var(--scotia-red-dark);
  --hb-red-light: var(--scotia-red-light);
  --hb-bg: var(--scotia-bg-alt);
  --hb-text: var(--scotia-text);
  --hb-muted: var(--scotia-muted);
  --hb-border: var(--scotia-border);
  --hb-green: var(--scotia-green);
  --hb-amber: var(--scotia-warning-dark);
  --hb-shadow: var(--scotia-shadow);
  --hb-radius: var(--scotia-radius);

  /* Desactivar identidad Andino — login Scotiabank es fondo oscuro plano */
  --hb-grad: none;
  --hb-grad-login: var(--scotia-bg-login);
  --hb-grad-naranja: var(--scotia-bg-login);
  --hb-grad-rojo: linear-gradient(180deg, var(--scotia-red) 0%, var(--scotia-red-dark) 100%);
  --hb-franja: none;

  /* Semánticos tipo gestión (sustituir paleta multicolor hb-*) */
  --hb-magenta: var(--scotia-red);
  --hb-turquesa: var(--scotia-blue);
  --hb-naranja: var(--scotia-warning);
  --hb-amarillo: #FBC02D;
  --hb-verde-t: var(--scotia-green);
  --hb-morado: #9C27B0;
}

body {
  font-family: var(--scotia-font);
  color: var(--scotia-text);
  background: var(--scotia-bg-alt);
}
```

### Login específico (sustituir `.cm-login` multicolor)

```css
.scotia-login {
  min-height: 100vh;
  background: var(--scotia-bg-login);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--scotia-space-xl);
}

.scotia-login::before {
  /* Sin franja tejida Andino */
  display: none;
}

.scotia-login-logo { height: 60px; margin-bottom: var(--scotia-space-base); }
.scotia-login-title { color: #fff; font-size: 24px; font-weight: 700; }
.scotia-login-subtitle { color: var(--scotia-text-on-red-muted); font-size: 16px; }

.scotia-login input {
  color: #fff;
  border-bottom: 1px solid rgba(255, 255, 255, 0.3);
  background: transparent;
}

.scotia-login-btn {
  width: 100%;
  height: 50px;
  background: var(--scotia-red);
  color: #fff;
  border: none;
  border-radius: var(--scotia-radius-sm);
  font-weight: 600;
}

.scotia-login-btn:hover { background: var(--scotia-red-dark); }
.scotia-login-btn:disabled { opacity: 0.38; cursor: not-allowed; }
```

---

## 4. Componentes

### 4.1 AppBar / Header web

| Propiedad | Valor |
|-----------|-------|
| Background | `#ED1C24` |
| Título | Blanco, sin sombra |
| Iconos | Blanco |
| Elevation | 0 |
| Tabs (tablero solicitudes) | Label blanco, inactivo `white70`, indicador blanco |

**Equivalente Core:** barra superior fija roja; sidebar lateral blanco con íconos rojos (inspirado en drawer, no copiar drawer móvil completo).

### 4.2 Drawer → Sidebar web (solo referencia visual)

| Elemento | Estilo |
|----------|--------|
| Header | Fondo `#ED1C24`, avatar círculo blanco con ícono rojo |
| Items | Ícono rojo + texto negro |
| Sección "SUPERVISIÓN" | 12px, bold, gris |
| Logout | Ícono rojo al pie |

### 4.3 Botones

| Variante | Background | Texto | Padding | Origen |
|----------|------------|-------|---------|--------|
| Primario | `#ED1C24` | Blanco | `vertical: 14px`, full width login `height: 50` | Login, FAB, confirmar |
| Primario disabled | M3 grey | — | `opacity ~0.38` | Login bloqueado |
| Secundario outline | Transparente | `#1976D2` | `vertical: 14px` | "VER FICHA COMPLETA" |
| Acción éxito | `#4CAF50` | Blanco | `vertical: 14px` | "REGISTRAR RESULTADO" |
| Ghost / cerrar | `#E0E0E0` | `black54` | `vertical: 12px` | "CERRAR" modal |
| Outlined nav | Default M3 | Negro | — | "ANTERIOR" stepper |

### 4.4 Chips / filtros (cartera)

**Filtros principales** (`ChoiceChip`):

- Seleccionado: fondo `rgba(237,28,36,0.2)`, texto `#ED1C24`
- No seleccionado: texto negro, fondo default
- Opciones: Todos, Renovaciones, Nuevas, En mora, Visitados

**Filtro asesor** (`FilterChip`, solo supervisor):

- Seleccionado: fondo `#1976D2`, texto blanco
- No seleccionado: fondo `#E3F2FD`, texto negro

### 4.5 Badges de estado

#### Prioridad (`_buildPriorityTag`)

| Valor | Color |
|-------|-------|
| ALTA | `#D32F2F` |
| MEDIA | `#EF6C00` |
| BAJA | `#1976D2` |

#### Tipo gestión (`_getColorGestion`)

| Tipo | Color | Fondo chip |
|------|-------|------------|
| RENOVACION | `#2196F3` | color @ 10% opacity |
| AMPLIACION | `#4CAF50` | idem |
| NUEVA SOLICITUD | `#FF9800` | idem |
| SEGUIMIENTO | `#607D8B` | idem |
| RECUPERACION MORA | `#F44336` | idem |
| DESERTOR | `#9C27B0` | idem |
| default | `#9E9E9E` | idem |

#### Estado visita (ícono leading)

| Estado | Ícono | Color |
|--------|-------|-------|
| Visitado | check_circle | `#4CAF50` |
| En ruta | pending_actions | `#2196F3` |
| Pendiente | account_circle_outlined | `#9E9E9E` |

#### Estado solicitud (tablero — relevante para Core)

| Estado | Color |
|--------|-------|
| Aprobada | `#4CAF50` |
| Rechazada | `#F44336` |
| En comité | `#FF9800` |
| Desembolsada | `#2196F3` |
| default | `#9E9E9E` |

Badge: padding `8×4px`, radius `8px`, fondo color @ 10%, texto color sólido, 10px bold.

#### Mora semáforo

| Días | Color | Urgencia |
|------|-------|----------|
| ≤ 30 | `#FBC02D` | Seguimiento preventivo |
| ≤ 60 | `#FF9800` | Gestión prioritaria |
| > 60 | `#F44336` | Recuperación urgente |

---

## 5. Referencia por pantalla (prioridad Core web)

### 5.1 Login / Auth

**Archivos:** `lib/view/auth/login_oficial_screen.dart`, `forgot_password_screen.dart`, `register_request_screen.dart`

| Aspecto | Descripción |
|---------|-------------|
| Layout | Centrado vertical, una columna, padding 24px |
| Fondo | `#1A1A1A` sólido (sin gradiente, sin franja) |
| Logo | Imagen 60px alto (URL externa) o ícono banco rojo 80px fallback |
| Títulos | "SCOTIABANK" 24px bold blanco; subtítulo 16px white70 |
| Inputs | Underline blanco 30%, labels white70, texto blanco |
| CTA | Botón full width 50px alto, rojo `#ED1C24`, texto "INGRESAR" blanco |
| Errores | Texto rojo Material; bloqueo naranja |
| Link | "Problemas para ingresar" white70 subrayado |
| Bottom sheet | Fondo `#2A2A2A`, radius top 20px |

**No hay splash screen** con branding custom (Android launch = blanco default).

### 5.2 AppBar + navegación

**Archivo principal:** `cartera_diaria_screen.dart` (+ patrón repetido en ~15 pantallas)

```
┌─────────────────────────────────────────────┐
│ ☰  Cartera Diaria              🔔  ↻      │  ← AppBar #ED1C24, texto blanco
├─────────────────────────────────────────────┤
│  [Total]   [Visitados]   [Pendientes]       │  ← Header rojo curvo (radius 20 abajo)
│  Resumen del día…                           │
└─────────────────────────────────────────────┘
```

- Header dashboard: mismo rojo, contadores 20px bold blanco, labels 12px white70
- **Core web:** header rojo + sub-header opcional con KPIs; sidebar blanco con acentos rojos

### 5.3 Lista tipo cartera (cards)

**Archivo:** `cartera_diaria_screen.dart`

```
┌──────────────────────────────────────────────┐
│ ▌ (barra 6px color gestión)                  │
│ 👤  Nombre Cliente              S/ 5000      │
│     DNI: ****1234               ALTA         │
│     [RENOVACION chip]                        │
└──────────────────────────────────────────────┘
```

| Elemento | Estilo |
|----------|--------|
| Card pendiente | Blanco, elevation 4, radius 15px, margin bottom 10px |
| Card visitada | `#F5F5F5`, elevation 0, texto gris |
| Borde izquierdo | 6px, color según `tipo_gestion` |
| Monto | 15px bold `#ED1C24` |
| Buscador | Outline radius 12px, icono search |
| Progress día | Track `#EEEEEE`, fill rojo, height 8px, radius 10px |

**Core web (evaluación solicitudes):** reutilizar patrón card + badge estado + monto en rojo; tabs de estado como `tablero_solicitudes_screen.dart`.

### 5.4 Formularios / steppers solicitud

**Archivo:** `solicitud_form_screen.dart`

| Elemento | Estilo |
|----------|--------|
| AppBar | Rojo, título blanco |
| Indicador pasos | 4 segmentos 40×8px, radius 4px: activo rojo, completado verde, pendiente `#E0E0E0` |
| Área pasos | Fondo `#F5F5F5`, padding vertical 20px |
| Contenido | Padding 24px, títulos paso 18px bold |
| Inputs | `OutlineInputBorder` M3 default |
| Simulación highlight | Fondo `green[50]`, texto verde bold 18px |
| Nav inferior | Padding 24px; primario rojo "SIGUIENTE" / "FINALIZAR Y ENVIAR" |

**Core web:** stepper horizontal rojo/verde/gris; formularios con spacing 16px entre campos.

### 5.5 Tablero solicitudes (alta prioridad Core)

**Archivo:** `tablero_solicitudes_screen.dart`

- AppBar rojo + TabBar scrollable (Enviada, En comité, Aprobada…)
- Cards: elevation 2, radius 12px, padding lista 16px
- Badge estado con colores semánticos (tabla §4.5)

### 5.6 Botones de acción principales

| Contexto | Label | Color |
|----------|-------|-------|
| Login | INGRESAR | Rojo |
| Cartera FAB | Prospecto | Rojo extended FAB |
| Modal visita | CONFIRMAR Y FINALIZAR | Rojo |
| Modal visita | REGISTRAR RESULTADO | Verde |
| Documentos | CONTINUAR CON EL ENVÍO | Rojo |
| Cobranza | REGISTRAR GESTIÓN | Rojo |

---

## 6. Assets

### 6.1 Carpeta `assets/` local

**No existe** carpeta `assets/` declarada en `pubspec.yaml`. El proyecto no incluye logos ni iconos embebidos en el repo Flutter.

### 6.2 Recursos usados en runtime

| Asset | Ruta / URL | Copiar a Core Frontend |
|-------|------------|------------------------|
| Logo Scotiabank | `https://raw.githubusercontent.com/Nela1901/assets/main/logoscotia.png` | `public/logoscotia.png` o `src/assets/logoscotia.png` |
| Fallback login | Material Icon `account_balance`, no archivo | Usar SVG ícono banco o logo anterior |
| Android splash | `android/.../launch_background.xml` → fondo blanco | Opcional: splash blanco o rojo + logo |
| Iconos UI | Material Icons (built-in) | Lucide/Heroicons equivalentes en React |

### 6.3 Acción recomendada

1. Descargar `logoscotia.png` desde la URL del login y versionarlo en Core Frontend.
2. No buscar assets en `assets/` del repo Ventas — no hay archivos.

---

## 7. Lo que NO replicar

| Elemento | Motivo |
|----------|--------|
| Bottom navigation bar | Solo app móvil |
| Drawer completo con 15+ rutas móviles | Core tiene IA propia de navegación web |
| Banner "Modo offline activo" (naranja) | SQLite / offline móvil |
| Supabase Auth | Core usa JWT backend `:8003` |
| Workmanager / notificaciones push | Infra móvil |
| ReorderableListView (drag clientes) | UX campo, no back-office |
| Google Maps / geolocator | Módulos mapa móvil |
| Gradiente/franja Banco Andino (`--hb-franja`, `--hb-grad-*`) | Marca incorrecta |
| FAB "Prospecto" flotante | Acción móvil de prospección en campo |

---

## 8. Tabla resumen completa

| Token | Valor | Archivo Flutter origen | Uso en React |
|-------|-------|------------------------|--------------|
| `--scotia-red` | `#ED1C24` | `main.dart`, todas las pantallas `home/` | Primario global |
| `--scotia-red-dark` | `#C4161D` | Derivado | Hover botones |
| `--scotia-red-light` | `#FDE8E9` | `ficha_cliente_screen.dart` avatar | Fondos tintados |
| `--scotia-red-tint` | `rgba(237,28,36,0.2)` | `cartera_diaria_screen.dart` ChoiceChip | Filtros activos |
| `--scotia-bg-login` | `#1A1A1A` | `login_oficial_screen.dart` | Login full page |
| `--scotia-bg-sheet` | `#2A2A2A` | `login_oficial_screen.dart` bottom sheet | Modales oscuros auth |
| `--scotia-bg-alt` | `#F5F5F5` | Cards visitadas, stepper | Fondo app / filas alternas |
| `--scotia-text` | `rgba(0,0,0,0.87)` | Listas, formularios | Texto body |
| `--scotia-muted` | `#9E9E9E` | Drawer section labels | Labels, hints |
| `--scotia-border` | `#E0E0E0` | Inputs, cards | Bordes |
| `--scotia-green` | `#4CAF50` | Visitado, aprobada, stepper done | Éxito |
| `--scotia-error` | `#F44336` | Errores login, rechazada | Error |
| `--scotia-warning` | `#FF9800` | Bloqueo, en comité | Warning |
| `--scotia-blue` | `#1976D2` | FilterChip asesor, enlaces | Secundario |
| `--scotia-radius-base` | `12px` | Search, cards tablero | Cards inputs |
| `--scotia-radius-lg` | `15px` | Cards cartera | List items |
| `--scotia-space-base` | `16px` | Padding universal | Layout |
| `--scotia-space-xl` | `24px` | Login, forms, modals | Secciones |
| `--scotia-shadow-card` | ver §2.5 | Cards cartera | Elevación |
| `tipo_gestion.*` | ver §4.5 | `_getColorGestion()` | Borde/chip lista |
| `prioridad.*` | ver §4.5 | `_buildPriorityTag()` | Tags prioridad |
| `estado_solicitud.*` | ver §4.5 | `tablero_solicitudes_screen.dart` | Pipeline Core |
| AppBar bg | `#ED1C24` | Todas las pantallas `AppBar` | Header web |
| AppBar text | `#FFFFFF` | idem | Título header |
| Button primary h | `50px` | `login_oficial_screen.dart` | CTA login |
| Progress height | `8px` | `cartera_diaria_screen.dart` | Barras progreso |
| Font family | Roboto | Flutter default | `body` CSS |
| Logo | URL GitHub | `login_oficial_screen.dart` | `public/logoscotia.png` |

---

## 9. Checklist de adopción en Core Frontend

1. [ ] Reemplazar `:root` con bloque §3 (o alias `--hb-*` → `--scotia-*`).
2. [ ] Eliminar/ocultar `.hb-franja-top` y gradientes en login.
3. [ ] Aplicar `.scotia-login` o adaptar `.cm-login` a fondo `#1A1A1A`.
4. [ ] Copiar logo a `public/logoscotia.png`.
5. [ ] AppBar/header: fondo `#ED1C24`, texto blanco.
6. [ ] Botones primarios: `#ED1C24`, hover `#C4161D`.
7. [ ] Badges de solicitud: colores §4.5 (tablero).
8. [ ] Cards: radius 12–15px, sombra suave, sin multicolor.

---

*Generado desde appbanco_scotiabank_ventas — solo documentación; sin cambios en core_frontend_scotiabank.*
