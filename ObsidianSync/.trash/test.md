---
tags:
  - note/basic
aliases:
---

# Решение
## 1
$$
\begin{cases}
-x + ay = 2a \\
ax - y = 3a - 5
\end{cases}

\Leftrightarrow

\begin{cases}
x = ay - 2a \; (2) \\
ax - y = 3a - 5 \; (1)
\end{cases}
$$

$$
\begin{gather}
(1) \; a^{2}y - 2a^{2} - y = 3a - 5 \\
y = \frac{2a^{2}+3a - 5}{a^{2}-1} = \\
\frac{(a-1) (2a+5)}{(a-1)(a+1)} =  \\
\frac{2a+5}{a+1}, \; a\neq 1
\end{gather}
$$

$$
\begin{gather}
(2) \; x = \frac{2a^{2}+5a}{a+1} - a = \frac{2a^{2}+5a -2a^{2} - 2a}{a+1} = \frac{3a}{a+1}
\end{gather}
$$

***

## 2
Тогда
$$
x^{2}+y^{2} = \frac{9a^{2}}{(a+1)^{2}} + \frac{(2a+5)^{2}}{(a+1)^{2}} = \frac{9a^{2}+4a^{2} +20a + 25}{(a+1)^{2}} = \frac{13a^{2} + 20a + 25}{(a+1)^{2}} = f(a)
$$

$$
f'(a) = \frac{(26a+20) (a+1)^{2} - 2(a+1)(13a^{2} + 20a + 25)}{(a+1)^4} = \frac{26a^{2} + 46a + 20 - 26a^{2} - 40a - 50}{(a+1)^3} = \frac{6a-30}{(a+1)^3} = \frac{6(a-5)}{(a+1)^3}
$$

![[diagram-20250906.svg]]

$$
\text{Тогда } a_{min} = 5: f(a_{min}) = \frac{13 * 25 + 100 + 25}{6^{2}} = \frac{450}{36} = 12 \frac{1}{2}
$$
***

## 3
Проверим $a=1:$
$$
\begin{cases}
x = y - 2 \\
x - y = 3 - 5
\end{cases}
 \Leftrightarrow
\begin{cases}
x = y -2  \\
x = y - 2
\end{cases}
$$

Тогда $x^{2} + y^{2} = y^{2} - 4y + 4 + y^{2} = 2y^{2} -4y + 4$
$y_{в} = \frac{4}{4} = 1$
Минимальное значение достигается при $y_{в}$ (т.к. $2y^{2}-4y+4$ — парабола, ветви верх): $2 - 4 + 4 = 2 < 12 \frac{1}{2}$

***
# Ответ

$\text{Ответ: } 2 \text{ при } a =1$

