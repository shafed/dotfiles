---
tags:
  - note/basic
aliases:
---

$$
\begin{align*}
&\begin{cases}
x + y = 2a \quad (1) \\
x^2 + y^2 = 2a^2 - 5 \quad (2)
\end{cases} \\[6pt]
&(a - y)^2 + y^2 = 2a^2 - 5 \\
&a^2 - 2ay + y^2 + y^2 = 2a^2 - 5 \\
&2y^2 - 2ay + a^2 - 2a^2 + 5 = 0 \\
&y = \frac{2a \pm \sqrt{(2a)^2 - 4 \cdot 2 \cdot (a^2 - 5)}}{4} 
= \frac{2a \pm \sqrt{4a^2 - 8a^2 + 40}}{4} \\
&= \frac{2a \pm \sqrt{-4a^2 + 40}}{4} \\[6pt]
&y = \frac{2a \pm 2\sqrt{10 - a^2}}{4} = \frac{a \pm \sqrt{10 - a^2}}{2} \\[6pt]
&x = 2a - y \\[6pt]
&\text{Пусть } z = \frac{x}{y}, \quad z = \frac{2a-y}{y} \\[6pt]
&z = \frac{2a}{y} - 1 \\[6pt]
&z + 1 = \frac{2a}{y} \quad \Rightarrow \quad y = \frac{2a}{z+1} \\[6pt]
&x = 2a - \frac{2a}{z+1} = \frac{2az}{z+1} \\[6pt]
&x^2 + y^2 = 2a^2 - 5 \\
&\left(\frac{2az}{z+1}\right)^2 + \left(\frac{2a}{z+1}\right)^2 = 2a^2 - 5 \\
&\frac{4a^2(z^2+1)}{(z+1)^2} = 2a^2 - 5 \\[6pt]
&4a^2(z^2+1) = (2a^2 - 5)(z+1)^2 \\[6pt]
&f(a) = \frac{13a^2 + 20a + 25}{(a+1)^2} \\[6pt]
&f'(a) = \frac{(26a+20)(a+1)^2 - (13a^2+20a+25)\cdot 2(a+1)}{(a+1)^4} \\[6pt]
&= \frac{26a^3+72a^2+66a+20 - (26a^3+72a^2+90a+50)}{(a+1)^3} \\
&= \frac{6(a-5)}{(a+1)^3} \\[6pt]
&\text{Пусть } a_{\min} = 5 \\[6pt]
&f(a_{\min}) = \frac{13 \cdot 25 + 100 + 25}{36} = \frac{450}{36} = 12\tfrac{1}{2}
\end{align*}
$$
$$
\documentclass{standalone}
\usepackage{tikz}

\begin{document}
\begin{tikzpicture}[>=stealth,scale=1.2]
    % Ось a
    \draw[->] (-1,0) -- (7,0) node[right] {$a$};

    % Точки на оси
    \foreach \x/\lbl in { -1/{}, 0/{0}, 1/{1}, 5/{5} }
        \draw (\x,0) node[below] {$\lbl$} -- (\x,0.1);

    % Области знаков производной
    \draw[thick] (1,0.2) -- (5,0.2) node[midway,above] {$-$};
    \draw[thick] (5,0.2) -- (6.5,0.2) node[midway,above] {$+$};
\end{tikzpicture}
\end{document}

$$
