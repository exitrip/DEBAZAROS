# OpenEMS FDTD Analysis Automation Script
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

## switches & options
draw_3d_pattern = 0  # this may take a while...
use_pml = 0          # use pml boundaries instead of mur

currDir = os.getcwd()
print(currDir)

# setup_only : dry run to view geometry, validate settings, no FDTD computations
# debug_pec  : generated PEC skeleton (use ParaView to inspect)
debug_pec = False
setup_only = False

## prepare simulation folder
Sim_Path = os.path.join(currDir, 'simulation_output')
Sim_CSX = '3xHDMI-openEMS-TopyIn1-simple.xml'
if os.path.exists(Sim_Path):
	shutil.rmtree(Sim_Path)   # clear previous directory
	os.mkdir(Sim_Path)    # create empty simulation folder

## setup FDTD parameter & excitation function
max_timesteps = 20000
min_decrement = 0.01 # 10*log10(min_decrement) dB  (i.e. 1E-5 means -50 dB)
CSX = CSXCAD.ContinuousStructure()
FDTD = openEMS(NrTS=max_timesteps, EndCriteria=min_decrement)
FDTD.SetCSX(CSX)

#######################################################################################################################################
# BOUNDARY CONDITIONS
#######################################################################################################################################
BC = ["PML_8","PML_8","PML_8","PML_8","PML_8","PML_8"]
FDTD.SetBoundaryCond(BC)

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
FDTD.SetSinusExcite(f0)

#######################################################################################################################################
# MATERIALS AND GEOMETRY
#######################################################################################################################################
materialList = {}

## MATERIAL - PEC
materialList['PEC'] = CSX.AddMetal('PEC')

materialList['PEC'].AddPolyhedronReader(os.path.join(currDir,'copper_gen_model.stl'), priority=9800).ReadFile()

## MATERIAL - air
materialList['air'] = CSX.AddMaterial('air')

materialList['air'].SetMaterialProperty(epsilon=1, mue=1)
materialList['air'].AddPolyhedronReader(os.path.join(currDir,'air_gen_model.stl'), priority=9600).ReadFile()

## MATERIAL - fr4
materialList['fr4'] = CSX.AddMaterial('fr4')

materialList['fr4'].SetMaterialProperty(epsilon=4.2, mue=1)
materialList['fr4'].AddPolyhedronReader(os.path.join(currDir,'fr4_gen_model.stl'), priority=9700).ReadFile()


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
# PROBES
#######################################################################################################################################
nf2ffBoxList = {}
dumpBoxList = {}
probeList = {}

# PROBE - ef - efield
dumpboxName = "ef_efield"
dumpboxType = 0
dumpBoxList[dumpboxName] = CSX.AddDump(dumpboxName, dump_type=dumpboxType)
dumpboxStart = [ 146, -113, 1.5 ]
dumpboxStop  = [ 256, -73, 1.55 ]
dumpBoxList[dumpboxName].AddBox(dumpboxStart, dumpboxStop )


# PROBE - hf - hfield
dumpboxName = "hf_hfield"
dumpboxType = 1
dumpBoxList[dumpboxName] = CSX.AddDump(dumpboxName, dump_type=dumpboxType)
dumpboxStart = [ 146, -113, 1.4 ]
dumpboxStop  = [ 256, -73, 1.45 ]
dumpBoxList[dumpboxName].AddBox(dumpboxStart, dumpboxStop )


#######################################################################################################################################
# RUN
#######################################################################################################################################
### Run the simulation
CSX_file = os.path.join(Sim_Path, Sim_CSX)
if not os.path.exists(Sim_Path):
	os.mkdir(Sim_Path)
CSX.Write2XML(CSX_file)
from CSXCAD import AppCSXCAD_BIN
os.system(AppCSXCAD_BIN + ' "{}"'.format(CSX_file))

FDTD.Run(Sim_Path, verbose=3, cleanup=True, setup_only=setup_only, debug_pec=debug_pec)
