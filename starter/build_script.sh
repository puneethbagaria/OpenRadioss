#!/bin/bash

function my_help()
{
  echo " " 
  echo " build_script"
  echo " ------------"
  echo " " 
  echo " Use with arguments : "
  echo " -arch=[build architecture]"
  if  [ -f CMake_Compilers/platforms.txt ]
  then
       cat CMake_Compilers/platforms.txt 
  fi
  if  [ -f CMake_Compilers_c/platforms.txt ]
  then
       cat CMake_Compilers_c/platforms.txt 
  fi
  echo " -prec=[dp|sp]                        : set precision - dp (default) |sp "
  echo " -static-link                         : Fortran, C & C++ runtime are linked in binary"
  echo " -debug=[0|1]                         : debug version 0 no debug flags (default), 1 usual debug flag )"
  echo " -addflag=\"list of additional flags\" : add compiler flags to usual set"
  echo " " 
  echo " Execution control "
  echo " -nt=[threads]      : number of threads for build "
  echo " -verbose           : Verbose build"
  echo " -clean             : clean build directory"
  echo " " 
  echo " " 
}

# Variable initialization
# -----------------------
OTHER_MAKE_ARGS=" " 
# -----------------------------
# Parse command line arguments
# -----------------------------
arch=none
prec=dp
threads=1
got_arch=0
debug=0
jenkins_release=0
no_rr_clean=0
changelist=00000
cf=""
dc=""
qd=""
ADF=""
debug=0
sanitize=0
ddebug=""
static_link=0
number_of_arguments=$#
clean=0
verbose=""
st_vers="starter"
com=0

if [ $number_of_arguments = 0 ]
then
  my_help
  exit 1
 
else

   for var in "$@"
   do
       arg=`echo $var|awk -F '=' '{print $1}'`

       if [ "$arg" == "-arch" ]
       then
         arch=`echo $var|awk -F '=' '{print $2}'`
         got_arch=1
       fi

       if [ "$arg" == "-prec" ]
       then
         prec=`echo $var|awk -F '=' '{print $2}'`
         if [ ${prec} = 'sp' ]
         then
           suffix=_sp
         fi
       fi

       if [ "$arg" == "-addflag" ]
       then
         ad=`echo $var|awk -F '-addflag=' '{ print $2}'`
         export ADFL=${ad}
       fi

       if [ "$arg" == "-debug" ]
       then
         debug=`echo $var|awk -F '=' '{print $2}'`
         if [ $debug == 2 ]
         then
           debug=1
           sanitize=1
         fi 
         if [ $debug == 1 ]
         then
           ddebug="_db"
         fi
       fi

       if [ "$arg" == "-nt" ]
       then
         threads=`echo $var|awk -F '=' '{print $2}'`
       fi

       if [ "$arg" == "-static-link" ]
       then
         static_link=1
       fi

       if [ "$arg" == "-c" ]
       then
         com=1
         dc="-DCOM=1"
         cf="_c"
         vers=`cat CMake_Compilers_c/cmake_st_version.txt | awk -F '\"' '{print $2}' `
         st_vers="s_${vers}"
       fi

       if [ "$arg" == "-verbose" ]
       then
         verbose="VERBOSE=1"
       fi

       if [ "$arg" == "-clean" ]
       then
         clean=1
       fi

   done

   if [ $got_arch == 0 ] 
   then
     echo " " 
     echo " --- Error "
     echo " No architecture flag set ! "
     echo " " 
     my_help
     exit 1
   fi


   echo " " 
   echo " Build OpenRadioss Starter "
   echo " --------------------------"
   echo " Build Arguments :"
   echo " arch =                 : " $arch
   echo " precision =            : " $prec
   echo " debug =                : " $debug
   echo " static_link =          : " $static_link
   if [[ -v ad ]]  
   then
      echo " Addflag                : \""$ad "\" "
   fi
   echo " "
   echo " #threads for Makefile : " $threads
   echo " "
fi




build_directory=cbuild_${arch}${suffix}${cf}${ddebug}

if [ $clean = 1 ]
then
   if [ -d ${build_directory} ]
   then
     echo "Clean ${build_directory} directory"
     rm -rf ./${build_directory}
   else
     echo "Clean ${build_directory} directory requested but not found"
   fi
   echo " " 
   exit 0
fi


# create build directory
if [ ! -d ../exec ] 
then
   mkdir ../exec
fi

# create build directory
if [ ! -d ${build_directory} ] 
then
   mkdir ${build_directory}
fi

starter_exec=${st_vers}_${arch}${dmpi}${suffix}${ddebug}
echo " " 

if [ -f ${build_directory}/${starter_exec} ]
then
  echo " -- Remove executable in build_script "
  rm ${build_directory}/${starter_exec}
fi

if [ -f ../exec/${starter_exec} ]
then
  echo " -- Remove executable in exec "
 
  rm ../exec/${starter_exec}
fi
echo " "


cd ${build_directory}

# Get compiler settings
if [ $com = 1 ]
then
    source ../CMake_Compilers_c/cmake_${arch}_compilers.sh
else
    source ../CMake_Compilers/cmake_${arch}_compilers.sh
fi
  
Fortran_path=`which $Fortran_comp`
C_path=`which $C_comp`
CPP_path=`which $CPP_comp`
CXX_path=`which $CXX_comp`


# Apply cmake
if [ ${arch} = "win64" ]
then
  Fortran_path_w=`cygpath.exe -m "${Fortran_path}"`
  C_path_w=`cygpath.exe -m "${C_path}"`
  CPP_path_w=`cygpath.exe -m "${CPP_path}"`
  CXX_path_w=`cygpath.exe -m "${CXX_path}"`
  cmake.exe -G "Unix Makefiles" -Darch=${arch} -Dprecision=${prec} ${DAD} -Ddebug=${debug} ${dc}  -Dstatic_link=$static_link -DCMAKE_BUILD_TYPE=Release -DCMAKE_Fortran_COMPILER="${Fortran_path_w}" -DCMAKE_C_COMPILER="${C_path_w}" -DCMAKE_CPP_COMPILER="${CPP_path_w}" -DCMAKE_CXX_COMPILER="${CXX_path_w}" .. 
else
  cmake -Darch=${arch} -Dprecision=${prec} ${DAD} -Ddebug=${debug}  -Dstatic_link=$static_link ${dc} -Dsanitize=${sanitize}  -DCMAKE_Fortran_COMPILER=${Fortran_path} -DCMAKE_C_COMPILER=${C_path} -DCMAKE_CPP_COMPILER=${CPP_path} -DCMAKE_CXX_COMPILER=${CXX_path} .. 
fi


make -j ${threads}  ${verbose}


echo " "
if [ -f ${starter_exec} ]
then
  echo " -- Copy ${starter_exec} in ../exec "
  cp  ${starter_exec} ../../exec
fi

cd ..
echo " "


