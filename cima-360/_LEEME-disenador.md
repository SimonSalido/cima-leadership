# CIMA 360° · Plataforma de Evaluación 360 + NOM-035 + Coaching

**Naturaleza:** módulo privado (con login). Se abre desde la página "Evaluación 360°" del sitio con el botón **Ingresar a la plataforma**.

## Publicar
- Subir la carpeta `cima-360/` junto con el resto del sitio (misma ruta: `cima-360/index.html`).
- Usa el mismo proyecto de Supabase que el Aula y el Plan de Vida.

## Supabase (una sola vez)
1. Supabase → SQL Editor → pegar y correr `supabase/e360_schema.sql`. Crea las tablas `e360_*`, los permisos por rol y el primer administrador.
2. Authentication → Providers → Email → desactivar **Allow new users to sign up** (sólo CIMA da de alta usuarios).
3. Authentication → URL Configuration → agregar en **Redirect URLs** la dirección pública de la plataforma, por ejemplo `https://www.cimaleadership.com.mx/cima-360/index.html`. Sin esto, los correos de invitación y de "olvidé mi contraseña" no regresan a la plataforma.

## Alta de usuarios
1. En la plataforma → **Usuarios y precios → Nuevo usuario** (correo, rol y empresa).
2. En Supabase → **Authentication → Users → Invite user** con el mismo correo.
La persona recibe un correo, crea su contraseña y entra. Para quitar el acceso, se borra en la plataforma.

## Roles
- **Administrador CIMA:** todo (empresas, procesos, reportes, coaching, propuestas, precios, usuarios).
- **Coach:** reportes y planes de coaching.
- **Capital Humano (cliente):** sólo su empresa. Ve los reportes individuales sólo si la empresa tiene encendido "Capital Humano puede ver los reportes individuales".
- **Evaluadores:** no tienen cuenta; entran con su enlace personal.

## Marca
Naranja `#e64018` · negro `#0c0c0e` · fondo `#FCFBF9`. Playfair Display (títulos) y DM Sans (texto).
