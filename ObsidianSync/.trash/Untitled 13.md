---
id: Untitled
aliases: []
tags:
  - note/basic
---

$$
\frac{\sin^{2} 7x}{\sin^{2} x} 
= 16 \cos 4x \,(1+2\cos 4x) 
+ \frac{\cos^{2} 7x}{\cos^{2} x}
$$

Domain:
$$
\sin^{2}x \neq 0,\;\cos^{2}x \neq 0
$$

1)
$$
\begin{aligned}
\frac{\sin^{2}7x}{\sin^{2}x} - \frac{\cos^{2}7x}{\cos^{2}x}
&= \frac{\sin^{2}7x \cos^{2}x - \cos^{2}7x \sin^{2}x}{\tfrac{1}{4}\sin^{2}2x} \\
&= \frac{(\sin 7x \cos x - \cos 7x \sin x)(\sin 7x \cos x + \cos 7x \sin x)}{\tfrac{1}{4}\sin^{2}2x} \\
&= \frac{4 \sin 6x \sin 8x}{\sin^{2}2x} \\
&= \frac{8 \sin 4x \cos 4x \sin 6x}{\sin^{2}2x} \\
&= 16 \sin 2x \cos 2x \cos 4x \sin 6x \sin^{2}2x \\
&= \frac{8(\sin 8x + \sin 4x)\cos 4x}{\sin 2x} \\
&= \frac{8 \sin 4x (1+2\cos 4x)\cos 4x}{\sin 2x}
\end{aligned}
$$

2)
$$
\cos 2x (1+2\cos 4x) = \cos 4x (1+2\cos 4x)
$$
$$
(\cos 2x - 1)(1+2\cos 4x)\cos 4x = 0
$$

$$
\cos 4x = 0 \;\;\Rightarrow\;\; x = \tfrac{\pi}{8} + \tfrac{\pi k}{4}
$$
$$
\cos 4x = -\tfrac{1}{2} \;\;\Rightarrow\;\; x = \pm\tfrac{\pi}{6} + \tfrac{\pi k}{2}
$$
$$
\sin 2x \neq 0 \;\;\Rightarrow\;\; x \neq \tfrac{\pi k}{2}
$$

Answer:
$$
x = \tfrac{\pi}{8} + \tfrac{\pi k}{4}, \quad 
x = \pm\tfrac{\pi}{6} + \tfrac{\pi k}{2}, \quad 
x \neq \tfrac{\pi k}{2},\;\; k \in \mathbb{Z}
$$


