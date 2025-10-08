# 🧪 Guía de Pruebas - Nuevas Funcionalidades

## 🚀 Inicio Rápido

### Paso 1: Compilar y Ejecutar
```bash
cd "C:\Users\U7suario\Documents\GitHub\Nootes-flutter"
flutter run -d chrome
```

### Paso 2: Login
- Usuario de prueba o crear cuenta nueva
- Navegar al workspace principal

---

## 📝 Test 1: Sistema de Plantillas

### Objetivo:
Verificar que las plantillas crean notas estructuradas correctamente

### Pasos:
1. ✅ Click en botón **naranja flotante** (icono 📄)
2. ✅ Verificar que aparece diálogo con **8 plantillas** en grid 2x2
3. ✅ Seleccionar **"Diario Personal"**
4. ✅ Completar formulario:
   - Estado de ánimo: `😊 Feliz`
   - Clima: `☀️ Soleado`
5. ✅ Verificar vista previa con variables reemplazadas
6. ✅ Click en **"Crear Nota"**
7. ✅ Verificar nota creada con:
   - Título: "Diario [fecha actual]"
   - Contenido estructurado con headers
   - Tags: `diario`, `personal`

### Resultado Esperado:
```markdown
# Diario - 8/10/2025

**Estado de ánimo:** 😊 Feliz
**Clima:** ☀️ Soleado

## ☀️ Buenos momentos del día


## 🎯 Logros de hoy

...
```

### Probar otras plantillas:
- **Reunión**: Debe pedir proyecto y organizador
- **Lista de Tareas**: Debe tener 3 niveles de prioridad
- **Receta**: Debe incluir ingredientes y preparación
- **Plan de Proyecto**: Debe tener tabla de cronograma

---

## 📊 Test 2: Dashboard de Productividad

### Objetivo:
Verificar cálculo correcto de métricas y visualización

### Pasos:
1. ✅ Crear **3-5 notas** con contenido diferente
2. ✅ Agregar tags a las notas
3. ✅ Click en botón **morado flotante** (icono 📊)
4. ✅ Verificar cards de métricas:
   - Total de notas = número correcto
   - Notas hoy = cantidad creada hoy
   - Notas esta semana = suma correcta
5. ✅ Verificar sección de palabras:
   - Total palabras > 0
   - Promedio por nota calculado
6. ✅ Verificar racha de escritura:
   - Racha actual >= 1 (si creaste notas hoy)
7. ✅ Verificar heatmap:
   - Cuadrado verde en día actual
   - Hover muestra tooltip con fecha y cantidad
8. ✅ Verificar top tags:
   - Tags ordenados por frecuencia
   - Barras de progreso correctas

### Resultado Esperado:
- Cards con iconos coloridos
- Números actualizados en tiempo real
- Heatmap responsive (30 cuadrados)
- Barras de progreso animadas

### Test de actualización:
1. ✅ Click en **"Actualizar"** (icono ↻)
2. ✅ Verificar que métricas se recalculan
3. ✅ Crear nueva nota y actualizar
4. ✅ Verificar que contador aumenta

---

## ✅ Test 3: Sistema de Tareas

### Objetivo:
Verificar detección y gestión de checkboxes

### Pasos preparatorios:
1. ✅ Crear nota "Tareas Semanales" con contenido:
```markdown
## Trabajo
- [x] Revisar emails
- [ ] Reunión con equipo
- [ ] Actualizar informe

## Personal
- [ ] Comprar comida
- [x] Hacer ejercicio
- [ ] Leer libro
```

### Pasos de prueba:
1. ✅ Menú **"⋮"** → **"Mis Tareas"**
2. ✅ Verificar 3 tabs:
   - Pendientes
   - Completadas
   - Todas
3. ✅ En tab **"Pendientes"**:
   - Verificar 4 tareas sin marcar
   - Agrupadas bajo "Tareas Semanales"
   - Progreso: 2/6 (33%)
4. ✅ En tab **"Completadas"**:
   - Verificar 2 tareas marcadas
   - Texto tachado
5. ✅ Click en checkbox de "Comprar comida"
6. ✅ Verificar que progreso cambia a 3/6 (50%)
7. ✅ Click en **FAB "Estadísticas"**
8. ✅ Verificar:
   - Total: 6 tareas
   - Completadas: 3
   - Pendientes: 3
   - Tasa: 50%

### Test de múltiples notas:
1. ✅ Crear segunda nota "Proyecto X" con tareas
2. ✅ Verificar que aparece segunda card
3. ✅ Expandir/colapsar cards
4. ✅ Verificar contador actualizado

---

## 📤 Test 4: Exportación

### Objetivo:
Verificar generación correcta de formatos

### Preparación:
1. ✅ Tener al menos 3 notas con:
   - Títulos diferentes
   - Contenido con markdown
   - Tags variados

### Test de Markdown:
1. ✅ Menú **"⋮"** → **"Exportar"**
2. ✅ Seleccionar 2 notas (checkbox)
3. ✅ Verificar contador: "2 notas seleccionadas"
4. ✅ Click en card **"Markdown"** (azul)
5. ✅ Verificar diálogo con:
   - Nombre archivo: `notas_[timestamp].md`
   - Tamaño en KB
   - Vista previa del contenido
6. ✅ Verificar estructura:
```markdown
# Exportación de Notas - Nootes
Fecha de exportación: ...

---

## [Título Nota 1]

**Etiquetas:** tag1, tag2
**Creada:** ...

[contenido]

---
```
7. ✅ Copiar contenido y pegar en editor
8. ✅ Verificar formato correcto

### Test de JSON:
1. ✅ Click en card **"JSON"** (verde)
2. ✅ Verificar estructura JSON válida:
```json
{
  "version": "1.0",
  "exportDate": "...",
  "noteCount": 2,
  "notes": [...]
}
```
3. ✅ Copiar y validar en jsonlint.com

### Test de HTML:
1. ✅ Click en card **"HTML"** (naranja)
2. ✅ Verificar HTML con:
   - DOCTYPE declarado
   - CSS embedded
   - Meta charset UTF-8
3. ✅ Copiar contenido
4. ✅ Guardar como `test.html`
5. ✅ Abrir en navegador
6. ✅ Verificar:
   - Fondo oscuro (#0f172a)
   - Cards con bordes redondeados
   - Tags como chips azules
   - Formato responsive

### Test de selección:
1. ✅ Botón **"Todas"** - selecciona todas las notas
2. ✅ Botón **"Deseleccionar"** - limpia selección
3. ✅ Selección individual funciona
4. ✅ Cards deshabilitadas sin selección

---

## 🎨 Test 5: Integración UI/UX

### Objetivo:
Verificar consistencia visual y navegación

### Test de FAB:
1. ✅ Verificar botones flotantes en orden:
   - Dashboard (morado)
   - Plantilla (naranja)
   - Nueva nota (azul)
   - Imagen (gris)
   - Audio (gris/rojo)
2. ✅ Tooltips aparecen en hover
3. ✅ Animaciones suaves al presionar

### Test de menú:
1. ✅ Click en **"⋮"** en header
2. ✅ Verificar opciones:
   - Mis Tareas (icono verde)
   - Exportar (icono azul)
   - Ajustes (icono gris)
3. ✅ Descripciones visibles
4. ✅ Navegación funciona

### Test de navegación:
1. ✅ Ir a "Mis Tareas"
2. ✅ Botón back regresa a workspace
3. ✅ Ir a "Exportar"
4. ✅ Botón back funciona
5. ✅ Ir a Dashboard
6. ✅ Botón back funciona

### Test responsive:
1. ✅ Redimensionar ventana a móvil (<600px)
2. ✅ Verificar grid de plantillas: 1 columna
3. ✅ Verificar cards dashboard: 1 columna
4. ✅ Verificar botones flotantes apilados

---

## 🐛 Casos Edge a Probar

### Test 1: Plantillas sin datos
1. Crear nota desde plantilla sin llenar campos
2. Verificar que usa valores por defecto
3. Variables sin datos muestran `{{variable}}`

### Test 2: Dashboard sin notas
1. Borrar todas las notas
2. Abrir dashboard
3. Verificar valores en 0
4. Sin errores de división por cero

### Test 3: Tareas sin checkboxes
1. Abrir "Mis Tareas" sin notas con checkboxes
2. Verificar mensaje: "¡No hay tareas pendientes!"
3. Ilustración de estado vacío visible

### Test 4: Exportar sin selección
1. Ir a "Exportar"
2. Click en card sin seleccionar notas
3. Verificar mensaje: "Selecciona al menos una nota"
4. Cards deshabilitadas visualmente

### Test 5: Notas con caracteres especiales
1. Crear nota con título: `Test & <script> "quotes"`
2. Exportar a HTML
3. Verificar escape correcto: `&lt;script&gt;`

---

## ⚡ Test de Performance

### Test 1: Dashboard con muchas notas
1. Crear 100+ notas (script de prueba)
2. Abrir dashboard
3. Verificar:
   - Carga < 3 segundos
   - Sin lag en UI
   - Heatmap renderiza correctamente

### Test 2: Exportar muchas notas
1. Seleccionar 50+ notas
2. Exportar a HTML
3. Verificar:
   - Diálogo abre < 2 segundos
   - Contenido renderiza completo
   - Memoria < 500MB

### Test 3: Tareas con muchos checkboxes
1. Crear nota con 50+ checkboxes
2. Abrir "Mis Tareas"
3. Verificar:
   - Lista carga suavemente
   - Scroll fluido
   - Checkboxes responsivos

---

## ✅ Checklist de Validación Final

### Funcionalidad:
- [ ] 8 plantillas funcionan correctamente
- [ ] Dashboard calcula métricas precisas
- [ ] Tareas se detectan y agrupan
- [ ] 3 formatos de exportación generan archivos válidos
- [ ] Navegación entre páginas fluida

### UI/UX:
- [ ] Colores consistentes con diseño
- [ ] Iconos apropiados y visibles
- [ ] Tooltips descriptivos
- [ ] Animaciones suaves (no lag)
- [ ] Estados vacíos con ilustraciones

### Responsive:
- [ ] Desktop (>1200px) - 2-4 columnas
- [ ] Tablet (600-1200px) - 2 columnas
- [ ] Móvil (<600px) - 1 columna
- [ ] Botones accesibles (>44dp)

### Errores:
- [ ] 0 errores de compilación
- [ ] Sin crashes durante uso normal
- [ ] Mensajes de error claros
- [ ] Validación de formularios

---

## 🎯 Criterios de Éxito

### Mínimo Aceptable:
- ✅ 4/5 funcionalidades principales funcionan
- ✅ 0 errores críticos
- ✅ UI responsive en desktop y móvil

### Óptimo:
- ✅ 5/5 funcionalidades 100% operativas
- ✅ 0 warnings de compilación
- ✅ Performance <2s en todas las operaciones
- ✅ Todas las animaciones suaves (60 FPS)

### Excelente:
- ✅ Todos los tests pasan
- ✅ Casos edge manejados
- ✅ Experiencia de usuario pulida
- ✅ Documentación completa

---

## 📝 Reporte de Bugs

Si encuentras algún error, documenta:

1. **Descripción**: Qué estabas haciendo
2. **Pasos para reproducir**: Lista numerada
3. **Resultado esperado**: Qué debería pasar
4. **Resultado actual**: Qué pasó realmente
5. **Screenshots**: Si aplica
6. **Consola**: Errores en DevTools

---

## 🎉 Conclusión

Al completar estos tests, habrás validado:
- ✅ 5 funcionalidades principales
- ✅ 8 plantillas predefinidas
- ✅ 15+ métricas de dashboard
- ✅ 3 formatos de exportación
- ✅ Sistema completo de tareas

**Tiempo estimado:** 30-45 minutos  
**Resultado esperado:** 100% de tests pasando  
**Estado:** Ready for Production 🚀
