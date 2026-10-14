# References

For general citation of the PICLas framework, please refer to *Citing PICLas* in the `README.md`.
If your work relies on specific methods implemented in PICLas, please also cite the corresponding publications listed below.

## Particle-in-Cell

- For the high-order Maxwell DG method:
```bibtex
@article{piclas_munz,
    author = {Claus-Dieter Munz and Monika Auweter-Kurtz and Stefanos Fasoulas and Asim Mirza and Philip Ortwein and Marcel Pfeiffer and Torsten Stindl},
    title = {Coupled Particle-In-Cell and Direct Simulation Monte Carlo method for simulating reactive plasma flows},
    journal = {Comptes Rendus Mécanique},
    volume = {342},
    number = {10},
    pages = {662-670},
    year = {2014},
    issn = {1631-0721},
    doi = {https://doi.org/10.1016/j.crme.2014.07.005},
    }
```

- For the high-order Poisson DG method:
```bibtex
@article{piclas_pfeiffer,
title={A particle-in-cell solver based on a high-order hybridizable discontinuous Galerkin spectral element method on unstructured curved meshes},
author={Pfeiffer, M and Hindenlang, F and Binder, T and Copplestone, SM and Munz, C-D and Fasoulas, S},
journal={Computer Methods in Applied Mechanics and Engineering},
volume={349},
pages={149--166},
year={2019},
publisher={Elsevier}
    }
```

## Rarefied gas flows

- For the particle-based BGK methods (ESBGK, SBGK, BGK):
```bibtex
@article{Pfeiffer2018a,
    author = {Pfeiffer, Marcel},
    title = {Particle-based fluid dynamics: Comparison of different Bhatnagar-Gross-Krook models and the direct simulation Monte Carlo method for hypersonic flows},
    journal = {Physics of Fluids},
    volume = {30},
    number = {10},
    pages = {106106},
    year = {2018},
    doi = {10.1063/1.5042016},
    }
```

- For the BGK methods with diatomic species including quantized vibrational energies:
```bibtex
@article{Pfeiffer2018b,
    author = {Pfeiffer, Marcel},
    title = {Extending the particle ellipsoidal statistical Bhatnagar-Gross-Krook method to diatomic molecules including quantized vibrational energies},
    journal = {Physics of Fluids},
    volume = {30},
    number = {11},
    pages = {116103},
    year = {2018},
    doi = {10.1063/1.5054961},
    }
```

- For the multi-species ESBGK method for monatomic gas mixtures:
```bibtex
@article{Pfeiffer2021,
    author = {Pfeiffer, Marcel and Mirza, Asim and Nizenkov, Paul},
    title = {Multi-species modeling in the particle-based ellipsoidal statistical Bhatnagar–Gross–Krook method for monatomic gas species},
    journal = {Physics of Fluids},
    volume = {33},
    pages = {036106},
    year = {2021},
    doi = {10.1063/5.0037915},
    }
```

- For the multi-species ESBGK method for polyatomic gas mixtures including internal degrees of freedom:
```bibtex
@article{hild_multi-species_2024,
    author = {Hild, F. and Pfeiffer, M.},
    title = {Multi-species modeling in the particle-based ellipsoidal statistical Bhatnagar-Gross-Krook method including internal degrees of freedom},
    journal = {Journal of Computational Physics},
    volume = {514},
    pages = {113226},
    year = {2024},
    doi = {10.1016/j.jcp.2024.113226},
    }
```

- For the particle-based Fokker-Planck methods (cubic and ellipsoidal statistical FP):
```bibtex
@article{Pfeiffer2017,
    author = {Pfeiffer, Marcel and Gorji, M. Hossein},
    title = {Adaptive particle–cell algorithm for Fokker–Planck based rarefied gas flow simulations},
    journal = {Computer Physics Communications},
    volume = {213},
    pages = {1--8},
    year = {2017},
    doi = {10.1016/j.cpc.2016.11.003},
    }
@article{Jun2019,
    title = {Comparative {Study} {Between} {Cubic} and {Ellipsoidal} {Fokker}–{Planck} {Kinetic} {Models}},
    volume = {57},
    url = {https://arc.aiaa.org/doi/10.2514/1.J057935},
    doi = {10.2514/1.J057935},
    number = {6},
    journal = {AIAA Journal},
    author = {Jun, Eunji and Pfeiffer, Marcel and Mieussens, Luc and Gorji, M. Hossein},
    year = {2019},
    pages = {2524--2533},
}
```

- For the coupling of BGK/FP methods with DSMC:
```bibtex
@article{Pfeiffer2019a,
    author = {Pfeiffer, M. and Mirza, A. and Nizenkov, P.},
    title = {Evaluation of particle-based continuum methods for a coupling with the direct simulation Monte Carlo method based on a nozzle expansion},
    journal = {Physics of Fluids},
    volume = {31},
    number = {7},
    pages = {073601},
    year = {2019},
    doi = {10.1063/1.5098085},
    }
```

## Gas-surface interaction

- For machine learning based gas-surface scattering:
```bibtex
@misc{piclas_schuette,
    title={Conditional Normalizing Flow for Gas-Surface Scattering from Thermal to Hypersonic Velocities},
    author={Miklas Schütte and Stephen Hocker and Hansjörg Lipp and Johannes Roth and Stefanos Fasoulas and Marcel Pfeiffer},
    year={2026},
    eprint={2606.31928},
    archivePrefix={arXiv},
    primaryClass={physics.comp-ph},
    url={https://arxiv.org/abs/2606.31928},
    }
```
