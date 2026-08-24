# Plot S11, S21 parameters from OpenEMS results.
#
# To be run with python.
# FreeCAD to OpenEMS plugin by Lubomir Jagos, 
# see https://github.com/LubomirJagos/FreeCAD-OpenEMS-Export
#
# This file has been automatically generated. Manual changes may be overwritten.
#
### Import Libraries
import math
import numpy as np
import os, tempfile, shutil
from pylab import *
import csv
import CSXCAD
from openEMS import openEMS
from openEMS.physical_constants import *

#
# FUNCTION TO CONVERT CARTESIAN TO CYLINDRICAL COORDINATES
#     returns coordinates in order [theta, r, z]
#
def cart2pol(pointCoords):
	theta = np.arctan2(pointCoords[1], pointCoords[0])
	r = np.sqrt(pointCoords[0] ** 2 + pointCoords[1] ** 2)
	z = pointCoords[2]
	return theta, r, z

#
# FUNCTION TO GIVE RANGE WITH ENDPOINT INCLUDED arangeWithEndpoint(0,10,2.5) = [0, 2.5, 5, 7.5, 10]
#     returns coordinates in order [theta, r, z]
#
def arangeWithEndpoint(start, stop, step=1, endpoint=True):
	if start == stop:
		return [start]

	arr = np.arange(start, stop, step)
	if endpoint and arr[-1] + step == stop:
		arr = np.concatenate([arr, [stop]])
	return arr

# Change current path to script file folder
#
abspath = os.path.abspath(__file__)
dname = os.path.dirname(abspath)
os.chdir(dname)
## constants
unit    = 0.001 # Model coordinates and lengths will be specified in mm.
fc_unit = 0.001 # STL files are exported in FreeCAD standard units (mm).

currDir = os.getcwd()
Sim_Path = os.path.join(currDir, r'simulation_output')
print(currDir)

## setup FDTD parameter & excitation function
max_timesteps = 20000
min_decrement = 0.01 # 10*log10(min_decrement) dB  (i.e. 1E-5 means -50 dB)
CSX = CSXCAD.ContinuousStructure()
FDTD = openEMS(NrTS=max_timesteps, EndCriteria=min_decrement)
FDTD.SetCSX(CSX)

#######################################################################################################################################
# COORDINATE SYSTEM
#######################################################################################################################################
def mesh():
	x,y,z

mesh.x = np.array([]) # mesh variable initialization (Note: x y z implies type Cartesian).
mesh.y = np.array([])
mesh.z = np.array([])

openEMS_grid = CSX.GetGrid()
openEMS_grid.SetDeltaUnit(unit) # First call with empty mesh to set deltaUnit attribute.

#######################################################################################################################################
# EXCITATION sinpos_fund sinusodial
# /home/aescape/openEMS-Project/FreeCAD-OpenEMS-Export/utilsOpenEMS/ScriptLinesGenerator/PythonScriptLinesGenerator2.py
#######################################################################################################################################
f0 = 72.0*1000000.0
max_res = C0 / f0 / 20

#######################################################################################################################################
# MATERIALS AND GEOMETRY
#######################################################################################################################################
materialList = {}

#######################################################################################################################################
# GRID LINES
#######################################################################################################################################

## GRID - xyz - air (Fixed Distance)
mesh.x = np.delete(mesh.x, np.argwhere((mesh.x >= 146) & (mesh.x <= 256)))
mesh.x = np.concatenate((mesh.x, arangeWithEndpoint(146,256,0.05)))
mesh.y = np.delete(mesh.y, np.argwhere((mesh.y >= -113) & (mesh.y <= -73)))
mesh.y = np.concatenate((mesh.y, arangeWithEndpoint(-113,-73,0.05)))
mesh.z = np.delete(mesh.z, np.argwhere((mesh.z >= -5) & (mesh.z <= 5)))
mesh.z = np.concatenate((mesh.z, arangeWithEndpoint(-5,5,0.05)))

openEMS_grid.AddLine('x', mesh.x)
openEMS_grid.AddLine('y', mesh.y)
openEMS_grid.AddLine('z', mesh.z)

#######################################################################################################################################
# PORTS
#######################################################################################################################################
port = {}
portNamesAndNumbersList = {}
## PORT - portPin - portPin
portStart = [ 182.8, -78.1, 1.6 ]
portStop  = [ 185.3, -77.6, 1.6315 ]
portR = 50
portUnits = 1
portExcitationAmplitude = 2200.0
portDirection = 'x'
port[1] = FDTD.AddLumpedPort(port_nr=1, R=portR*portUnits, start=portStart, stop=portStop, p_dir=portDirection, priority=9900, excite=1.0*portExcitationAmplitude)
portNamesAndNumbersList["portPin"] = 1;

## PORT - portPout - portPout
portStart = [ 196.9, -99.9, 1.6 ]
portStop  = [ 198.1, -99.4, 1.6315 ]
portR = 50
portUnits = 1
portExcitationAmplitude = 0.0
portDirection = 'x'
port[2] = FDTD.AddLumpedPort(port_nr=2, R=portR*portUnits, start=portStart, stop=portStop, p_dir=portDirection, priority=10000, excite=0)
portNamesAndNumbersList["portPout"] = 2;

#######################################################################################################################################
# POST-PROCESSING AND PLOT GENERATION
#######################################################################################################################################

freq = np.linspace(max(1e6, f0 - fc), f0 + fc, 501)
port[1].CalcPort(Sim_Path, freq)
port[2].CalcPort(Sim_Path, freq)

s11 = port[1].uf_ref / port[1].uf_inc
s21 = port[2].uf_ref / port[1].uf_inc

s11_dB = 20*log10(abs(s11))
s21_dB = 20*log10(abs(s21))

plot(freq/1e9,s11_dB,'k-', linewidth=2)
grid()
plot(freq/1e9,s21_dB,'r--', linewidth=2)
legend(('$S_{11}$','$S_{21}$'))
title('S21-Parameter\nportPin - portPin $\\rightarrow$ portPout - portPout', fontsize=12)
ylabel('S21(dB)', fontsize=12)
xlabel('frequency (GHz)', fontsize=12)
ylim([-40, 2])
show()

#######################################################################################################################################
# SAVE PLOT DATA
#######################################################################################################################################

#
#   Write S11, real and imag Z_in into CSV file separated by ';'
#
filename = 'openEMS_simulation_s11_dB.csv'

with open(filename, 'w', newline='') as csvfile:
	writer = csv.writer(csvfile, delimiter=';', quotechar='|', quoting=csv.QUOTE_MINIMAL)
	writer.writerow(['freq (Hz)', 's11 (dB)', 's21 (dB)'])
	writer.writerows(np.array([freq, s11_dB, s21_dB]).T)  # creates array with 1st row frequencies, 2nd row S11 and transpose it

