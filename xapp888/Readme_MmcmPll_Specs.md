# Calculation, Specification and settings for MMCM/PLL

This document provides the specifications and settings of the most commonly used
FPGA speed grades. For other speed grades consult the data sheet of the used FPGA.

Warning: The values given in below tables are values from datasheets in the Xilinx Document Navigator_2018.2 catalog. Make sure to check the values of the different primitives in newer datasheets and user guides.

For completeness, formula provided in the User Guides are repeated here:

The VCO frequency, which should be taken as high as possible, can be determined by:
$$
{F}_{VCO}={F}_{CLKIN} \Big(\frac{M}{D}\Big)
$$

$$
{F}_{VCOMIN} < {F}_{VCO} < {F}_{VCOMAX}
$$

Any of the six clock output frequencies can be found using this formula:
$$
{F}_{OUT}={F}_{CLKIN}\Big(\frac{M}{D*O}\Big)
$$
The M, D and O values control counters in the MMCM/PLL. When the MMCM/PLL is gong to be used in a static mode these M, D and O values can be passed through attributes used on instantiated primitives.  The value of M corresponds to the CLKFBOUT_MULT_F/CLKFBOUT_MULT setting, the value of D to the DIVCLK_DIVIDE, and O to the CLKOUTn_DIVIDE (n = number of the output). 
When these parameters are entered in HDL code or XDC files of the design the Vivado tool will calculate all necessary parameters for the counter registers in the MMCM/PLL.

When using the MMCM and or PLL in dynamic mode through the DRP port, one must manually calculate the register settings (XAPP888 can be a good guide here). 

**REMARK:** It is assumed that one using the given formulas will use parameter values within the allowable minimum and maximum specifications of the data sheet and DRP register settings. 
For convenience MMCM and PLL specifications, from the data sheets, are provided below.  

Use next equations to find the allowed M, D values for the best VCO frequency:
$$
{D}_{MIN}=_{roundup}\Big(\frac{{F}_{IN}}{{F}_{PFDMAX}}\Big)
$$

$$
{D}_{MAX}=_{rounddown}\Big(\frac{{F}_{IN}}{{F}_{PFDMAX}}\Big)
$$

$$
{M}_{MIN}=_{roundup}\Big(\frac{{F}_{VCOMIN}}{{F}_{IN}}{D}_{MIN}\Big)
$$

$$
{M}_{MAX}=_{rounddown}\Big(\frac{{F}_{VCOMAX}}{{F}_{IN}}{D}_{MAX}\Big)
$$

Using the input frequency, maximum VCO frequency and smallest D value, find the ideal value for M. 
$$
{M}_{IDEAL}=\frac{{D}_{MIN}{F}_{VCOMAX}}{{F}_{IN}}
$$
Use this M value as start point to find the final M value to make the VCO operate at its highest possible frequency. Use formula 3 in order to find the O parameter, determining the clock output frequency, for each of the used outputs.

------

### MMCME2
7-Series MMCM
Artix Specifications: -3, -2 and -1 for 1V0

| Symbol   |   -3    |   -2    |   -1    | Units |
|----------|---------|---------|---------|-------|
| Fin_max  |  800    |  800    |  800    | MHz   |
| Fin_min  |   10    |   10    |   10    | MHz   |
| Fpfd_max |  550    |  500    |  450    | MHz   |
| Fpfd_min |   10    |   10    |   10    | MHz   |
| Fvco_max | 1600    | 1440    | 1200    | MHz   |
| Fvco_min |  600    |  600    |  600    | MHz   |
| Fout_max |  800    |  800    |  800    | MHz   |
| Fout_min |    4.69 |    4.69 |    4.69 | MHz   |

Kintex Specifications: -3, -2 and -1 for 1V0
| Symbol   |   -3    |   -2    |   -1    | Units |
|----------|---------|---------|---------|-------|
| Fin_max  | 1066    |  933    |  800    | MHz   |
| Fin_min  |   10    |   10    |   10    | MHz   |
| Fpfd_max |  550    |  500    |  450    | MHz   |
| Fpfd_min |   10    |   10    |   10    | MHz   |
| Fvco_max | 1600    | 1440    | 1200    | MHz   |
| Fvco_min |  600    |  600    |  600    | MHz   |
| Fout_max | 1066    |  933    |  800    | MHz   |
| Fout_min |    4.69 |    4.69 |    4.69 | MHz   |

Virtex Specifications: -3, -2 and -1 for 1V0
| Symbol   |   -3    |   -2    |   -1    | Units |
|----------|---------|---------|---------|-------|
| Fin_max  | 1066    |  933    |  800    | MHz   |
| Fin_min  |   10    |   10    |   10    | MHz   |
| Fpfd_max |  550    |  500    |  450    | MHz   |
| Fpfd_min |   10    |   10    |   10    | MHz   |
| Fvco_max | 1600    | 1440    | 1200    | MHz   |
| Fvco_min |  600    |  600    |  600    | MHz   |
| Fout_max | 1066    |  933    |  800    | MHz   |
| Fout_min |    4.69 |    4.69 |    4.69 | MHz   |

Attribute/Parameters
  Given parameters in the table are the most important one For
  calculation of the MMCM values. All the other parameters can be
  found in the 7-Series Clocking Guide (UG472).

|        Attribute       |    Allowed Values    |  Default  |
|------------------------|----------------------|-----------|
| BANDWIDTH              | LOW, HIGH, OPTIMIZED | OPTIMIZED |
| CLKOUT[0]_DIVIDE       | 1.000 to 128.000     | 1         |
| CLKOUT[1:6]_DIVIDE     | 1 to 128             | 1         |
| CLKOUT[0:6]_PHASE      | -360 to 360          | 0.0       |
| CLKOUT[0:6]_DUTY_CYCLE | 0.01 to 0.99         | 0.50      |
| CLKFBOUT_MULT_F        | 2 to 64              | 5         |
| CLKFBOUT_PHASE         | 0.000 to 360.000     | 0.000     |
| DIVCLK_DIVIDE          | 1 to 106             | 1         |
<div style="page-break-after: always;"></div>

### MMCME3
Ultrascale MMCM

Kintex Specifications: -3, -2 and -1 for 1V0
| Symbol   |   -3    |   -2    |   -1    | Units |
|----------|---------|---------|---------|-------|
| Fin_max  | 1066    |  933    |  800    | MHz   |
| Fin_min  |   10    |   10    |   10    | MHz   |
| Fpfd_max |  550    |  500    |  450    | MHz   |
| Fpfd_min |   10    |   10    |   10    | MHz   |
| Fvco_max | 1600    | 1440    | 1200    | MHz   |
| Fvco_min |  600    |  600    |  600    | MHz   |
| Fout_max |  850    |  725    |  630    | MHz   |
| Fout_min |    4.69 |    4.69 |    4.69 | MHz   |

Virtex Specifications: -3, -2 and -1 for 1V0
| Symbol   |   -3    |   -2    |   -1    | Units |
|----------|---------|---------|---------|-------|
| Fin_max  | 1066    |  933    |  800    | MHz   |
| Fin_min  |   10    |   10    |   10    | MHz   |
| Fpfd_max |  550    |  500    |  500    | MHz   |
| Fpfd_min |   10    |   10    |   10    | MHz   |
| Fvco_max | 1600    | 1440    | 1440    | MHz   |
| Fvco_min |  600    |  600    |  600    | MHz   |
| Fout_max |  850    |  725    |  725    | MHz   |
| Fout_min |    4.69 |    4.69 |    4.69 | MHz   |

Attribute/Parameters
  Given parameters in the table are the most important one For
  calculation of the MMCM values. All the other parameters can be
  found in the Ultrascale - Ultrascale-Plus Clocking Guide (UG572).

| Attribute              | Allowed Values                     | Default   |
| ---------------------- | ---------------------------------- | --------- |
| BANDWIDTH              | LOW, HIGH, OPTIMIZED or POSTCRC[1] | OPTIMIZED |
| CLKOUT[0]_DIVIDE       | 2.000 to 128.000                   | 1         |
| CLKOUT[1:6]_DIVIDE     | 1 to 128                           | 1         |
| CLKOUT[0:6]_PHASE      | -360 to 360                        | 0.0       |
| CLKOUT[0:6]_DUTY_CYCLE | 0.01 to 0.99                       | 0.50      |
| CLKFBOUT_MULT_F        | 2 to 64                            | 5         |
| CLKFBOUT_PHASE         | -360.000 to 360.000                | 0.000     |
| DIVCLK_DIVIDE          | 1 to 106                           | 1         |
[1]: One valid when used with the SEM-IP core.

### MCME4

Ultrascale-Plus MMCM

Kintex Specifications: -3, -2 and -1 for 1V0
| Symbol   |   -3    |   -2    |   -1    | Units |
|----------|---------|---------|---------|-------|
| Fin_max  | 1066    |  933    |  800    | MHz   |
| Fin_min  |   10    |   10    |   10    | MHz   |
| Fpfd_max |  550    |  500    |  450    | MHz   |
| Fpfd_min |   10    |   10    |   10    | MHz   |
| Fvco_max | 1600    | 1600    | 1600    | MHz   |
| Fvco_min |  800    |  800    |  800    | MHz   |
| Fout_max |  891    |  775    |  667    | MHz   |
| Fout_min |    6.25 |    6.25 |    6.25 | MHz   |

Virtex Specifications: -3, -2 and -1 for 1V0
| Symbol   |   -3    |   -2    |   -1    | Units |
|----------|---------|---------|---------|-------|
| Fin_max  | 1066    |  933    |  800    | MHz   |
| Fin_min  |   70    |   70    |   70    | MHz   |
| Fpfd_max |  667.5  |  667.5  |  667.5  | MHz   |
| Fpfd_min |   70    |   70    |   70    | MHz   |
| Fvco_max | 1500    | 1500    | 1500    | MHz   |
| Fvco_min |  750    |  750    |  750    | MHz   |
| Fout_max |  891    |  775    |  667    | MHz   |
| Fout_min |    5.86 |    5.86 |    5.86 | MHz   |

Attribute/Parameters
  Given parameters in the table are the most important one For
  calculation of the MMCM values. All the other parameters can be
  found in the Ultrascale - Ultrascale-Plus Clocking Guide (UG572).
| Attribute              | Allowed Values                     | Default   |
| ---------------------- | ---------------------------------- | --------- |
| BANDWIDTH              | LOW, HIGH, OPTIMIZED or POSTCRC[1] | OPTIMIZED |
| CLKOUT[0]_DIVIDE       | 2.000 to 128.000                   | 1         |
| CLKOUT[1:6]_DIVIDE     | 1 to 128                           | 1         |
| CLKOUT[0:6]_PHASE      | -360 to 360                        | 0.0       |
| CLKOUT[0:6]_DUTY_CYCLE | 0.01 to 0.99                       | 0.50      |
| CLKFBOUT_MULT_F        | 2 to 128                           | 5         |
| CLKFBOUT_PHASE         | -360.000 to 360.000                | 0.000     |
| DIVCLK_DIVIDE          | 1 to 106                           | 1         |
[1]: One valid when used with the SEM-IP core.

<div style="page-break-after: always;"></div>

### PLLE2
7-Series PLL
Artix Specifications: -3, -2 and -1 for 1V0

| Symbol   |    -3   |    -2   |    -1   | Units |
|----------|---------|---------|---------| ----- |
| Fin_max  |  800    |  800    |  800    | MHz   |
| Fin_min  |   19    |   19    |   19    | MHz   |
| Fpfd_max |  550    |  500    |  450    | MHz   |
| Fpfd_min |   19    |   19    |   19    | MHz   |
| Fvco_max | 3133    | 1866    | 1600    | MHz   |
| Fvco_min |  800    |  800    |  800    | MHz   |
| Fout_max |  800    |  800    |  800    | MHz   |
| Fout_min |    6.25 |    6.25 |    6.25 | MHz   |

Kintex Specifications: -3, -2 and -1 for 1V0
| Symbol   |    -3   |    -2   |    -1   | Units |
|----------|---------|---------|---------|-------|
| Fin_max  | 1066    |  933    |  800    | MHz   |
| Fin_min  |   19    |   19    |   19    | MHz   |
| Fpfd_max |  550    |  500    |  450    | MHz   |
| Fpfd_min |   19    |   19    |   19    | MHz   |
| Fvco_max | 2133    | 1866    | 1600    | MHz   |
| Fvco_min |  800    |  800    |  800    | MHz   |
| Fout_max | 1066    |  933    |  800    | MHz   |
| Fout_min |    6.25 |    6.25 |    6.25 | MHz   |

Virtex Specifications: -3, -2 and -1 for 1V0
| Symbol   |    -3   |    -2   |    -1   | Units |
|----------|---------|---------|---------|-------|
| Fin_max  | 1066    |  933    |  800    | MHz   |
| Fin_min  |   19    |   19    |   19    | MHz   |
| Fpfd_max |  550    |  500    |  450    | MHz   |
| Fpfd_min |   19    |   19    |   19    | MHz   |
| Fvco_max | 2133    | 1866    | 1600    | MHz   |
| Fvco_min |  800    |  800    |  800    | MHz   |
| Fout_max | 1066    |  933    |  800    | MHz   |
| Fout_min |    6.25 |    6.25 |    6.25 | MHz   |

Attribute/Parameters
  Given parameters in the table are the most important one For
  calculation of the MMCM values. All the other parameters can be
  found in the 7-Series Clocking Guide (UG472).

| Attribute              | Allowed Values       | Default   |
| ---------------------- | -------------------- | --------- |
| BANDWIDTH              | LOW, HIGH, OPTIMIZED | OPTIMIZED |
| CLKOUT[0:5]_DIVIDE     | 1 to 128             | 1         |
| CLKOUT[0:5]_PHASE      | -360 to 360          | 0.0       |
| CLKOUT[0:5]_DUTY_CYCLE | 0.01 to 0.99         | 0.50      |
| CLKFBOUT_MULT          | 2 to 64              | 5         |
| CLKFBOUT_PHASE         | 0.000 to 360.000     | 0.000     |
| DIVCLK_DIVIDE          | 1 to 56              | 1         |
<div style="page-break-after: always;"></div>

### PLLE3
Ultrascale PLL

Kintex Specifications: -3 for 1V0, -2 and -1 for 0V95
| Symbol   |    -3   |   -2    |  -1     | Units |
|----------|---------|---------|---------|-------|
| Fin_max  | 1066    |  933    |  800    | MHz   |
| Fin_min  |   70    |   70    |   70    | MHz   |
| Fpfd_max |  667.5  |  667.5  |  667.5  | MHz   |
| Fpfd_min |   70    |   70    |   70    | MHz   |
| Fvco_max | 1335    | 1335    | 1200    | MHz   |
| Fvco_min |  600    |  600    |  600    | MHz   |
| Fout_max |  850    |  725    |  630    | MHz   |
| Fout_min |    4.69 |    4.69 |    4.69 | MHz   |

Virtex Specifications: -3 for 1V0, -2 and -1 for 0V95
| Symbol   |   -3    |   -2    |   -1    | Units |
|----------|---------|---------|---------|-------|
| Fin_max  | 1066    |  933    |  800    | MHz   |
| Fin_min  |   70    |   70    |   70    | MHz   |
| Fpfd_max |  667.5  |  667.5  |  667.5  | MHz   |
| Fpfd_min |   70    |   70    |   70    | MHz   |
| Fvco_max | 1335    | 1335    | 1200    | MHz   |
| Fvco_min |  600    |  600    |  600    | MHz   |
| Fout_max |  850    |  725    |  725    | MHz   |
| Fout_min |    4.69 |    4.69 |    4.69 | MHz   |

Attribute/Parameters
  Given parameters in the table are the most important one For
  calculation of the MMCM values. All the other parameters can be
  found in the Ultrascale - Ultrascale-Plus Clocking Guide (UG572).

| Attribute              | Allowed Values      | Default |
| ---------------------- | ------------------- | ------- |
| CLKOUT[0:1]_DIVIDE     | 1 to 128            | 1       |
| CLKOUT[0:6]_PHASE      | -360.000 to 360.000 | 0.0     |
| CLKOUT[0:1]_DUTY_CYCLE | 0.01 to 0.99        | 0.50    |
| CLKFBOUT_MULT          | 2 to 21             | 5       |
| CLKFBOUT_PHASE         | -360.000 to 360.000 | 0.000   |
| DIVCLK_DIVIDE          | 1 to 15             | 1       |
<div style="page-break-after: always;"></div>

### PLLE4
Ultrascale-Plus PLL

Kintex Specifications: -3 for 0V9, -2 and -1 for 0V85
| Symbol   |   -3    |   -2    |   -1    | Units |
|----------|---------|---------|---------|-------|
| Fin_max  | 1066    |  933    |  800    | MHz   |
| Fin_min  |   70    |   70    |   70    | MHz   |
| Fpfd_max |  667.5  |  667.5  |  667.5  | MHz   |
| Fpfd_min |   70    |   70    |   70    | MHz   |
| Fvco_max | 1500    | 1500    | 1500    | MHz   |
| Fvco_min |  750    |  750    |  750    | MHz   |
| Fout_max |  891    |  775    |  667    | MHz   |
| Fout_min |    5.86 |    5.86 |    5.86 | MHz   |

Virtex Specifications: -3 for 0V90, -2 and -1 for 0V85
| Symbol   |   -3    |   -2    |   -1    | Units |
|----------|---------|---------|---------|-------|
| Fin_max  | 1066    |  933    |  800    | MHz   |
| Fin_min  |   70    |   70    |   70    | MHz   |
| Fpfd_max |  667.5  |  667.5  |  667.5  | MHz   |
| Fpfd_min |   70    |   70    |   70    | MHz   |
| Fvco_max | 1500    | 1500    | 1500    | MHz   |
| Fvco_min |  750    |  750    |  750    | MHz   |
| Fout_max |  891    |  775    |  667    | MHz   |
| Fout_min |    5.86 |    5.86 |    5.86 | MHz   |

Attribute/Parameters
  Given parameters in the table are the most important one For
  calculation of the MMCM values. All the other parameters can be
  found in the Ultrascale - Ultrascale-Plus Clocking Guide (UG572).
| Attribute              | Allowed Values      | Default |
| ---------------------- | ------------------- | ------- |
| CLKOUT[0:1]_DIVIDE     | 1 to 128            | 1       |
| CLKOUT[0:1]_PHASE      | -360.000 to 360.000 | 0.0     |
| CLKOUT[0:1]_DUTY_CYCLE | 0.01 to 0.99        | 0.50    |
| CLKFBOUT_MULT          | 2 to 21             | 5       |
| CLKFBOUT_PHASE         | -360.000 to 360.000 | 0.000   |
| DIVCLK_DIVIDE          | 1 to 15             | 1       |
