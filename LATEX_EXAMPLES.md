# 📚 Ejemplos de Ecuaciones LaTeX para Probar

Copia y pega estos ejemplos en el editor para probar el renderizado LaTeX.

## 🔢 Matemáticas Básicas

### Fracciones
```latex
$$
\frac{a}{b} \quad \frac{x^2 + y^2}{z^2}
$$
```

### Exponentes y Subíndices
```latex
$$
x^2 \quad y^{2n+1} \quad a_i \quad b_{i,j}
$$
```

### Raíces
```latex
$$
\sqrt{2} \quad \sqrt[3]{8} \quad \sqrt{x^2 + y^2}
$$
```

## 📐 Ecuaciones Famosas

### Teorema de Pitágoras
```latex
$$
a^2 + b^2 = c^2
$$
```

### Fórmula Cuadrática
```latex
$$
x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
$$
```

### Identidad de Euler
```latex
$$
e^{i\pi} + 1 = 0
$$
```

### Relatividad
```latex
$$
E = mc^2
$$
```

### Gravitación Universal
```latex
$$
F = G\frac{m_1 m_2}{r^2}
$$
```

## 🎓 Cálculo

### Derivada
```latex
$$
\frac{d}{dx}f(x) = \lim_{h \to 0}\frac{f(x+h)-f(x)}{h}
$$
```

### Integral
```latex
$$
\int_a^b f(x)\,dx
$$
```

### Integral Definida Famosa
```latex
$$
\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}
$$
```

### Derivadas Parciales
```latex
$$
\frac{\partial f}{\partial x} \quad \frac{\partial^2 f}{\partial x \partial y}
$$
```

## 🔬 Física

### Ecuación de Schrödinger
```latex
$$
i\hbar\frac{\partial}{\partial t}\Psi(\vec{x},t) = \left[-\frac{\hbar^2}{2m}\nabla^2 + V(\vec{x})\right]\Psi(\vec{x},t)
$$
```

### Ecuaciones de Maxwell
```latex
$$
\nabla \cdot \vec{E} = \frac{\rho}{\epsilon_0}
$$
```

```latex
$$
\nabla \times \vec{B} - \frac{1}{c^2}\frac{\partial \vec{E}}{\partial t} = \mu_0\vec{J}
$$
```

### Segunda Ley de Newton
```latex
$$
\vec{F} = m\vec{a} = m\frac{d^2\vec{r}}{dt^2}
$$
```

## 📊 Estadística

### Media
```latex
$$
\bar{x} = \frac{1}{n}\sum_{i=1}^n x_i
$$
```

### Varianza
```latex
$$
\sigma^2 = \frac{1}{n}\sum_{i=1}^n (x_i - \bar{x})^2
$$
```

### Distribución Normal
```latex
$$
f(x) = \frac{1}{\sigma\sqrt{2\pi}}e^{-\frac{1}{2}\left(\frac{x-\mu}{\sigma}\right)^2}
$$
```

## 🔣 Álgebra Lineal

### Sistema de Ecuaciones
```latex
$$
\begin{cases}
x + y = 5 \\
2x - y = 1
\end{cases}
$$
```

### Matrices
```latex
$$
A = \begin{pmatrix}
a & b \\
c & d
\end{pmatrix}
$$
```

### Determinante
```latex
$$
\det(A) = \begin{vmatrix}
a & b \\
c & d
\end{vmatrix} = ad - bc
$$
```

## ∑ Sumas y Productos

### Suma
```latex
$$
\sum_{i=1}^{n} i = \frac{n(n+1)}{2}
$$
```

### Producto
```latex
$$
\prod_{i=1}^{n} x_i
$$
```

### Doble Suma
```latex
$$
\sum_{i=1}^{m}\sum_{j=1}^{n} a_{ij}
$$
```

## 🎯 Límites

### Definición de Derivada
```latex
$$
\lim_{h \to 0} \frac{f(x+h) - f(x)}{h}
$$
```

### Límite al Infinito
```latex
$$
\lim_{x \to \infty} \frac{1}{x} = 0
$$
```

## 🌟 Símbolos Especiales

### Conjuntos
```latex
$$
\mathbb{N} \subset \mathbb{Z} \subset \mathbb{Q} \subset \mathbb{R} \subset \mathbb{C}
$$
```

### Lógica
```latex
$$
\forall x \in \mathbb{R}, \exists y \in \mathbb{R} : x + y = 0
$$
```

### Flechas
```latex
$$
A \rightarrow B \quad A \Rightarrow B \quad A \leftrightarrow B \quad A \Leftrightarrow B
$$
```

## 📝 Inline Examples

Estos son para usar dentro del texto con `$...$`:

- La ecuación cuadrática es $ax^2 + bx + c = 0$
- El número de Euler es $e \approx 2.71828$
- Pi vale aproximadamente $\pi \approx 3.14159$
- La función seno se escribe $\sin(x)$
- La integral de $x^2$ es $\frac{x^3}{3} + C$

## 🎨 Combinaciones Avanzadas

### Ecuación con Múltiples Elementos
```latex
$$
f(x) = \int_{-\infty}^{x} \frac{1}{\sigma\sqrt{2\pi}}e^{-\frac{(t-\mu)^2}{2\sigma^2}}\,dt
$$
```

### Transformada de Fourier
```latex
$$
\hat{f}(\xi) = \int_{-\infty}^{\infty} f(x)e^{-2\pi i x \xi}\,dx
$$
```

### Serie de Taylor
```latex
$$
f(x) = \sum_{n=0}^{\infty} \frac{f^{(n)}(a)}{n!}(x-a)^n
$$
```

## 💡 Tips de Uso

1. **Espaciado:** Usa `\,` para espacio pequeño, `\quad` para medio, `\qquad` para grande
2. **Paréntesis grandes:** `\left( ... \right)` se ajustan al contenido
3. **Texto en ecuaciones:** `\text{texto aquí}`
4. **Negrita matemática:** `\mathbf{x}`
5. **Operadores:** `\sin`, `\cos`, `\tan`, `\log`, `\ln`, `\max`, `\min`

## 🚀 Probar Ahora

1. Abre una nota en Nootes
2. Escribe `$$ ` (con espacio)
3. Copia una ecuación de arriba
4. Pégala en el template que apareció
5. Mueve el cursor dentro de la ecuación
6. ¡Verás el preview en la esquina inferior derecha!

---

Para más comandos LaTeX, consulta: https://katex.org/docs/supported.html
