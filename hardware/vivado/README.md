# Vivado Integration

`vivado_project_files.zip` contains the final Vivado 2024.2 project file, final `system_bd.bd`, generated wrapper, and Basys3 XDC used for the hardware demonstration.

The custom IP source archives are stored under `hardware/ip/`. From the repository root, run:

```bash
python3 hardware/vivado/scripts/prepare_vivado_project.py
```

Then open:

```text
hardware/vivado/project/redundant_link/redundant_link.xpr
```

The Digilent Basys3 board files must be installed in Vivado. Regenerate Block Design output products if Vivado requests it.
