#
#  This file is part of MUMPS 5.4.1, released
#  on Tue Aug  3 09:49:43 UTC 2021
#
#Begin orderings

# NOTE that PORD is distributed within MUMPS by default. It is recommended to
# install other orderings. For that, you need to obtain the corresponding package
# and modify the variables below accordingly.
# For example, to have Metis available within MUMPS:
#          1/ download Metis and compile it
#          2/ uncomment (suppress # in first column) lines
#             starting with LMETISDIR,  LMETIS
#          3/ add -Dmetis in line ORDERINGSF
#             ORDERINGSF  = -Dpord -Dmetis
#          4/ Compile and install MUMPS
#             make clean; make   (to clean up previous installation)
#
#          Metis/ParMetis and SCOTCH/PT-SCOTCH (ver 6.0 and later) orderings are recommended.
#

#SCOTCHDIR  = ${HOME}/scotch_6.0
#ISCOTCH    = -I$(SCOTCHDIR)/include
#
# You have to choose one among the following two lines depending on
# the type of analysis you want to perform. If you want to perform only
# sequential analysis choose the first (remember to add -Dscotch in the ORDERINGSF
# variable below); for both parallel and sequential analysis choose the second 
# line (remember to add -Dptscotch in the ORDERINGSF variable below)

#LSCOTCH    = -L$(SCOTCHDIR)/lib -lesmumps -lscotch -lscotcherr
#LSCOTCH    = -L$(SCOTCHDIR)/lib -lptesmumps -lptscotch -lptscotcherr


LPORDDIR = $(topdir)/PORD/lib/
IPORD    = -I$(topdir)/PORD/include/
LPORD    = -L$(LPORDDIR) -lpord

LMETISDIR = /project/cwhsu_38/shared/software/metis-5.1.0/build/Linux-x86_64/libmetis
IMETIS    = /project/cwhsu_38/shared/software/metis-5.1.0/include

# You have to choose one among the following two lines depending on
# the type of analysis you want to perform. If you want to perform only
# sequential analysis choose the first (remember to add -Dmetis in the ORDERINGSF
# variable below); for both parallel and sequential analysis choose the second 
# line (remember to add -Dparmetis in the ORDERINGSF variable below)

LMETIS    = -L$(LMETISDIR) -lmetis
#LMETIS    = -L$(LMETISDIR) -lparmetis -lmetis

# The following variables will be used in the compilation process.
# Please note that -Dptscotch and -Dparmetis imply -Dscotch and -Dmetis respectively.
# If you want to use Metis 4.X or an older version, you should use -Dmetis4 instead of -Dmetis
# or in addition with -Dparmetis (if you are using parmetis 3.X or older).
#ORDERINGSF = -Dscotch -Dmetis -Dpord -Dptscotch -Dparmetis
ORDERINGSF  = -Dpord -Dmetis
ORDERINGSC  = $(ORDERINGSF)

LORDERINGS = $(LMETIS) $(LPORD) $(LSCOTCH)
IORDERINGSF = $(ISCOTCH)
IORDERINGSC = $(IMETIS) $(IPORD) $(ISCOTCH)

#End orderings
########################################################################
################################################################################

PLAT =
LIBEXT  = .a
OUTC    = -o 
OUTF    = -o 
RM      = /bin/rm -f
CC      = gcc
FC = gfortran
FL = gfortran
AR = ar vr 
RANLIB  = echo

MKLROOT=/spack/apps/linux-centos7-x86_64/intel-19.0.4/intel-mkl-2019.5.281-ftihihwas7hnpmex6tt3luvqzuy6fgb7/compilers_and_libraries_2019.5.281/linux/mkl/lib/intel64_lin
LAPACK = -L$(MKLROOT) -lmkl_sequential -lmkl_intel_lp64 -lmkl_core

INCSEQ = -I$(topdir)/libseq
LIBSEQ  = $(LAPACK) -L$(topdir)/libseq -lmpiseq

#LIBBLAS = /usr/local/lib/libgoto_coppermine32p-r1.00.so
LIBBLAS = -L/spack/apps/linux-centos7-x86_64/intel-19.0.4/intel-mkl-2019.5.281-ftihihwas7hnpmex6tt3luvqzuy6fgb7/compilers_and_libraries_2019.5.281/linux/mkl/lib/intel64_lin/libmkl_intel_lp64.so
LIBOTHERS = -lpthread

#Preprocessor defs for calling Fortran from C (-DAdd_ or -DAdd__ or -DUPPER)
CDEFS   = -DAdd_

#Begin Optimization options
OPTF    = -O -fPIC 
OPTL    = -O -I. -fPIC
OPTC    = -O -fPIC 
#End Optimization options

 

INCS = $(INCSEQ)
LIBS = $(LIBSEQ)
LIBSEQNEEDED = libseqneeded
