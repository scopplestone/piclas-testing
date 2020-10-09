import json
import os
import collections
import shutil
import sys
from timeit import default_timer as timer
import subprocess
import select

# Bind raw_input to input in Python 2
try:
    input = raw_input
except NameError:
    pass

print(132*'=')
print("createCylinderHOPR.py, add nice ASCII art here")
print(132*'=')

cwd               = os.getcwd()
config_filename   = os.path.join(cwd, '.createCylinderHOPR.json')
config_debug_info = False # Debugging variable
if os.path.exists(config_filename) :
    config_exists=True
else :
    config_exists=False


class myColors :
    """ Add different colors and styles (ANSI code) to strings """
    # After coloring, change back to \033
    endc   = '\033[0m'

    # Regular Colors
    black  = '\033[0;30m'
    red    = '\033[0;31m'
    green  = '\033[0;32m'
    yellow = '\033[0;33m'
    blue   = '\033[0;34m'
    purple = '\033[0;35m'
    cyan   = '\033[0;36m'
    white  = '\033[0;37m'

    # Text Style
    bold = '\033[1m'
    underlinE = '\033[4m'

def bold(text) :
    return myColors.bold+text+myColors.endc

def red(text) :
    return myColors.red+text+myColors.endc

def green(text) :
    return myColors.green+text+myColors.endc

def blue(text) :
    return myColors.blue+text+myColors.endc

def yellow(text) :
    return myColors.yellow+text+myColors.endc


class ExternalCommand() :
    def __init__(self) :
        self.stdout = []
        self.stderr = []
        self.stdout_filename = None
        self.stderr_filename = None
        self.return_code = 0
        self.result = ""
        self.walltime = 0

    def execute_cmd(self, cmd, target_directory, name="std", string_info = None, environment = None):
        """Execute an external program specified by 'cmd'. The working directory of this program is set to target_directory.
        Returns the return_code of the external program.

        cmd                    : command given as list of strings (the command is split at every white space occurrence)
        target_directory       : path to directory where the cmd command is to be executed
        name (optional)        : [name].std and [name].err files are created for storing the std and err output of the job
        string_info (optional) : Print info regarding the command that is executed before execution
        environment (optional) : run cmd command with environment variables as given by environment=os.environ (and possibly modified)
        """
        # Display string_info
        if string_info is not None:
            print(string_info)

        # check that only cmd arguments of type 'list' are supplied to this function
        if type(cmd) != type([]) :
            print(("cmd must be of type 'list'\ncmd=")+str(cmd)+(" and type(cmd)="),type(cmd))
            exit(1)

        sys.stdout.flush() # flush output here, because the subprocess will force buffering until it is finished
        #log = logging.getLogger('logger')

        workingDir = os.path.abspath(target_directory)
        #log.debug(workingDir)
        #log.debug(cmd)
        start = timer()
        (pipeOut_r, pipeOut_w) = os.pipe()
        (pipeErr_r, pipeErr_w) = os.pipe()
        if environment is None :
            self.process = subprocess.Popen(cmd, stdout=pipeOut_w, \
                                            stderr=pipeErr_w, \
                                            universal_newlines=True, cwd=workingDir)
        else :
            self.process = subprocess.Popen(cmd, stdout=pipeOut_w, \
                                            stderr=pipeErr_w, \
                                            universal_newlines=True, cwd=workingDir, \
                                            env = environment)

        self.stdout = []
        self.stderr = []

        bufOut = ""
        bufErr = ""
        while self.process.poll() is None:
            # Loop long as the selct mechanism indicates there
            # is data to be read from the buffer

            # 1.   std.out
            while len(select.select([pipeOut_r], [], [], 0)[0]) == 1:
                # Read up to a 1 KB chunk of data
                out_s = os.read(pipeOut_r, 1024)
                if not isinstance(out_s, str):
                    out_s = out_s.decode("utf-8")
                bufOut = bufOut + out_s
                tmp = bufOut.split('\n')
                for line in tmp[:-1] :
                    self.stdout.append(line+'\n')
                    print(line)
                bufOut = tmp[-1]

            # 1.   err.out
            while len(select.select([pipeErr_r], [], [], 0)[0]) == 1:
                # Read up to a 1 KB chunk of data
                out_s = os.read(pipeErr_r, 1024)
                if not isinstance(out_s, str):
                    out_s = out_s.decode("utf-8")
                bufErr = bufErr + out_s
                tmp = bufErr.split('\n')
                for line in tmp[:-1] :
                    self.stderr.append(line+'\n')
                    print(line)
                bufErr = tmp[-1]

        os.close(pipeOut_w)
        os.close(pipeOut_r)
        os.close(pipeErr_w)
        os.close(pipeErr_r)


        self.return_code = self.process.returncode

        end = timer()
        self.walltime = end - start

        # write std.out and err.out to disk
        self.stdout_filename = os.path.join(target_directory,name+".out")
        with open(self.stdout_filename, 'w') as f :
            for line in self.stdout :
                f.write(line)
        if self.return_code != 0 :
            self.result=red("Failed")
            self.stderr_filename = os.path.join(target_directory,name+".err")
            with open(self.stderr_filename, 'w') as f :
                for line in self.stderr :
                    f.write(line)
        else :
            self.result=blue("Successful")

        # Display result (Successful or Failed)
        if string_info is not None:
            # display result and wall time in previous line and shift the text by ncols columns to the right
            # Note that f-strings in print statements, e.g. print(f"...."), only work in python 3
            # print(f"\033[F\033[{ncols}G "+str(self.result)+" [%.2f sec]" % self.walltime)
            ncols = len(string_info)+1
            print("\033[F\033[%sG " % ncols +str(self.result)+" [%.2f sec]" % self.walltime)
        else :
            print(self.result+" [%.2f sec]" % self.walltime)

        return self.return_code


def AddBool(Config, Key, Bool) :
    # Store X Mode
    if Bool :
        Config[Key] = True
    else :
        Config[Key] = False


class SetupConfiguration():
    def __init__(self):
        self.config = collections.OrderedDict()
        self.ReadConfig()

    def ReadConfig(self):
        ''' Read configuration from "config_filename" file '''
        self.successful=False
        try :
            with open(config_filename, 'r') as json_data_file:
                json_config = json.load(json_data_file)
                self.config = collections.OrderedDict(sorted(json_config.items()))
                self.successful=True
        except :
            pass

        # --- ONLY FOR DEBUGGING ---
        if config_debug_info and self.successful :
            print()
            print("DEBUG:  Reading form %s" % config_filename,)
            for key, value in self.config.items() :
                print("DEBUG:  "+key+" = "+str(value))
            print()
        # --- ONLY FOR DEBUGGING ---

    def SaveConfig(self):
        ''' Save configuration to "config_filename" file '''

        # Remove the config file before writing a new one
        if os.path.exists(config_filename) :
            shutil.rmtree(config_filename,ignore_errors=True)

        with open(config_filename, 'w') as outfile:
            outfile.write(json.dumps(self.config, indent=4))

        # Delete self.config and load from file (json)
        del self.config
        with open(config_filename, 'r') as json_data_file:
            self.config = json.load(json_data_file)

        # --- ONLY FOR DEBUGGING ---
        # Sanity check: read the config file out print the content
        if config_debug_info :
            with open(config_filename, 'r') as json_data_file:
                config = json.load(json_data_file)

            print()
            print("DEBUG:  Saving to %s" % config_filename,)
            for key, value in config.items() :
                print("DEBUG:  "+key+" = "+str(value))
            print()
        # --- ONLY FOR DEBUGGING ---


def convert(mode,x):
    """convert the string 'x' to str, float or int"""
    if mode == "float":
        y = float(x)
    if mode == "int":
        y = int(x)
    if mode == "str":
        if x is not '':
            y = str(x)
    return y

def getInput(Configuration,question,variable,error,typeOfInput,sanityCheck=None):
    """Get input from user"""

    done = False
    while done == False:
        # Get user input
        if Configuration.config.get(variable, None) is None:# or Configuration.config.get(variable, None) == '':
            userInput = input(question)

            if userInput == '' and variable is not "hopr":
                print(red(error))
                continue
        else:
            userInput = input(question+green("Auto-select [%s]: " % str(Configuration.config[variable])))

        # Try to convert the new input or changed variable
        if userInput is not '':
            try:
                Configuration.config[variable] = convert(typeOfInput,userInput)
            except Exception as e:
                print(red(error))
                continue

        if Configuration.config[variable] == '' and variable is not "hopr":
            print(red(error))
            continue

        # Sanity check
        if sanityCheck is not None:
            if sanityCheck == 1:
                if Configuration.config["r1"] >= Configuration.config["r2"] :
                    print("r1 cannot be larger than r2! r1=%s, r2=%s" % (Configuration.config["r1"],Configuration.config["r2"]))
                    continue
            if sanityCheck == 2:
                # Sanity check mesh number
                if Configuration.config["mode"] not in (1,2,3):
                    print(red("Error: choose mesh 1, 2 or 3!"))
                    continue

        done = True
    return Configuration


# Get config from file if it exists
Configuration = SetupConfiguration() # Create class object: init calls ReadConfig()
Executable = ExternalCommand()

print()

getInput(Configuration , "Please enter the path to the HOPR executable: "                                                                 , "hopr" , "Please supply the path to the HOPR executable" , "str")
getInput(Configuration , "Please enter the radius of the cylinder: "                                                                      , "r1"   , "Please supply a value for the radius"          , "float")
getInput(Configuration , "Please enter the radius of the simulation domain: "                                                             , "r2"   , "Please supply a value for the radius"          , "float"  , sanityCheck=1)
getInput(Configuration , "Please enter the type of cylinder you want \n  1: quarter cylinder \n  2: half cylinder \n  3: full cylinder: " , "mode" , "Please supply a number for the desired mesh"   , "int"    , sanityCheck=2)

r01 = 3.5
s0  = Configuration.config["r1"] / r01
r02 = Configuration.config["r2"] / s0

if Configuration.config["mode"] == 1:
    # 90 degree
    NbrOfZones = 2
    symmetryBC = 6
    symmetryBC2 = 7
    mesh="quarter cylinder (90 degree)"
elif Configuration.config["mode"] == 2:
    # 180 degree
    NbrOfZones = 4
    symmetryBC = 6
    symmetryBC2 = 0
    mesh="half cylinder (180 degree)"
elif Configuration.config["mode"] == 3:
    # 360 degree
    NbrOfZones = 8
    symmetryBC = 0
    symmetryBC2 = 0
    mesh="full cylinder (360 degree)"
else:
    print(red("\nError: choose mesh 1, 2 or 3! mode=%s" % Configuration.config["mode"]))
    exit(1)


#Configuration.config["hopr"] = input("Please enter the path to the HOPR executable: ")
#AddBool(Configuration.config , 'Debug Mode' , True)

# Save to file
Configuration.SaveConfig()



# ==================================================================================
filename = "hopr.ini"
#print("Creating %s" % filename)
f = open("%s" % filename, 'w')

f.write(r"""
DEFVAR=(INT):    i01 = 6   ! no. elems in left and right block
DEFVAR=(INT):    i02 = 6   ! no. elems in upper block (should be twice the value of i01)

DEFVAR=(INT):    ir1 = 5   ! no. elems in r for first ring
""")

f.write(r'DEFVAR=(REAL):   r01 = %s ! middle square dim' % r01 + '\n')
f.write(r'DEFVAR=(REAL):   r02 = %s ! middle square dim' % r02 + '\n')
f.write(r'DEFVAR=(REAL):   s0  = %s ! middle square dim' % s0 + '\n')

f.write(r"""

DEFVAR=(INT):    iz = 1    !

DEFVAR=(REAL):   lz = 1.0    ! length of domain in z
DEFVAR=(REAL):   f1 = 1.    ! stretching factor in first ring

!================================================================================================================================= !
! OUTPUT
!================================================================================================================================= !
ProjectName        = Cylinder3_Ngeo3
Debugvisu          = T                          ! Visualize mesh and boundary conditions (tecplot ascii)
checkElemJacobians = T

!================================================================================================================================= !
! MESH
!================================================================================================================================= !
Mode   = 1                           ! Mode for Cartesian boxes
""")
f.write(r'nZones = %s                           ! number of boxes' % NbrOfZones + '\n')
f.write(r"""!            =(/z- , y- , x+ , y+ , x- , z+/)  ! Indices of Boundary Conditions

! ---------------------------------------------------------------
! Upper cylinder half
! ---------------------------------------------------------------
""")



# left part (180 and 360 degree only)
if NbrOfZones > 2:
    f.write(r"""
!left-lower (x-)
Corner       =(/-r01 , 0.  , 0.   ,,   -r02 , 0.  , 0.   ,,   -r02 , r02 , 0.   ,,   -r01 , r01 , 0.   ,,   -r01 , 0.  , lz   ,,   -r02 , 0.  , lz   ,,   -r02 , r02 , lz   ,,   -r01 , r01 , lz /)
nElems       =(/ir1,i01,iz/)                   ! number of elements in each direction
""")
if NbrOfZones > 2:
    f.write(r'BCIndex      =(/1  , %s  , 4  , 0  , 3  , 2/)   ! Indices of Boundary Conditions for  six Boundary Faces (z- , y- , x+ , y+ , x- , z+)' % symmetryBC + '\n')
    f.write(r"""!            =(/z- , y- , x+ , y+ , x- , z+/)  ! Indices of Boundary Conditions
elemtype     =108                              ! element type (108: Hexahedral)
factor       =(/f1,1.,1./)                     ! stretching

!left-upper (y+)
Corner       =(/0.  , r01 , 0.   ,,   -r01 , r01 , 0.   ,,   -r02 , r02 , 0.   ,,   0.  , r02 , 0.   ,,   0.  , r01 , lz   ,,   -r01 , r01 , lz   ,,   -r02 , r02 , lz   ,,   0.  , r02 , lz /)
nElems       =(/i02,ir1,iz/)                   ! number of elements in each direction
""")
if NbrOfZones > 2:
    f.write(r'BCIndex      =(/1  , 3  , 0  , 4  , %s  , 2/)   ! Indices of Boundary Conditions for  six Boundary Faces (z- , y- , x+ , y+ , x- , z+)' % symmetryBC2 + '\n')
    f.write(r"""!            =(/z- , y- , x+ , y+ , x- , z+/)  ! Indices of Boundary Conditions
elemtype     =108                              ! element type (108: Hexahedral)
factor       =(/1.,f1,1./)                     ! stretching
""")




# right part (90 degree)
f.write(r"""
!right-lower (x+)
Corner       =(/r01 , 0.  , 0.   ,,   r02 , 0.  , 0.   ,,   r02 , r02 , 0.   ,,   r01 , r01 , 0.   ,,   r01 , 0.  , lz   ,,   r02 , 0.  , lz   ,,   r02 , r02 , lz   ,,   r01 , r01 , lz /)
nElems       =(/ir1,i01,iz/)                   ! number of elements in each direction
""")
f.write(r'BCIndex      =(/1  , %s  , 5  , 0  , 3  , 2/)   ! Indices of Boundary Conditions for  six Boundary Faces (z- , y- , x+ , y+ , x- , z+)' % symmetryBC + '\n')
f.write(r"""
!            =(/z- , y- , x+ , y+ , x- , z+/)  ! Indices of Boundary Conditions
elemtype     =108                              ! element type (108: Hexahedral)
factor       =(/f1,1.,1./)                     ! stretching

!right-upper (y+)
Corner       =(/0.  , r01 , 0.   ,,   r01 , r01 , 0.   ,,   r02 , r02 , 0.   ,,   0.  , r02 , 0.   ,,   0.  , r01 , lz   ,,   r01 , r01 , lz   ,,   r02 , r02 , lz   ,,   0.  , r02 , lz /)
nElems       =(/i02,ir1,iz/)                   ! number of elements in each direction
""")
f.write(r'BCIndex      =(/1  , 3  , 0  , 5  , %s  , 2/)   ! Indices of Boundary Conditions for  six Boundary Faces (z- , y- , x+ , y+ , x- , z+)' % symmetryBC2 + '\n')
f.write(r"""!            =(/z- , y- , x+ , y+ , x- , z+/)  ! Indices of Boundary Conditions
elemtype     =108                              ! element type (108: Hexahedral)
factor       =(/1.,f1,1./)                     ! stretching





""")


# bottom right and left part (360 degree only)
# Bottom part of the full cylinder
if NbrOfZones > 4:
    f.write(r"""
! ---------------------------------------------------------------
! Bottom cylinder half
! ---------------------------------------------------------------
!left-lower (x-)
Corner       =(/-r01 , 0.  , 0.   ,,   -r02 , 0.  , 0.   ,,   -r02 , -r02 , 0.   ,,   -r01 , -r01 , 0.   ,,   -r01 , 0.  , lz   ,,   -r02 , 0.  , lz   ,,   -r02 , -r02 , lz   ,,   -r01 , -r01 , lz /)
nElems       =(/ir1,i01,iz/)                   ! number of elements in each direction
""")
if NbrOfZones > 4:
    f.write(r'BCIndex      =(/1  , %s  , 4  , 0  , 3  , 2/)   ! Indices of Boundary Conditions for  six Boundary Faces (z- , y- , x+ , y+ , x- , z+)' % symmetryBC + '\n')
    f.write(r"""
!            =(/z- , y- , x+ , y+ , x- , z+/)  ! Indices of Boundary Conditions
elemtype     =108                              ! element type (108: Hexahedral)
factor       =(/f1,1.,1./)                     ! stretching

!left-upper (y+)
Corner       =(/0.  , -r01 , 0.   ,,   -r01 , -r01 , 0.   ,,   -r02 , -r02 , 0.   ,,   0.  , -r02 , 0.   ,,   0.  , -r01 , lz   ,,   -r01 , -r01 , lz   ,,   -r02 , -r02 , lz   ,,   0.  , -r02 , lz /)
nElems       =(/i02,ir1,iz/)                   ! number of elements in each direction
BCIndex      =(/1  , 3  , 0  , 4  , 0  , 2/)   ! Indices of Boundary Conditions for  six Boundary Faces (z- , y- , x+ , y+ , x- , z+)
!            =(/z- , y- , x+ , y+ , x- , z+/)  ! Indices of Boundary Conditions
elemtype     =108                              ! element type (108: Hexahedral)
factor       =(/1.,f1,1./)                     ! stretching



!right-lower (x+)
Corner       =(/r01 , 0.  , 0.   ,,   r02 , 0.  , 0.   ,,   r02 , -r02 , 0.   ,,   r01 , -r01 , 0.   ,,   r01 , 0.  , lz   ,,   r02 , 0.  , lz   ,,   r02 , -r02 , lz   ,,   r01 , -r01 , lz /)
nElems       =(/ir1,i01,iz/)                   ! number of elements in each direction
""")
if NbrOfZones > 4:
    f.write(r'BCIndex      =(/1  , %s  , 5  , 0  , 3  , 2/)   ! Indices of Boundary Conditions for  six Boundary Faces (z- , y- , x+ , y+ , x- , z+)' % symmetryBC + '\n')
    f.write(r"""
!            =(/z- , y- , x+ , y+ , x- , z+/)  ! Indices of Boundary Conditions
elemtype     =108                              ! element type (108: Hexahedral)
factor       =(/f1,1.,1./)                     ! stretching

!right-upper (y+)
Corner       =(/0.  , -r01 , 0.   ,,   r01 , -r01 , 0.   ,,   r02 , -r02 , 0.   ,,   0.  , -r02 , 0.   ,,   0.  , -r01 , lz   ,,   r01 , -r01 , lz   ,,   r02 , -r02 , lz   ,,   0.  , -r02 , lz /)
nElems       =(/i02,ir1,iz/)                   ! number of elements in each direction
BCIndex      =(/1  , 3  , 0  , 5  , 0  , 2/)   ! Indices of Boundary Conditions
!            =(/z- , y- , x+ , y+ , x- , z+/)  ! Indices of Boundary Conditions
elemtype     =108                              ! element type (108: Hexahedral)
factor       =(/1.,f1,1./)                     ! stretching




""")






f.write(r"""
useCurveds    = F
BoundaryOrder = 3  ! = NGeo+1

!================================================================================================================================= !
! BOUNDARY CONDITIONS
!================================================================================================================================= !
! periodic
!   BoundaryName=BC_back    ! BC index X (from  position in parameterfile)
!   BoundaryType=(/1,0,0,1/)  ! (/ Type, curveIndex, State, alpha /)
!
!   BoundaryName=BC_front     ! BC index X
!   BoundaryType=(/1,0,0,-1/)
!   vv=(/0.,0.,lz/)

! non-periodic
BoundaryName=BC_back    ! BC index X (from  position in parameterfile)
BoundaryType=(/3,0,0,0/)  ! (/ Type, curveIndex, State, alpha /)

BoundaryName=BC_front     ! BC index X
BoundaryType=(/3,0,0,0/)  ! (/ Type, curveIndex, State, alpha /)

BoundaryName=BC_cylinder     ! BC index X
BoundaryType=(/3,0,0,0/)

BoundaryName=BC_left    ! BC index X
BoundaryType=(/2,0,0,0/)

BoundaryName=BC_right    ! BC index X
BoundaryType=(/4,0,0,0/)
""")


if NbrOfZones == 4:
    f.write(r"""
BoundaryName=BC_symmetry    ! BC index X
BoundaryType=(/4,0,0,0/)
""")
elif NbrOfZones == 2:
    f.write(r"""
BoundaryName=BC_symmetry1   ! BC index X
BoundaryType=(/4,0,0,0/)

BoundaryName=BC_symmetry2   ! BC index X
BoundaryType=(/4,0,0,0/)
""")



f.write(r"""

!================================================================================================================================= !
! MESH POST DEFORM
!================================================================================================================================= !
MeshPostDeform=1                            ! deforms [-1,1]^2 to a cylinder with radius Postdeform_R0
PostDeform_R0=s0                           ! here domain is [-4,4]^2 mapped to a cylinder with radius 0.25*4 = 1

""")

f.close()

print( )
print("Created the following %s file:" % filename)
print("    cylinder radius: %s" % Configuration.config["r1"])
print("      domain radius: %s" % Configuration.config["r2"])
print("          mesh type: %s" % mesh)
print( )


# Run hopr
if Configuration.config.get("hopr", None) is not None :
    if os.path.exists(Configuration.config["hopr"]):
        input("Hit [enter] to run hopr: ")
        # Execute python and corresponding program
        cmd=[Configuration.config["hopr"], 'hopr.ini']
        #Executable.execute_cmd(MyWindow.case.cmd, target_directory, environment = MyWindow.my_env) != 0 : # use uncolored string for cmake
        Executable.execute_cmd(cmd, cwd)
    else:
        print(red("Error: hopr executable not found under [%s]" % Configuration.config["hopr"]))
        exit(1)



