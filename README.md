# MESTI

**MESTI** (Maxwell's Equations Solver with Thousands of Inputs) is an open-source software for full-wave electromagnetic simulations in frequency domain using finite-difference discretization on the [Yee lattice](https://meep.readthedocs.io/en/latest/Yee_Lattice).

MESTI implements the **augmented partial factorization (APF)** method described in [this paper](https://doi.org/10.1038/s43588-022-00370-6). While conventional methods solve Maxwell's equations on every element of the discretization basis set (which contains much more information than is typically needed), APF bypasses such intermediate solution step and directly computes the information of interest: a generalized scattering matrix given any list of input source profiles and any list of output projection profiles. It can jointly handle thousands of inputs without a loop over them, using fewer computing resources than what a conventional direct method uses to handle a single input. It is exact with no approximation beyond discretization.

MESTI.m here uses MATLAB with double-precision arithmetic and considers 2D systems either in transverse-magnetic (TM) polarization (*Hx*,*Hy*,*Ez*) with

$$
\left[ -\frac{\partial^2}{\partial x^2} -\frac{\partial^2}{\partial y^2} - \frac{\omega^2}{c^2}\varepsilon(x,y) \right] E_z(x,y)= b(x,y),
$$

or in transverse-electric (TE) polarization (*Ex*,*Ey*,*Hz*) with

```math
\begin{align*}
&\left[
-\frac{\partial}{\partial x}\left(\varepsilon^{-1}\right)_{yy}(x,y) \frac{\partial}{\partial x}
-\frac{\partial}{\partial y}\left(\varepsilon^{-1}\right)_{xx}(x,y) \frac{\partial}{\partial y} \right. \\
&\,\,\,\left. +\frac{\partial}{\partial y}\left(\varepsilon^{-1}\right)_{xy}(x,y) \frac{\partial}{\partial x}
+\frac{\partial}{\partial x}\left(\varepsilon^{-1}\right)_{yx}(x,y) \frac{\partial}{\partial y} - \frac{\omega^2}{c^2} \right] H_z(x,y) = b(x,y),
\end{align*}
```

where *b*(*x*,*y*) is the source profile.

A 3D vectorial version written in Julia, to be named MESTI.jl, is under development and will be released in the near future. In addition to 3D vectorial support, MESTI.jl will also provide MPI parallelization, subpixel smoothing, and single-precision arithmetic.

MESTI.m is a general-purpose solver with its interface written to provide maximal flexibility. It supports
 - TM or TE polarization.
 - Any relative permittivity profile *ε*(*x*,*y*), real-valued or complex-valued. The imaginary part of *ε*(*x*,*y*) describes absorption and linear gain. Users can optionally average the interface pixels for [subpixel smoothing](https://meep.readthedocs.io/en/latest/Subpixel_Smoothing) (which produces an anisotropic *ε* in TE polarization) before calling MESTI.
 - Infinite open spaces can be described with a [perfectly matched layer (PML)](https://en.wikipedia.org/wiki/Perfectly_matched_layer) placed on any side(s), which also allows for infinite substrates, waveguides, photonic crystals, *etc*. The PML implemented in MESTI includes both imaginary-coordinate and real-coordinate stretching, so it can accelerate the attenuation of evanescent waves in addition to attenuating the propagating waves.
 - Any material dispersion *ε*(*ω*) can be used since this is in frequency domain.
 - Any list of input source profiles (user-specified or automatically built).
 - Any list of output projection profiles (or no projection, in which case the complete field profiles are returned).
 - Periodic, Bloch periodic, perfect electrical conductor (PEC), and/or perfect magnetic conductor (PMC) boundary conditions.
 - Exact outgoing boundaries in two-sided or one-sided geometries.
 - Real-valued or complex-valued frequency *ω*.
 - Automatic or manual choice between APF, conventional direct solver (*e.g.*, to compute the full field profile), and the [recursive Green's function method](https://github.com/chiaweihsu/RGF) as the solution method.
 - Linear solver using MUMPS (requires installation) or the built-in routines in MATLAB (which uses UMFPACK).
 - Shared memory parallelism (with multithreaded BLAS and with OpenMP in MUMPS).

## When to use MESTI?

MESTI.m can perform most linear-response computations in 2D and 1D for arbitrary structures, such as

- Scattering problems: [transmission](./examples/2d_metalens), [reflection](./examples/2d_reflection_matrix_Gaussian_beams), [transport through complex media](./examples/2d_open_channel_through_disorder), waveguide bent, grating coupler, radar cross-section, controlled-source electromagnetic surveys, *etc*.
- Thermal emission.
- Local density of states.
- [Inverse design](https://github.com/complexphoton/APF_inverse_design) based on the above quantities.

Since MESTI can use the APF method to handle a large number of input states simultaneously, the computational advantage of MESTI is the most pronounced in multi-input systems.

There are use cases that MESTI.m can handle but is not necessarily the most efficient, such as
- Broadband response problems involving many frequencies but only a few input states. Time-domain methods like FDTD may be preferred as they can compute a broadband response without looping over frequencies.
- Problems like plasmonics that require more than an order of magnitude difference in the discretization grid size at different regions of the structure. Finite-element methods may be preferred as they can handle varying spatial resolutions. (Finite-element methods can also adopt APF, but MESTI uses finite difference with a fixed grid size.)
- Homogeneous structures with a small surface-to-volume ratio. Boundary element methods may be preferred as they only discretize the surface.

Problems that MESTI.m currently does not handle:
- 3D systems. The upcoming MESTI.jl will take care of this.
- Nonlinear systems (*e.g.*, *χ*<sup>(2)</sup>, *χ*<sup>(3)</sup>, gain media).
- Magnetic systems (*e.g.*, spatially varying permeability *μ*)

For eigenmode computation, such as waveguide mode solver and photonic band structure computation, one can use [<code>mesti_build_fdfd_matrix.m</code>](./src/mesti_build_fdfd_matrix.m) to build the matrix and then compute its eigenmodes. However, we don't currently provide a dedicated function to do so.

## Installation

No installation is required for MESTI itself. To use, simply download it and add the <code>MESTI.m/src</code> folder to the MATLAB search path using the <code>addpath</code> command. The MATLAB version should be R2019b or later. (Using an earlier version is possible but requires minor edits.)

However, to use the APF method, the user needs to install the serial version of [MUMPS](https://graal.ens-lyon.fr/MUMPS/index.php) and its MATLAB interface (note: the serial version of MUMPS already supports multithreading). Without MUMPS, MESTI will still run but will only use other methods, which generally take longer and use more memory. So, MUMPS installation is strongly recommended for large-scale multi-input simulations or whenever efficiency is important. See this [MUMPS installation](./mumps) page for steps to install MUMPS.

## Usage Summary 

The function [<code>mesti(syst, B, C, D)</code>](./src/mesti.m) provides the most flexibility. Structure <code>syst</code> specifies the polarization to use, permittivity profile, boundary conditions in *x* and *y*, which side(s) to put PML with what parameters, the wavelength, and the discretization grid size. Any list of input source profiles can be specified with matrix <code>B</code>, each column of which specifies one source profile *b*(*x*,*y*). Any list of output projection profiles can be specified with matrix <code>C</code>. Matrix <code>D</code> is optional (treated as zero when not specified) and subtracts the baseline contribution; see [this paper](https://doi.org/10.1038/s43588-022-00370-6) for details.

The function [<code>mesti2s(syst, in, out)</code>](./src/mesti2s.m) deals specifically with scattering problems in two-sided or one-sided geometries where *ε*(*x*,*y*) consists of an inhomogeneous scattering region with homogeneous spaces on the left (*-x*) and right (*+x*), light is incident from the left and/or right, the boundary condition in *x* is outgoing, and the boundary condition in *y* is closed (*e.g.*, periodic or PEC). The user only needs to specify the input and output sides or channel indices or wavefronts through <code>in</code> and <code>out</code>. The function <code>mesti2s()</code> automatically builds the source matrix <code>B</code>, projection matrix <code>C</code>, baseline matrix <code>D</code>, and calls <code>mesti()</code> for the computation.
Flux normalization in *x* is applied automatically and exactly, so the full scattering matrix is always unitary when *ε*(*x*,*y*) is real-valued.
<code>mesti2s()</code> also offers the additional features of (1) exact outgoing boundaries in *x* based on the Green's function in free space, and (2) the [recursive Green's function method](https://github.com/chiaweihsu/RGF) when TM polarization is used; they are efficient for 1D systems and for 2D systems where the width in *y* is not large. 

To compute the complete field profiles, simply omit the argument <code>C</code> or  <code>out</code>, or set it to <code>[]</code>.

The solution method, the linear solver to use, and other options can be specified with a structure <code>opts</code> as an optional input argument to <code>mesti()</code> or <code>mesti2s()</code>; see documentation for details. They are chosen automatically when not explicitly specified.

The function [<code>mesti_build_channels()</code>](./src/mesti_build_channels.m) can be used to build the input and/or output matrices when using <code>mesti()</code>, or to determine which channels are of interest when using <code>mesti2s()</code>.

Additional functions that build the input/output matrices for different applications and the anisotropic *ε*(*x*,*y*) from subpixel smoothing will be added in the future.

## Documentation

Detailed documentation is given in comments at the beginning of the function files:
 - [<code>mesti.m</code>](./src/mesti.m)
 - [<code>mesti2s.m</code>](./src/mesti2s.m)
 - [<code>mesti_build_channels.m</code>](./src/mesti_build_channels.m)

For example, typing <code>help mesti</code> in MATLAB brings up the documentation for <code>mesti()</code>.

## Examples

Examples in the [examples](./examples) folder illustrate the usage and the main functionalities of MESTI. Each example has its own folder, with its <code>.m</code> script, auxiliary files specific to that example, and a <code>README.md</code> page that shows the example script with its outputs:

- [Fabry–Pérot etalon](./examples/1d_fabry_perot): 1D, using <code>mesti2s()</code>, with comparison to analytic solution.
- [Distributed Bragg reflector](./examples/1d_distributed_bragg_reflector): 1D, using <code>mesti2s()</code>, with comparison to analytic solution.
- [Open channel in a disordered system](./examples/2d_open_channel_through_disorder): 2D, using <code>mesti2s()</code>, transmission matrix & field profile with customized wavefronts.
-  [Reflection matrix in Gaussian-beam basis](./examples/2d_reflection_matrix_Gaussian_beams): 2D, using <code>mesti()</code>, reflection matrix in customized basis for a fully open system.
- [Meta-atom design for metasurfaces](./examples/2d_meta_atom): 2D, using <code>mesti2s()</code> with Bloch periodic boundary.
- [Angle dependence of a mm-wide metalens](./examples/2d_metalens): 2D, using <code>mesti()</code> with compressed input/output matrices (APF-c).

Also see the following repository:
- [APF inverse design](https://github.com/complexphoton/APF_inverse_design): How to use MESTI to perform inverse design.

## Gallery
Here are some animations from the examples above:

1. Propagation through a Fabry–Pérot etalon
<img src="./examples/1d_fabry_perot/fabry_perot_field_profile.gif" width="336" height="264"> 

2. Open channel propagating through disorder
<img src="./examples/2d_open_channel_through_disorder/disorder_open_channel.gif" width="530" height="398"> 

3. Reflection matrix of a scatterer in Gaussian-beam basis:
<img src="./examples/2d_reflection_matrix_Gaussian_beams/reflection_matrix_Gaussian_beams.gif" width="438" height="252"> 

4. Angle dependence of a mm-wide hyperbolic metalens
<img src="./examples/2d_metalens/metalens_animation.gif" width="580" height="297"> 

5. Inverse design of a wide-angle metasurface beamsplitter
<img src="https://github.com/complexphoton/APF_inverse_design/blob/main/inverse_design_codes/animated_opt.gif" width="480" height="276"> 

## Reference & Credit

For more information on the theory, capability, and benchmarks (*e.g.*, scaling of computing time, memory usage, and accuracy), please see:

- Ho-Chun Lin, Zeyu Wang, and Chia Wei Hsu. [Fast multi-source nanophotonic simulations using augmented partial factorization](https://doi.org/10.1038/s43588-022-00370-6). *Nature Computational Science* **2**, 815–822 (2022).

```bibtex
@article{2022_Lin_NCS,
  title = {Fast multi-source nanophotonic simulations using augmented partial factorization},
  author = {Lin, Ho-Chun and Wang, Zeyu and Hsu, Chia Wei},
  journal = {Nat. Comput. Sci.},
  volume = {2},
  issue = {12},
  pages = {815--822},
  year = {2022},
  month = {Dec},
  doi = {10.1038/s43588-022-00370-6}
}
```

Please cite this paper when you use MESTI.
