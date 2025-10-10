# Funcionalidades LaTeX en Nootes

## ✅ Implementación Completada

El editor Quill ahora incluye soporte completo para renderizado de ecuaciones matemáticas LaTeX usando `flutter_math_fork`.

## 🎯 Características

### 1. Atajos de Teclado

#### Bloque Math (Display Mode)
- **Atajo:** Escribe `$$ ` (dos signos de dólar seguidos de espacio)
- **Resultado:** Se expande automáticamente a:
  ```
  $$
  
  $$
  ```
- **Cursor:** Se posiciona en el medio para que escribas la ecuación

#### Math Inline
- **Atajo:** Escribe `$ ` (un signo de dólar seguido de espacio)
- **Resultado:** Se inserta `$$` con el cursor en el medio
- **Uso:** Para ecuaciones dentro del texto como $x^2 + y^2 = r^2$

### 2. Vista Previa en Vivo

Cuando el cursor está dentro de delimitadores math (`$$...$$` o `$...$`), aparece automáticamente un overlay en la **esquina inferior derecha** mostrando:

- 📐 **Icono indicador:** 
  - `Icons.functions` para bloques math
  - `Icons.exposure` para math inline
- 🎨 **Renderizado LaTeX:** Vista previa en tiempo real de la ecuación
- 🔄 **Actualización automática:** Se actualiza al mover el cursor o editar

### 3. Botones de Toolbar

En la barra de herramientas del editor:

- **Botón "Bloque LaTeX"** (Icons.functions):
  - Inserta plantilla de bloque math
  - Posiciona el cursor para empezar a escribir

- **Botón "LaTeX inline"** (Icons.exposure):
  - Inserta par de delimitadores `$$`
  - Cursor listo en el medio

### 4. Detección Inteligente

- **Bloque math:** Busca `$$` antes y después del cursor
- **Inline math:** Busca pares de `$` individuales en la línea actual
- **Preview oculto:** Se oculta automáticamente cuando sales de los delimitadores

## 📝 Ejemplos de Uso

### Ecuación Cuadrática
```latex
$$
x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
$$
```

### Ecuación de Schrödinger
```latex
$$
i\hbar\frac{\partial}{\partial t}\Psi(\vec x,t) = -\frac{\hbar}{2m}\nabla^2\Psi(\vec x,t)+ V(\vec x)\Psi(\vec x,t)
$$
```

### Transformada de Fourier
```latex
$$
\hat f(\xi) = \int_{-\infty}^\infty f(x)e^{- 2\pi i \xi x}\mathrm{d}x
$$
```

### Inline
```latex
La fórmula $E = mc^2$ es famosa.
```

## 🔧 Implementación Técnica

### Archivos Modificados
- `lib/widgets/quill_editor_widget.dart`: Widget principal del editor
- `pubspec.yaml`: Dependencia `flutter_math_fork: ^0.7.4`

### Métodos Clave
- `_expandMathBlockSkeleton()`: Expande atajo `$$ `
- `_expandInlineMathSkeleton()`: Expande atajo `$ `
- `_updateMathPreview()`: Detecta y actualiza preview
- `_insertMathBlock()`: Botón toolbar bloque
- `_insertMathInline()`: Botón toolbar inline

### Estado
```dart
String _mathPreview = '';      // Expresión LaTeX actual
bool _mathIsBlock = false;     // true si es bloque, false si inline
bool _showMathPreview = false; // Controla visibilidad del overlay
```

## ✨ Características Adicionales Preservadas

El editor mantiene todas las funcionalidades previas:
- ✅ Formato rico (negrita, cursiva, listas, etc.)
- ✅ Wikilinks `[[nombre]]` con autocompletado
- ✅ Atajos Markdown (# heading, - lista, etc.)
- ✅ Búsqueda, imágenes, enlaces
- ✅ Guardado automático con Delta JSON
- ✅ Contador de palabras
- ✅ Tema claro/oscuro

## 🐛 Testing

Para probar:
1. Abre cualquier nota
2. Escribe `$$ ` → Debería expandirse el template
3. Escribe una ecuación como `\frac{a}{b}`
4. Verás el preview renderizado en la esquina inferior derecha
5. Usa los botones de la toolbar para insertar templates

## 📚 Recursos

- [flutter_math_fork en pub.dev](https://pub.dev/packages/flutter_math_fork)
- [Sintaxis LaTeX de KaTeX](https://katex.org/docs/supported.html)
- Compatible con la mayoría de comandos LaTeX estándar
