---
title: Constructing Parameterized Matrices with GNU Octave
tags: c++, nix
---

<!-- cSpell:words diagonal undistort -->
<!-- cSpell:ignore pmatrix numpy mathrm syms passthru -->

This week I was dealing with image processing and linear algebra, and I needed
a quick derivation of a specific kind of matrix.
With GNU Octave to the rescue, this cost me only a few minutes!
This article represents my notes from this little journey from the mathematical 
derivation of the matrix and the symbolic solution that I then ported to C++.

<!--more-->

In a C++ project where I use the [OpenCV](https://opencv.org/) library to 
undistort pictures, I needed a function that creates shearing matrices for 
specific shearing factors.
The following illustration shows the needed transformation:

![Example projection: The B'/B'' and D'/D'' points are the projections for values of N smaller/larger 1.0](/images/shear.png)

Given a picture that is `W` pixels wide and `H` pixels high, all points on the
main diagonal line shall remain untouched by the transformation.
For a shearing factor `N < 1.0`, all other points should be pulled towards the
main diagonal line, along the direction of the other diagonal line (which goes 
from point B to D).
The same applies for a factor `N > 1.0` but in this case, the points are pushed 
away from the main diagonal line instead of being pulled towards it.

## Defining the Equations

So we are looking for a Matrix $M_N$ for which the following qualitative example
projections hold:

$$
\forall N \in \Reals \qquad
\begin{align}
M_N A &= A \\
M_N C &= C \\
M_N B &= \begin{cases}
         B'  & \text{if }N < 1 \\ 
         B   & \text{if } N = 1 \\
         B'' & \text{if }N > 1
         \end{cases} \\
M_N D &= \begin{cases}
         D'  & \text{if }N < 1 \\ 
         D   & \text{if } N = 1 \qquad \\
         D'' & \text{if }N > 1
         \end{cases}
\end{align}
$$

I'm not good at memorizing standard matrices, but most geometric transformations
can be calculated using 
[eigenvalues and eigenvectors](https://en.wikipedia.org/wiki/Eigenvalues_and_eigenvectors#:~:text=In%20linear%20algebra%2C%20an%20eigenvector,which%20the%20eigenvector%20is%20scaled.):
From the image and the example projections, we can derive the following generic
eigenvalue- and eigenvector-based equations, where $x_1$ is the main diagonal 
and $x_2$ is the other diagonal:

$$
x_1 = \frac{C - A}{|C - A|} 
    = \frac{1}{\sqrt{W^2 + H^2}} \begin{pmatrix}
                                 W \\ 
                                 H
                                 \end{pmatrix}
, \quad 
\lambda_1 = 1
$$

$$
x_2 = \frac{B - D}{|B - D|} 
    = \frac{1}{\sqrt{W^2 + H^2}} \begin{pmatrix}
                                 W \\ 
                                 -H
                                 \end{pmatrix}
, \quad 
\lambda_2 = N
$$

$$
M x_1 = \lambda_1 x_1 = x_1
, \quad 
M x_2 = \lambda_2 x_2 = N x_2 
$$

The idea is now to create a system of equations that we could solve on paper
or automatically using the computer:
From two multiplications of the matrix with a vector each, we can form one
equation where we multiply the matrix $M$ with another matrix that is composed
of the two input vectors, which then equals another matrix that is composed of
the two output vectors.:

$$
\begin{align}
M \begin{pmatrix} x_1 & x_2 \end{pmatrix} 
&= 
\begin{pmatrix} \lambda_1 x_1 & \lambda_2 x_2 \end{pmatrix} \\
M X &= X_\lambda
\end{align}
$$

Libraries for Linear Algebra (e.g.
[numpy](https://numpy.org/doc/stable/reference/generated/numpy.linalg.solve.html),
[MATLAB](https://www.mathworks.com/help/symbolic/linsolve.html),
and [GNU Octave](https://octave.sourceforge.io/octave/function/linsolve.html))
have functions for solving linear systems of equations.
They all work with a matrix equation like $AX = B$:
Calling $\text{solve}(A, B)$ returns the solution of $X$.
At this point, we can't just run $\text{solve}(X, X_\lambda)$ because $M$ and 
$X$ first need to be swapped to fit the input format.

Using known [transposition properties](https://en.wikipedia.org/wiki/Transpose),
we can quickly bring our system of equations to the right form by transposing
the matrices:

$$
\begin{align}
( M X )^\intercal &= X_\lambda^\intercal \\
X^\intercal M^\intercal &= X_\lambda^\intercal \\
M^\intercal &= \mathrm{solve}(X^\intercal, X_\lambda^\intercal) \\
M &= \mathrm{solve}(X^\intercal, X_\lambda^\intercal)^\intercal
\end{align}
$$

...and *now* we can finally solve the system automatically.

## Solving the Equations

<div class="floating-image-right">
  ![GNU Octave is great](/images/gnu-octave-example-mesh.svg){width=300px}
</div>

Back in my university days, I used the proprietary 
[MATLAB](https://www.mathworks.com/products/matlab.html) suite to do such tasks 
with just very few lines of code, which students got for free.
I am not a student at a university any longer, so when choosing software, I 
generally first have a look if there is free software before choosing anything 
proprietary.
In hindsight, I also find it a great pity that my university 
([RWTH Aachen](https://www.rwth-aachen.de/) in Germany)
played a part in luring its students into a comfortable dependency on very 
expensive proprietary tools (apart from that it is a super awesome university). 
The free solutions available at the same time would not have been less suitable 
for educational purposes.

Luckily, [GNU Octave](https://octave.org/) exists and it can do many many things
just like MATLAB.
What I also like about GNU Octave:

- It's a much smaller package (with a package manager and a 
  [package ecosystem](https://gnu-octave.github.io/packages/), so you can choose 
  what you need)
- You can run it without being connected to an annoying license server
- It runs in the shell so you don't have to launch a big IDE for everything
  (Maybe that has changed in the last 10 years, but I doubt it)

So let's write a very short script that calculates our parametrized Matrix $M$:


```octave
# filename: octave-script.m
pkg load symbolic

syms W H N

x1 = [W; H]
x2 = [W;-H]

M = transpose(transpose([x1,x2]) \ transpose([x1,N * x2]))
```

In my later program, I wanted not only `N` to be an input parameter, but also
the image dimensions `W` and `H`, so we have three symbols in this program.
I also left out the division by the length of the main vectors $x_1$ and $x_2$,
because they would cancel out in the resulting system of equations anyway
(try it out to see yourself).

I typically don't have special tools like this installed on my system, because
[NixOS](https://nixos.org) makes it so easy to install project-specific tools in
project-specific shells.
In the nixpkgs ecosystem, `octave` is a package that can be preloaded with the
user's package selection from the octave ecosystem.
The program at hand only needs the 
[`symbolic`](https://gnu-octave.github.io/packages/symbolic/) package.
I just added the `myOctave` symbol from the following code to the nix flake of
my C++ project.

It is also possible to run a shell with just octave, without a project around
it, by running this script through `nix-shell`:

```nix
let pkgs = import <nixpkgs> { };
    myOctave = pkgs.octave.passthru.withPackages (p: with p; [
      symbolic
    ]);

in pkgs.mkShell { nativeBuildInputs = [ myOctave ]; }
```

Let's see it in action:

```octave
$ nix-shell octave-shell.nix
[nix-shell:~]$ octave octave-script.m
...

M = (sym 2×2 matrix)

  ⎡  N   1    W⋅(1 - N)⎤
  ⎢  ─ + ─    ─────────⎥
  ⎢  2   2       2⋅H   ⎥
  ⎢                    ⎥
  ⎢H⋅(1 - N)    N   1  ⎥
  ⎢─────────    ─ + ─  ⎥
  ⎣   2⋅W       2   2  ⎦
```

Voilà, that's the matrix that we needed!

It's very rewarding to see how the matrix collapses to an identity matrix if
we define $N = 0$.

## Using the Matrix in C++

We can now take this solution and simply implement it 1:1 in our target 
language, which is C++ in this case.
The matrix type that is used in OpenCV is 
[the `cv::Mat` type](https://docs.opencv.org/4.x/d6/d6d/tutorial_mat_the_basic_image_container.html),
which can be constructed like this:

```cpp
cv::Mat shearingMatrix(const cv::Size &s, double n) {
  const float w = s.width, h = s.height;

  return cv::Mat_<float>(3, 3) << 
    n / 2.0 + 0.5,           (1.0 - n) / 2.0 * w / h, 0,
    (1.0 - n) / 2.0 * h / w, n / 2.0 + 0.5,           0, 
    0,                       0,                       1;
}
```

## Summary

GNU Octave is fun to use once it's installed.
I only use it in such rare cases that I don't install it regularly on my 
systems.
It was however very easy to integrate into the project-specific shell.
This way everyone who takes part in the development of this repository can also 
execute the Octave scripts that have been used to derive some of the C++ code.
If any upfront requirement changes that led to the design of specific code,
it's easy to change even the most complicated snippets.
