# CIMA · Plan de Vida — instrucciones para el diseñador

**Naturaleza:** módulo del área de clientes (coaching individual). Puede ir público o detrás del login del sitio.

## Qué es
App interactiva autónoma (un solo `index.html`, sin dependencias): el cliente construye su **Plan de Vida** en 4 partes — Visión a 20 años (8 dimensiones), Metas 10/5/3, Plan de acción anual/trimestral, y Ritmos + **Indicadores de Vida** con radar. Guarda las respuestas en el navegador y tiene botón **Descargar PDF**.

## Publicar (portal cimaleadership.com.mx)
- Subir esta carpeta a Vercel o Netlify (sitio estático).
- Ideal en un subdominio, p. ej. `planvida.cimaleadership.com.mx` (en Vercel → Domains; en GoDaddy → CNAME).
- O embeber en el área de clientes con:
  ```html
  <iframe src="https://URL-DEL-PLAN-DE-VIDA" style="width:100%;height:1600px;border:0" title="Plan de Vida CIMA"></iframe>
  ```

## Logo oficial
En el `<script>`, reemplazar la constante `LOGO_SVG` (recreación) por el **SVG oficial**.

## Marca
Naranja `#FA4B1E` · tinta `#1A1A1A` · fondo `#FCFBF9`. Títulos serif, cuerpo sans.

## Nota importante
Los datos del cliente se guardan **localmente en su navegador** (localStorage). Para conservarlos entre dispositivos o centralizarlos en tu sistema, se necesita un backend/cuenta de usuario. Por ahora, el cliente descarga su PDF para conservarlo.
