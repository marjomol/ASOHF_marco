**********************************************************************
       PROGRAM ASOHF_v18
***********************************************************************
***********************************************************************
*      ASOHF IS AN ADAPTIVE SPHERICAL OVERDENSITY HALO FINDER.
*      IT FINDS HALOES AND SUBHALOES IN A COSMOLOGICAL SIMULATION,
*      BUILDS THEIR MERGING HISTORIES AND COMPUTES THEIR MAIN PHYSICAL
*      PROPERTIES.
***********************************************************************
*      For further details: Planelles & Quilis, 2010. A&A, 519:A94
***********************************************************************
*
*      Version: asohf_paralel_v8_NewVeins.f
*      (masclet1:/scratch/planelles/project_statistics/ASOHF/ASOHF_SA)
*
*---------------------GENERAL CONSIDERATIONS--------------------------*
*      In this version the merger tree is done every 2 iterations and
*      therefore, MAXITER=2 and MAXITER2=real num. of iters (MARK)
*
*      # INPUT FILES:
*           1)asohf_parameters.dat
*           2)asohf.dat
*
*      # OUTPUT FILES:
*           1)Families00000 ---> general information of all haloes
*           2)Merger_t00000 (optional, PLOT=2) ---> with %
*           3)Merger_r00000 (optional, PLOT=3) ---> main line
*           4)Grid_asohf00000 (only when FLAG_SA=0)
*
*           If REALCLUS(I)= -1  ------> HALO
*                             = 0   ------> RUBBISH (double or poor)
*                             = #>0 ------> SUBHALO within #
*
*           Proceeding way: 1)Halo refinement with DM particles
*                           2)Halo classification
*
*      # DATA TO READ:
*           1) MASCLET simulation in the "simu_masclet" directory
*           2) External file of particles: "particle_list.dat".
*              File in ascci containing:
*                #1st line        ---> NPARTICULAS,ZETA,T,N_GAS,N_DM
*                #1 line/particle ---> ID,X,Y,Z,VX,VY,VZ,MASS
*                 - Positions should go in units of Mpc within [0, L_box]
*                 - Velocities should go in units of c.
*                 - Masses should go in units of 9.1717e18 M_sun
*
*------------------------PREVIOUS SETTINGS----------------------------*
*      FLAG_SA     --> stand-alone halo finder(=0) or MASCLETs grid(=1)
*      FLAG_MASCLET--> MASCLET "as" stand-alone (=1)(it needs flag_sa=0)
*      FLAG_GAS    --> there is gas(=1) or only DM(=0) (see VAR!!)
*
*      If PLOT=2---> MERGER TREE WITH % (ONLY FOR HALOES AT IR=0)
*      If PLOT=3---> REDUCED MERGER TREE (ONLY FOR HALOES AT IR=0)
*
*      OJO!!! ONLY INTERNAL USE!!! hay que cambiar a mano:
*             1) El valor de las distintas COTAS
*             2) Rellenar las distintas especies de particulas
*             3) Tal y como esta, estamos pasando del gas al
*                construir la malla aunque si que lo leemos
**********************************************************************

       IMPLICIT NONE

       INCLUDE 'input_files/asohf_parameters.dat'

       INTEGER I,J,K,I2,J2
       INTEGER NX,NY,NZ,ITER,NDXYZ
       REAL*4 T,TEI

       REAL*4  RADX(0:NMAX+1),RADY(0:NMAY+1),RADZ(0:NMAZ+1)
       COMMON /GRID/   RADX,RADY,RADZ

       REAL*4  RX(0:NAMRX+1,NPALEV),RY(0:NAMRX+1,NPALEV),
     &         RZ(0:NAMRX+1,NPALEV)
       COMMON /GRIDAMR/ RX,RY,RZ

       REAL*4 PI,ACHE,T0,RE0,PI4ROD
       COMMON /DOS/ACHE,T0,RE0
       REAL*4 UNTERCIO,CGR,CGR2,ZI,RODO,ROI,REI,LADO,LADO0
       COMMON /CONS/PI4ROD,REI,CGR,PI
       REAL*4 OMEGA0

       REAL*4 RETE,HTE,ROTE
       COMMON /BACK/ RETE,HTE,ROTE

       REAL*4 DX,DY,DZ,H2
       COMMON /ESPACIADO/ DX,DY,DZ

       REAL*4 UV, UM

       INTEGER IX,JY,KZ,NL,IR,L1
       REAL*4 RX2,RY2,RZ2,A1,A2,B1,C1,A3,A4
       REAL*4 DXPA,DYPA,DZPA

*      VARIABLES
       REAL*4 U1(NMAX,NMAY,NMAZ)
       REAL*4 U11(NAMRX,NAMRY,NAMRZ,NPALEV)
       COMMON /VARIA/ U1,U11

c       REAL*4 POT(NMAX,NMAY,NMAZ)
c       REAL*4 POT1(NAMRX,NAMRY,NAMRZ,NPALEV)

       INTEGER NPATCH(0:NLEVELS)
       INTEGER PARE(NPALEV)
       INTEGER PATCHNX(NPALEV)
       INTEGER PATCHNY(NPALEV)
       INTEGER PATCHNZ(NPALEV)
       INTEGER PATCHX(NPALEV)
       INTEGER PATCHY(NPALEV)
       INTEGER PATCHZ(NPALEV)
       REAL*4  PATCHRX(NPALEV)
       REAL*4  PATCHRY(NPALEV)
       REAL*4  PATCHRZ(NPALEV)

       INTEGER NPART(0:NLEVELS)
       REAL*4 U2DM(PARTIRED),U3DM(PARTIRED),U4DM(PARTIRED)
       REAL*4 MASAP(PARTIRED)
       REAL*4 RXPA(PARTIRED),RYPA(PARTIRED),RZPA(PARTIRED)
       INTEGER ORIPA(PARTIRED)
       INTEGER NPART_ESP(0:N_ESP-1),NDMPART_X(0:NMAX)

       INTEGER SOLAP(NAMRX,NAMRY,NAMRZ,NPALEV)

       INTEGER FIRST,LAST,EVERY,NFILE,NFILE2,IFI2
       INTEGER N1,N2,N3,VAR,KONTA2,MAX_NUM_PART
       INTEGER NCLUS
       INTEGER*4 DATE(3), TIME(3)
       REAL ZETA,CONTRASTEC,F2,MAP,OMEGAZ

*      ---HALOS AND SUBHALOS---
       REAL*4 MASA(MAXNCLUS), RADIO(MAXNCLUS)
       REAL*4 CLUSRX(MAXNCLUS),CLUSRY(MAXNCLUS),CLUSRZ(MAXNCLUS)
       REAL*4 CLUSRXCM(MAXNCLUS),CLUSRYCM(MAXNCLUS),CLUSRZCM(MAXNCLUS)
       REAL*4 MSUB(MAXNCLUS),RSUB(MAXNCLUS)
       INTEGER PATCHCLUS(MAXNCLUS),REALCLUS(MAXNCLUS)
       INTEGER HALBORDERS(MAXNCLUS),LEVHAL(MAXNCLUS)
       REAL*4 CONCENTRA(NMAXNCLUS)
       REAL*4 ANGULARM(3,NMAXNCLUS)
       REAL*4 VMAXCLUS(NMAXNCLUS)
       INTEGER IPLIP(NMAXNCLUS)
       REAL*4 VX(NMAXNCLUS),VY(NMAXNCLUS),VZ(NMAXNCLUS)
       REAL*4 MEAN_VR(NMAXNCLUS)
       REAL*4 VCMAX(NMAXNCLUS),MCMAX(NMAXNCLUS),RCMAX(NMAXNCLUS)
       REAL*4 M200C(NMAXNCLUS),R200C(NMAXNCLUS)
       REAL*4 M500C(NMAXNCLUS),R500C(NMAXNCLUS)
       REAL*4 M2500C(NMAXNCLUS),R2500C(NMAXNCLUS)
       REAL*4 M200M(NMAXNCLUS),R200M(NMAXNCLUS)
       REAL*4 M500M(NMAXNCLUS),R500M(NMAXNCLUS)
       REAL*4 M2500M(NMAXNCLUS),R2500M(NMAXNCLUS)
       REAL*4 PROFILES(NBINS,2,NMAXNCLUS)
       REAL*4 VELOCITY_DISPERSION(NMAXNCLUS)
       REAL*4 RMAXSIGMA(NMAXNCLUS),MMAXSIGMA(NMAXNCLUS)
       REAL*4 KINETIC_E(NMAXNCLUS),POTENTIAL_E(NMAXNCLUS)
       REAL*4 FSUB(NMAXNCLUS) ! fraction of mass in substructures
       INTEGER NSUBS(NMAXNCLUS) ! number of substructures
       INTEGER PARTICLES_PER_HALO(PARTIRED)
       INTEGER INDCS_PARTICLES_PER_HALO(2,NMAXNCLUS)
       INTEGER DMPCLUS(MAXNCLUS)
       INTEGER NHALLEV(0:NLEVELS),SUBS_LEV(0:NLEVELS)
       INTEGER SUBHALOS(NMAXNCLUS)
       REAL*4 EIGENVAL(3,NMAXNCLUS)
       REAL*4 INERTIA_TENSOR(6,NMAXNCLUS)

*      ---STAND-ALONE HALO FINDER---
       INTEGER FLAG_SA,FLAG_GAS,FLAG_MASCLET,FLAG_WDM
       INTEGER N_DM,N_PARTICLES,N_ST,N_GAS,IR_KERN_STARS,MIN_NUM_PART
       INTEGER SPLIT_SPECIES,BORDES,PARCHLIM
       INTEGER MPAPOLEV(NLEVELS)
       INTEGER REFINE_THR,MIN_PATCHSIZE,INTERP_DEGREE
       INTEGER BOR,BORAMR,BOR_OVLP
       REAL MINFRAC_REFINABLE,VOL_SOLAP_LOW,BOUND

*      ---PARALLEL---
       INTEGER NUM,OMP_GET_NUM_THREADS,NUMOR,FLAG_PARALLEL
       COMMON /PROCESADORES/ NUM

       INTEGER NMAXNCLUSBAS,PABAS,NPBAS,NLEVBAS,NBASPART_PLOT
       INTEGER FLAG_SUBS,FLAG_CENTRAL,DO_COMPUTE_ENERGIES
       INTEGER FW1,FW2,FW3,FW4,FW5

       INTEGER CR0AMR(NMAX,NMAY,NMAZ)
       INTEGER CR0AMR11(NAMRX,NAMRY,NAMRZ,NPALEV)

       CHARACTER*5 ITER_STRING

**************************************************************
*      OPENING FILES
**************************************************************
       OPEN(1,FILE='./input_files/asohf.dat',
     &              STATUS='UNKNOWN',ACTION='READ')


*      READING INITIAL DATA
****************************************************
*     NX,NY,NZ < or = NMAX,NMAY,NMAZ               *
****************************************************
       READ(1,*) !***********************************************************************
       READ(1,*) !*                         ASOHF PARAMETERS FILE                       *
       READ(1,*) !***********************************************************************
       READ(1,*) !*       General parameters block                                      *
       READ(1,*) !***********************************************************************
       READ(1,*) !Files: first, last, every -------------------------------------------->
       READ(1,*) FIRST,LAST,EVERY
       READ(1,*) !Cells per direction (NX,NY,NZ) --------------------------------------->
       READ(1,*) NX,NY,NZ
       READ(1,*) !DM particles (all levels) ---------------------------------------->
       READ(1,*) N_DM
       READ(1,*) !Hubble constant (h), omega matter ------------------------------------>
       READ(1,*) ACHE,OMEGA0
       READ(1,*) !Initial redshift, box size (Mpc) ------------------------------------->
       READ(1,*) ZI,LADO0
       READ(1,*) !Parallel(=1),serial(=0)/ Number of processors ------------------------>
       READ(1,*) FLAG_PARALLEL,NUM
       READ(1,*) !Reading flags: FLAG_SA,FLAG_MASCLET,FLAG_GAS ------------------------->
       READ(1,*) FLAG_SA,FLAG_MASCLET,FLAG_GAS
       READ(1,*) !Output flags: grid_asohf,density,haloes_grids,subs_grids,subs_part --->
       READ(1,*) FW1,FW2,FW3,FW4,FW5
       READ(1,*) !***********************************************************************
       READ(1,*) !*       Mesh building parameters block                                *
       READ(1,*) !***********************************************************************
       READ(1,*) !Levels for the mesh (stand-alone) ------------------------------------>
       READ(1,*) NL
       IF (NL.GT.NLEVELS) THEN
        WRITE(*,*) 'Fatal ERROR: NLEVELS too small in parameters file',
     &             NL,NLEVELS
        STOP
       END IF
       READ(1,*) !PARCHLIM(=0 no limit patches/level,>0 limit) ------------------------->
       READ(1,*) PARCHLIM
       READ(1,*) !LIM=max num patches/level(needs PARCHLIM>0) -------------------------->
       IF (PARCHLIM.EQ.1) THEN
        READ(1,*) (MPAPOLEV(I),I=1,NL)
       ELSE
        READ(1,*)
       END IF
       READ(1,*) !Refinement threshold (num. part.), refinable fraction to extend ------>
       READ(1,*) REFINE_THR,MINFRAC_REFINABLE
       READ(1,*) !Minimum patch size (child cells) ------------------------------------->
       READ(1,*) MIN_PATCHSIZE
       READ(1,*) !Base grid refinement border, AMR grids refinement border ------------->
       READ(1,*) BOR,BORAMR
       READ(1,*) !Allow for addition overlap (to avoid losing signal) in the mesh ------>
       READ(1,*) BOR_OVLP
       READ(1,*) !Density interpolation kernel (1=linear, 2=quadratic) ----------------->
       READ(1,*) INTERP_DEGREE
       READ(1,*) !Variable for mesh halo finding: 1(dm), 2(dm+stars) ------------------->
       READ(1,*) VAR
       READ(1,*) !Kernel level for stars (if VAR=2) ------------------------------------>
       READ(1,*) IR_KERN_STARS
       READ(1,*) !Particle especies (0=there are different mass particles, 1=equal mass
       READ(1,*) !particles, use local density, 2=equal mass particles, do nothing) --->
       READ(1,*) SPLIT_SPECIES
       READ(1,*) !***********************************************************************
       READ(1,*) !*       Halo finding parameters block                                 *
       READ(1,*) !***********************************************************************
       READ(1,*) !Max. reach around halos (Mpc), excluded cells in boundaries ---------->
       READ(1,*) BOUND, BORDES
       READ(1,*) !Minimum fraction of shared volume to merge (in grid search) ---------->
       READ(1,*) VOL_SOLAP_LOW
       READ(1,*) !FLAG_WDM (=1 write DM particles, =0 no) ------------------------------>
       READ(1,*) FLAG_WDM
       READ(1,*) !Search for substructure (=1 yes, =0 no) ------------------------------>
       READ(1,*) FLAG_SUBS
       READ(1,*) !Search for cores (max sigma_v of bound particles) (=1 yes, =0 no) ---->
       READ(1,*) FLAG_CENTRAL
       READ(1,*) !Compute kinetic and potential energies (=1 yes, =0 no) --------------->
       READ(1,*) DO_COMPUTE_ENERGIES
       READ(1,*) !Minimum number of particles per halo --------------------------------->
       READ(1,*) MIN_NUM_PART

       CLOSE(1)

       N_PARTICLES=N_DM
       H2=ACHE

**************************************************************
*     ...PARALLEL RUNNING...
!$OMP PARALLEL SHARED(NUM)
!$OMP SINGLE
!$      NUM=OMP_GET_NUM_THREADS()
!$OMP END SINGLE NOWAIT
!$OMP END PARALLEL
**************************************************************

       CALL IDATE(DATE)
       CALL ITIME(TIME)
       WRITE(*,*) 'DATE=',DATE(1),'/',DATE(2),'/',DATE(3)
       WRITE(*,*) 'TIME=',TIME(1),':',TIME(2),':',TIME(3)

       WRITE(*,*) '************************************************'
       WRITE(*,*) '             GENERAL SETTINGS                   '
       WRITE(*,*) '************************************************'

       IF (FLAG_PARALLEL.EQ.1) THEN
         WRITE(*,*)'Running in PARALLEL in',NUM, 'processors'
       END IF
       IF (FLAG_PARALLEL.EQ.0)  WRITE(*,*)'Running in SERIAL...'

       IF(FLAG_SA.EQ.0.AND.FLAG_MASCLET.EQ.0)
     &       WRITE(*,*) 'ASOHF as stand-alone Halo Finder...'
       IF(FLAG_SA.EQ.0.AND.FLAG_MASCLET.EQ.1)
     &       WRITE(*,*) 'ASOHF reading MASCLET PARTICLES...'
       IF(FLAG_SA.EQ.1)
     &       WRITE(*,*) 'ASOHF reading MASCLETs GRID...'

       IF(VAR.EQ.1) WRITE(*,*) 'Analysing only DM'
       IF(VAR.EQ.2) WRITE(*,*) 'Analysing DM+stars'

       WRITE(*,*) 'Min. number of particles per halo ',MIN_NUM_PART


***************************
*      GRID BUILDER
***************************
       LADO=LADO0-(LADO0/NX)
       CALL MALLA(NX,NY,NZ,LADO)

       WRITE(*,*)
       WRITE(*,*) '************************************************'
       WRITE(*,*) '                     GRID                       '
       WRITE(*,*) '************************************************'
       WRITE(*,*) 'SIDE LENGTH=',LADO
       WRITE(*,*) 'NX,DX,RADX(1),RADX(NX)=',NX,DX,RADX(1),RADX(NX)
       WRITE(*,*) 'NUMBER OF PATCHES PER LEVEL:'
       IF (PARCHLIM.EQ.0) WRITE(*,*) '  No limited patches per level!'
       IF (PARCHLIM.NE.0) THEN
             WRITE(*,*) '  Limit patches per level=', MPAPOLEV(1)
       END IF
       WRITE(*,*)



*********************************************************************
*      COSMOLOGICAL BACKGROUND
*********************************************************************
       PI=DACOS(-1.D0)
       UNTERCIO=1.D0/3.D0
       CGR=1.D0/(8.D0*PI)
       CGR2=2.D0*CGR
       ACHE=ACHE*3.66D-3
*      T0=364.298725        !T0=ACTUAL TIME
       T0=2.D0*UNTERCIO/ACHE
       RODO=OMEGA0*3.D0*ACHE**2
*      scale factor must be = 1Mpc  at z=0  in order to be consistent
*      with inipk.f and ini3d.f
*      in arbitrary units 1 ul=10.98 Mpc
       RE0=1.0/10.98
       ROI=RODO*(1.0+ZI)**3
       PI4ROD=4.D0*PI*ROI
       REI=RE0/(1.0+ZI)
       TEI=T0*(1.0+ZI)**(-1.5)   !TEI=INITIAL TIME

       UV=299792.458
       UM=9.1717E+18
       F2=LOG(3.0)-(2.0/3.0)

       HTE=ACHE !!!!!!!!!!!! DEBE PONER BIEN

********************************************************************
********************************************************************

       NFILE2=INT((LAST-FIRST)/EVERY) + 1
       WRITE(*,*)'Number of iterations to analise=',NFILE2

*///////// MAIN LOOP (ITERATIONS) /////////
*//////////////////////////////////////////
       DO IFI2=1, NFILE2                 !/
*//////////////////////////////////////////
*//////////////////////////////////////////

        ITER=FIRST+EVERY*(IFI2-1)

        WRITE(*,*)
        WRITE(*,*) '************************************************'
        WRITE(*,*) '************************************************'
        WRITE(*,*) '* STARTING ITER', ITER, IFI2
        WRITE(*,*) '************************************************'
        WRITE(*,*) '************************************************'
        WRITE(*,*)
        WRITE(ITER_STRING, '(I5.5)') ITER !For saving files to disk

        NMAXNCLUSBAS=MAXNCLUS
!$OMP PARALLEL DO SHARED(NMAXNCLUSBAS,CLUSRX,CLUSRY,CLUSRZ,CLUSRXCM,
!$OMP+                   CLUSRYCM,CLUSRZCM,MASA,RADIO,MSUB,RSUB,
!$OMP+                   PATCHCLUS,REALCLUS,HALBORDERS,LEVHAL),
!$OMP+            PRIVATE(I)
        DO I=1,NMAXNCLUSBAS
         CLUSRX(I)=0.0
         CLUSRY(I)=0.0
         CLUSRZ(I)=0.0
         CLUSRXCM(I)=0.0
         CLUSRYCM(I)=0.0
         CLUSRZCM(I)=0.0
         MASA(I)=0.0
         RADIO(I)=0.0
         MSUB(I)=0.0
         RSUB(I)=0.0
         PATCHCLUS(I)=0
         REALCLUS(I)=0
         HALBORDERS(I)=0
         LEVHAL(I)=0
        END DO

        NMAXNCLUSBAS=NMAXNCLUS
!$OMP PARALLEL DO SHARED(NMAXNCLUSBAS,VCMAX,MCMAX,RCMAX,DMPCLUS,M200C,
!$OMP+                   M500C,M2500C,M200M,M500M,M2500M,R200C,R500C,
!$OMP+                   R2500C,R200M,R500M,R2500M,IPLIP,REALCLUS,
!$OMP+                   LEVHAL,EIGENVAL,INERTIA_TENSOR,MEAN_VR,
!$OMP+                   VELOCITY_DISPERSION,RMAXSIGMA,MMAXSIGMA,
!$OMP+                   KINETIC_E,POTENTIAL_E,FSUB,NSUBS,
!$OMP+                   INDCS_PARTICLES_PER_HALO,CONCENTRA,ANGULARM,
!$OMP+                   VX,VY,VZ,PROFILES,VMAXCLUS,SUBHALOS),
!$OMP+            PRIVATE(I),
!$OMP+            DEFAULT(NONE)
        DO I=1,NMAXNCLUSBAS
         VCMAX(I)=0.0
         MCMAX(I)=0.0
         RCMAX(I)=0.0
         M200C(I)=0.0
         M500C(I)=0.0
         M2500C(I)=0.0
         M200M(I)=0.0
         M500M(I)=0.0
         M2500M(I)=0.0
         R200C(I)=0.0
         R500C(I)=0.0
         R2500C(I)=0.0
         R200M(I)=0.0
         R500M(I)=0.0
         R2500M(I)=0.0
         IPLIP(I)=0
         LEVHAL(I)=0
         DMPCLUS(I)=0
         REALCLUS(I)=0    !de momento no hay halos
         EIGENVAL(:,I)=0.0
         INERTIA_TENSOR(:,I)=0.0
         MEAN_VR(I)=0.0
         VELOCITY_DISPERSION(I)=0.0
         RMAXSIGMA(I)=0.0
         MMAXSIGMA(I)=0.0
         KINETIC_E(I)=0.0
         POTENTIAL_E(I)=0.0
         FSUB(I)=0.0
         NSUBS(I)=0
         INDCS_PARTICLES_PER_HALO(:,I)=0
         CONCENTRA(I)=0.0
         ANGULARM(:,I)=0.0
         VMAXCLUS(I)=0.0
         VX(I)=0.0
         VY(I)=0.0
         VZ(I)=0.0
         PROFILES(:,:,I)=0
         SUBHALOS(I)=0
        END DO

        PATCHNX=0
        PATCHNY=0
        PATCHNZ=0
        PATCHX=0
        PATCHY=0
        PATCHZ=0
        PATCHRX=0.0
        PATCHRY=0.0
        PATCHRZ=0.0

        NPATCH=0
        PARE=0

!$OMP PARALLEL DO SHARED(NX,NY,NZ,U1),PRIVATE(I,J,K)
        DO K=1,NZ
        DO J=1,NY
        DO I=1,NX
         U1(I,J,K)=-1.0        !valores minimos
        END DO
        END DO
        END DO

**********
*     cambio especial para paralelizar!!
**********
        N1=NAMRX                !dimension max de todos los parches
        NPBAS=NPALEV            !numero total maximo de parches
        PABAS=PARTIRED
        NLEVBAS=NLEVELS         !numero maximo de niveles
        NMAXNCLUSBAS=MAXNCLUS   !num max de candidatos a halo
**********


!$OMP PARALLEL DO SHARED(NPBAS,N1,U11),
!$OMP+        PRIVATE(IX,JY,KZ,I)
        DO I=1,NPBAS
         DO KZ=1,N1
         DO JY=1,N1
         DO IX=1,N1
          U11(IX,JY,KZ,I)=-1.0
         END DO
         END DO
         END DO
        END DO

        NHALLEV=0
        SUBS_LEV=0
        NPART=0

!$OMP PARALLEL DO SHARED(NMAXNCLUSBAS,MASA,RADIO,
!$OMP+                   CLUSRX,CLUSRY,CLUSRZ,LEVHAL),
!$OMP+            PRIVATE(I)
        DO I=1,NMAXNCLUSBAS
         CLUSRX(I)=0.0
         CLUSRY(I)=0.0
         CLUSRZ(I)=0.0
         MASA(I)=0.0
         RADIO(I)=0.0
         LEVHAL(I)=0
        END DO

        NCLUS=0
        ROTE=0.0
        RETE=0.0

        SUBHALOS=0

!$OMP PARALLEL DO SHARED(PABAS,U2DM,U3DM,U4DM,RXPA,RYPA,RZPA,
!$OMP+                   MASAP,ORIPA,PARTICLES_PER_HALO),
!$OMP+            PRIVATE(I)
        DO I=1,PABAS
         U2DM(I)=0.0
         U3DM(I)=0.0
         U4DM(I)=0.0
         RXPA(I)=0.0
         RYPA(I)=0.0
         RZPA(I)=0.0
         MASAP(I)=0.0
         ORIPA(I)=0
         PARTICLES_PER_HALO(I)=0
        END DO

***************************************************
*     READING INPUT DATA
***************************************************

       IF (FLAG_SA.EQ.1) THEN
*       Reading MASCLET files directly
        CALL READ_MASCLET(VAR,ITER,NX,NY,NZ,NDXYZ,T,ZETA,NL,NPATCH,
     &            PARE,PATCHNX,PATCHNY,PATCHNZ,PATCHX,PATCHY,PATCHZ,
     &            PATCHRX,PATCHRY,PATCHRZ,MAP,U2DM,U3DM,U4DM,MASAP,
     &            NPART,RXPA,RYPA,RZPA,ORIPA,N_DM)

        ! Background cosmology variables
        ROTE=RODO*(1.0+ZETA)**3
        RETE=RE0/(1.0+ZETA)

       ELSE
*       Reading external list of particles (either Masclet particles
*       or a general list of particles, depending on FLAG_MASCLET)
        IF (FLAG_MASCLET.EQ.1) THEN
         CALL READ_PARTICLES_MASCLET(ITER,NX,NY,NZ,T,ZETA,MAP,
     &                               U2DM,U3DM,U4DM,MASAP,RXPA,
     &                               RYPA,RZPA,ORIPA,N_DM,VAR,N_ST)
         IF (N_ST.GT.0) N_PARTICLES=N_PARTICLES+N_ST
         WRITE(*,*) 'DM, stars, total particles:',N_DM,N_ST,N_PARTICLES
        ELSE
         CALL READ_PARTICLES_GENERAL(ITER,NX,NY,NZ,T,ZETA,NL,MAP,
     &                               U2DM,U3DM,U4DM,MASAP,RXPA,
     &                               RYPA,RZPA,ORIPA,LADO0,N_GAS,N_DM,
     &                               N_PARTICLES)
        END IF

        IF (SPLIT_SPECIES.EQ.0) THEN
         CALL SORT_DM_PARTICLES(U2DM,U3DM,U4DM,MASAP,RXPA,RYPA,RZPA,
     &                          ORIPA,N_DM,NPART_ESP,N_ST,IR_KERN_STARS)
        ELSE IF (SPLIT_SPECIES.EQ.1) THEN
         CALL SORT_DM_PARTICLES_LOCALDENSITY(U2DM,U3DM,U4DM,MASAP,RXPA,
     &                          RYPA,RZPA,ORIPA,N_DM,NPART_ESP,N_ST,
     &                          IR_KERN_STARS,RODO,RE0)
        ELSE IF (SPLIT_SPECIES.EQ.2) THEN
         NPART_ESP(0)=N_DM
         NPART_ESP(1:N_ESP-1)=0
        END IF

!      FIX THIS, REMOVE NPART (USELESS) FROM EVERYWHERE
       !NPART=0
       !NPART=N_DM
       ! for now, we will leave it like this for this to work temporarily
        NPART=0
        NPART(0)=N_PARTICLES

        ! Background cosmology variables
        ROTE=RODO*(1.0+ZETA)**3
        RETE=RE0/(1.0+ZETA)

        WRITE(*,*)
        WRITE(*,*)'***********************'
        WRITE(*,*)'***** MESHRENOEF ******'
        WRITE(*,*)'***********************'
        WRITE(*,*)

        IF (NL.GT.0) THEN
         WRITE(*,*)'==== Building the grid...', ITER, NL
         CALL CREATE_MESH(ITER,NX,NY,NZ,NL,NPATCH,PARE,PATCHNX,PATCHNY,
     &                    PATCHNZ,PATCHX,PATCHY,PATCHZ,PATCHRX,PATCHRY,
     &                    PATCHRZ,RXPA,RYPA,RZPA,U2DM,U3DM,U4DM,MASAP,
     &                    N_PARTICLES,N_DM,N_GAS,LADO0,T,ZETA,
     &                    REFINE_THR,MIN_PATCHSIZE,MINFRAC_REFINABLE,
     &                    BOR,BORAMR,BOR_OVLP,NPART_ESP,FW1)
         WRITE(*,*)'==== END building the grid...', ITER, NL
        END IF

c        WRITE(*,*) 'TSC density interpolation, levels min,max:',0,NL_TSC
c        CALL INTERPOLATE_DENSITY(ITER,NX,NY,NZ,NL_TSC,NPATCH,PARE,
c     &           PATCHNX,PATCHNY,PATCHNZ,PATCHX,PATCHY,PATCHZ,
c     &           PATCHRX,PATCHRY,PATCHRZ,RXPA,RYPA,RZPA,MASAP,
c     &           N_PARTICLES,N_DM,N_GAS,LADO0,T,ZETA,NPART_ESP)
c
c        IF (NL_TSC.LT.NL) THEN
c         WRITE(*,*) 'Smooth density interpolation, levels min,max:',
c     &              NL_TSC+1,NL
c         CALL INTERPOLATE_DENSITY_KERNEL(ITER,NX,NY,NZ,NL_TSC,
c     &            NL,NPATCH,PARE,PATCHNX,PATCHNY,PATCHNZ,PATCHX,
c     &            PATCHY,PATCHZ,PATCHRX,PATCHRY,PATCHRZ,RXPA,RYPA,RZPA,
c     &            MASAP,N_PARTICLES,N_DM,N_GAS,LADO0,T,ZETA,NPART_ESP)
c        END IF

       CALL DENSITY(ITER,NX,NY,NZ,NL,NPATCH,PARE,PATCHNX,PATCHNY,
     &              PATCHNZ,PATCHX,PATCHY,PATCHZ,PATCHRX,PATCHRY,
     &              PATCHRZ,RXPA,RYPA,RZPA,MASAP,N_PARTICLES,N_DM,
     &              N_GAS,LADO0,T,ZETA,NPART_ESP,INTERP_DEGREE)

       WRITE(*,*)'***************************'
       WRITE(*,*)'***** END MESHRENOEF ******'
       WRITE(*,*)'***************************'

       END IF

c       CALL POISSON(NL,NX,NY,NZ,DX,NPATCH,PARE,PATCHNX,PATCHNY,
c     &              PATCHNZ,PATCHX,PATCHY,PATCHZ,PATCHRX,PATCHRY,
c     &              PATCHRZ,RXPA,RYPA,RZPA,MASAP,N_PARTICLES,N_DM,
c     &              LADO0,POT,POT1)

c       DO IR=1,NL
c       DO I=SUM(NPATCH(0:IR-1))+1,SUM(NPATCH(0:IR))
c        N1=PATCHNX(I)
c        N2=PATCHNY(I)
c        N3=PATCHNZ(I)
c        WRITE(*,*) IR,I,SUM(U11(1:N1,1:N2,1:N3,I))/(N1*N2*N3),
c     &             MAXVAL(U11(1:N1,1:N2,1:N3,I))
c       END DO
c       END DO

****************************************************************
*      VIRIAL CONTRAST ! gets CONTRASTEC and OMEGAZ
*      (Bryan & Norman ApJ, 1998)
*      Delta_vir,c = 18*pi^2 + 82 x - 39 x^2; x=Omega_m(z)-1
****************************************************************
       CALL BRYAN_NORMAN_98(CONTRASTEC,OMEGAZ,OMEGA0,ZETA)

c       WRITE(*,*) '***************************'
       WRITE(*,*) '* COSMOLOGICAL PARAMETERS *'
       WRITE(*,*) '***************************'
       WRITE(*,*) 'RETE=', RETE
       WRITE(*,*) 'ROTE=', ROTE
       WRITE(*,*) 'RODO,RE0,OMEGA0,OMEGAZ=', RODO,RE0,OMEGA0,OMEGAZ
       WRITE(*,*) 'Z=', ZETA
       WRITE(*,*) 'CONTRASTEC=',CONTRASTEC
c       WRITE(*,*) '***************************'

**************************************************************
*      Cleaning overlaps of patches
*      NOTE! we correct overlaps and not refinements because
*            we work within each level independentely
**************************************************************

       ! SOLAP: overlaps at level IR; (=1, keep), (=0, overlapped)
       DO IR=1,NL
        CALL VEINSGRID(IR,NL,NPATCH,PARE,PATCHNX,PATCHNY,PATCHNZ,
     &                 PATCHX,PATCHY,PATCHZ,PATCHRX,PATCHRY,PATCHRZ,
     &                 SOLAP)
       END DO

******* Compute CR0AMR *********************************************
       CALL COMPUTE_CR0AMR(NL,NX,NY,NZ,NPATCH,PARE,PATCHNX,PATCHNY,
     &                     PATCHNZ,PATCHX,PATCHY,PATCHZ,PATCHRX,
     &                     PATCHRY,PATCHRZ,CR0AMR,CR0AMR11,LADO0)


       CALL RENORM_DENSITY(NL,NX,NY,NZ,NPATCH,PATCHNX,PATCHNY,PATCHNZ,
     &                     CR0AMR,CR0AMR11,SOLAP,U1,U11,LADO0,RODO,RE0)

       IF (FW2.EQ.1) THEN
        OPEN(99,
     &       FILE='output_files/density_asohf'//ITER_STRING//'.res',
     &       STATUS='UNKNOWN',FORM='UNFORMATTED')
          write(99) (((u1(ix,jy,kz),ix=1,nx),jy=1,ny),kz=1,nz)
          write(99) (((cr0amr(ix,jy,kz),ix=1,nx),jy=1,ny),kz=1,nz)
          do i=1,sum(npatch(0:nl))
           n1=patchnx(i)
           n2=patchny(i)
           n3=patchnz(i)
           write(99) (((u11(ix,jy,kz,i),ix=1,n1),jy=1,n2),kz=1,n3)
           write(99) (((cr0amr11(ix,jy,kz,i),ix=1,n1),jy=1,n2),kz=1,n3)
           write(99) (((solap(ix,jy,kz,i),ix=1,n1),jy=1,n2),kz=1,n3)
          end do
        CLOSE(99)
       END IF
*********************************************************************

c       CALL CLEAN_OVERLAPS(NL,NPATCH,PATCHNX,PATCHNY,PATCHNZ,SOLAP,
c     &                     U11)

**********************************************************************
******************************HALO FINDER*****************************
**********************************************************************

       WRITE(*,*)
       WRITE(*,*) '***************************'
       WRITE(*,*) '***    HALO FINDING     ***'
       WRITE(*,*) '***************************'

       CALL SORT_DM_PARTICLES_X(U2DM,U3DM,U4DM,MASAP,RXPA,RYPA,RZPA,
     &                          ORIPA,N_DM,NDMPART_X,NX,LADO0)


**********************************************************
*      Looking for candidate haloes at the AMR levels
**********************************************************

       CALL HALOFIND_GRID(NL,NX,NY,NZ,NPATCH,PATCHNX,PATCHNY,
     &                    PATCHNZ,PATCHX,PATCHY,PATCHZ,PATCHRX,
     &                    PATCHRY,PATCHRZ,PARE,NCLUS,MASA,RADIO,
     &                    CLUSRX,CLUSRY,CLUSRZ,REALCLUS,LEVHAL,
     &                    NHALLEV,BOUND,CONTRASTEC,RODO,
     &                    SOLAP,CR0AMR,CR0AMR11,PATCHCLUS,
     &                    VOL_SOLAP_LOW,CLUSRXCM,CLUSRYCM,CLUSRZCM)

       IF (FW3.EQ.1) THEN
        open(55,
     &       file='./output_files/haloesgrids'//ITER_STRING//'.res',
     &       status='unknown')
        do i=1,nclus
         write(55,*) clusrx(i),clusry(i),clusrz(i),radio(i),masa(i),
     &               levhal(i), realclus(i), patchclus(i)
        end do
        close(55)
       END IF

*******************************************************
*      SORTING OUT ALL THE CLUSTERS
*******************************************************

       CALL RE_SORT_HALOES(NCLUS,NHALLEV,REALCLUS,CLUSRX,CLUSRY,CLUSRZ,
     &                     RADIO,MASA,LEVHAL,PATCHCLUS,DMPCLUS)

       WRITE(*,*)'MASSES: MIN, MAX AND MEAN=', MINVAL(MASA(1:NCLUS))*UM,
     &            MAXVAL(MASA(1:NCLUS))*UM, SUM(MASA(1:NCLUS))/NCLUS*UM
       WRITE(*,*) 'NCLUS=', NCLUS

***************************************************************
**     HALOES AT THE EDGES OF THE BOX (JUST FOR CAUTION!)     *
***************************************************************

       IF (BORDES.EQ.1) THEN
        CALL HALOES_BORDER(NCLUS,CLUSRX,CLUSRY,CLUSRZ,RADIO,LADO0,
     &                     HALBORDERS)
        WRITE(*,*) 'Haloes close to the box borders:',
     &             SUM(HALBORDERS(1:NCLUS))
       END IF

************************************************************
**     Eliminating POOR haloes (less than a minimum number of particles)
**     (We start here to work with partciles for the 1st time)
************************************************************

       CALL PRUNE_POOR_HALOES(NCLUS,CLUSRX,CLUSRY,CLUSRZ,RADIO,
     &                        REALCLUS,RXPA,RYPA,RZPA,N_DM,MIN_NUM_PART,
     &                        DMPCLUS,NDMPART_X,LADO0,1.0,1)
       CALL RE_SORT_HALOES(NCLUS,NHALLEV,REALCLUS,CLUSRX,CLUSRY,CLUSRZ,
     &                     RADIO,MASA,LEVHAL,PATCHCLUS,DMPCLUS)

*********************************************************
*      CHECKING....
*********************************************************
       WRITE(*,*) '---------------------------------'
       WRITE(*,*) 'CHECKING GRID FINDING:'
       KONTA2=COUNT(REALCLUS(1:NCLUS).EQ.-1)
       WRITE(*,*) 'REAL, FREE HALOS --->', KONTA2
       WRITE(*,*) '---------------------------------'
*********************************************************

************************************************************
*      REFINING REAL HALOES WITH THE DM PARTICLES ONLY     *
************************************************************

       WRITE(*,*)
       WRITE(*,*)'=================================='
       WRITE(*,*)'Refining with DM particles...'
       WRITE(*,*)'=================================='

       CALL HALOFIND_PARTICLES(NL,NCLUS,MASA,RADIO,CLUSRX,CLUSRY,
     &      CLUSRZ,REALCLUS,CONCENTRA,ANGULARM,VMAXCLUS,IPLIP,VX,VY,VZ,
     &      VCMAX,MCMAX,RCMAX,M200C,M500C,M2500C,M200M,M500M,M2500M,
     &      MSUB,R200C,R500C,R2500C,R200M,R500M,R2500M,RSUB,DMPCLUS,
     &      LEVHAL,EIGENVAL,N_DM,RXPA,RYPA,RZPA,MASAP,U2DM,U3DM,U4DM,
     &      ORIPA,CONTRASTEC,OMEGAZ,UM,UV,LADO0,CLUSRXCM,CLUSRYCM,
     &      CLUSRZCM,MEAN_VR,INERTIA_TENSOR,NPATCH,PATCHCLUS,PROFILES,
     &      VELOCITY_DISPERSION,KINETIC_E,POTENTIAL_E,
     &      DO_COMPUTE_ENERGIES,PARTICLES_PER_HALO,
     &      INDCS_PARTICLES_PER_HALO,FLAG_WDM,ZETA,MIN_NUM_PART,
     &      NDMPART_X)

*************************************************
******** GENERAL CHECKING ***********************
*************************************************

       WRITE(*,*)'HALOES WITHOUT MASS=',
     &        COUNT(MASA(1:NCLUS).LE.0.0)
*       WRITE(*,*)'KKKONTA=',KKKONTA

       WRITE(*,*) 'Total number of particles within halos:',
     &            SUM(DMPCLUS(1:NCLUS))


c       WRITE(*,*)'After refining with DM particles...'
c       WRITE(*,*)'===================================='
c       DO I=0,NL
c       WRITE(*,*)'Haloes at level ', I,' =',
c     &            COUNT(LEVHAL(1:NCLUS).EQ.I
c     &            .AND.REALCLUS(1:NCLUS).NE.0),
c     &            COUNT(REALCLUS(1:NCLUS).EQ.-1)
c       END DO
c       WRITE(*,*)'===================================='

*************************************************

************************************************
************ REMOVING POOR HALOES **************
************************************************
       CALL PRUNE_POOR_HALOES(NCLUS,CLUSRX,CLUSRY,CLUSRZ,RADIO,
     &                        REALCLUS,RXPA,RYPA,RZPA,N_DM,MIN_NUM_PART,
     &                        DMPCLUS,NDMPART_X,LADO0,1.0,0)

************************************************
************** RUBBISH (overlaps) **************
************************************************

       CALL CHECK_RUBISH(NCLUS,REALCLUS,CLUSRX,CLUSRY,CLUSRZ,VX,VY,VZ,
     &                   MASA,RADIO,LEVHAL)

****************************************************
********* PRUNING ACCIDENTAL SUBSTRUCTURE **********
****************************************************

       CALL ACCIDENTAL_SUBSTRUCTURE(NCLUS,REALCLUS,CLUSRX,CLUSRY,CLUSRZ,
     &                              VX,VY,VZ,MASA,RADIO,LEVHAL)

       WRITE(*,*)
       WRITE(*,*) 'At the end...'
       WRITE(*,*) 'TOTAL NUMBER OF HALOS=',
     &            COUNT(REALCLUS(1:NCLUS).EQ.-1)
       WRITE(*,*)'=================================='
       DO I=0,NL
       WRITE(*,*)'Haloes at level ', I,' =',
     &            COUNT(LEVHAL(1:NCLUS).EQ.I.
     &            AND.REALCLUS(1:NCLUS).NE.0),
     &            COUNT(REALCLUS(1:NCLUS).EQ.-1)
       END DO
       WRITE(*,*)'=================================='
       SUBS_LEV(0)=NCLUS


****************************************************
****************************************************
****************************************************
       IF (FLAG_SUBS.EQ.1) THEN
        WRITE(*,*)
        WRITE(*,*) '***************************'
        WRITE(*,*) '** SUBSTRUCTURE SEARCH   **'
        WRITE(*,*) '***************************'

        IF (FW4.EQ.1) THEN
         OPEN(99, file='./output_files/substructuregrid'//
     &        ITER_STRING//'.res',status='unknown')
         CLOSE(99)
        END IF
        IF (FW5.EQ.1) THEN
         OPEN(99, file='./output_files/substructureparticles'//
     &        ITER_STRING//'.res',status='unknown')
         CLOSE(99)
        END IF

        DO IR=1,NL
         CALL SEARCH_SUBSTRUCTURE_GRID(IR,NL,NX,NY,NZ,NPATCH,PATCHNX,
     &                    PATCHNY,PATCHNZ,PATCHX,PATCHY,PATCHZ,PATCHRX,
     &                    PATCHRY,PATCHRZ,PARE,NCLUS,MASA,RADIO,CLUSRX,
     &                    CLUSRY,CLUSRZ,REALCLUS,LEVHAL,NHALLEV,BOUND,
     &                    CONTRASTEC,RODO,SOLAP,CR0AMR,CR0AMR11,
     &                    PATCHCLUS,VOL_SOLAP_LOW,CLUSRXCM,CLUSRYCM,
     &                    CLUSRZCM,RSUB,MSUB,SUBS_LEV,UM,PROFILES)

         IF (FW4.EQ.1) THEN
          open(99, file='./output_files/substructuregrid'//
     &        ITER_STRING//'.res',status='unknown',position='append')
          do i=subs_lev(0)+1,nclus
           write(99,*) clusrx(i),clusry(i),clusrz(i),msub(i),rsub(i),
     &               realclus(i)
          end do
          close(99)
         END IF

         CALL SUBSTRUCTURE_PARTICLES(IR,NL,NCLUS,MASA,RADIO,CLUSRX,
     &      CLUSRY,CLUSRZ,REALCLUS,CONCENTRA,ANGULARM,VMAXCLUS,IPLIP,VX,
     &      VY,VZ,VCMAX,MCMAX,RCMAX,M200C,M500C,M2500C,M200M,M500M,
     &      M2500M,MSUB,R200C,R500C,R2500C,R200M,R500M,R2500M,RSUB,
     &      DMPCLUS,LEVHAL,EIGENVAL,N_DM,RXPA,RYPA,RZPA,MASAP,U2DM,U3DM,
     &      U4DM,ORIPA,CONTRASTEC,OMEGAZ,UM,UV,LADO0,CLUSRXCM,CLUSRYCM,
     &      CLUSRZCM,MEAN_VR,INERTIA_TENSOR,SUBS_LEV,PATCHCLUS,NPATCH,
     &      PROFILES,VELOCITY_DISPERSION,KINETIC_E,POTENTIAL_E,
     &      DO_COMPUTE_ENERGIES,PARTICLES_PER_HALO,
     &      INDCS_PARTICLES_PER_HALO,FLAG_WDM,ZETA,MIN_NUM_PART,
     &      MAX_NUM_PART,NDMPART_X)

         IF (FW5.EQ.1) THEN
          open(99, file='./output_files/substructureparticles'//
     &        ITER_STRING//'.res', status='unknown',position='append')
          do i=subs_lev(0)+1,nclus
           write(99,*) clusrx(i),clusry(i),clusrz(i),msub(i),rsub(i),
     &              realclus(i)
          end do
          close(99)
         END IF
        END DO

        CALL FRACTION_MASS_SUBS(NCLUS,REALCLUS,MASA,MSUB,FSUB,NSUBS)
       END IF

****************************************************
****************************************************
****************************************************
       IF (FLAG_CENTRAL.EQ.1) THEN
       WRITE(*,*)
       WRITE(*,*) '***************************'
       WRITE(*,*) '**     CORE SEARCH       **'
       WRITE(*,*) '***************************'

       CALL CORE_SEARCH(NCLUS,MASA,RADIO,CLUSRX,CLUSRY,CLUSRZ,REALCLUS,
     &                  MSUB,RSUB,SUBS_LEV,DMPCLUS,RMAXSIGMA,RXPA,RYPA,
     &                  RZPA,MASAP,U2DM,U3DM,U4DM,N_DM,MMAXSIGMA,
     &                  MAX_NUM_PART)
       END IF

*************************************************
*************************************************
*===================Families===============
       KONTA2=COUNT(REALCLUS(1:NCLUS).NE.0)

       OPEN(3,FILE='./output_files/families'//ITER_STRING,
     &      STATUS='UNKNOWN')
       IF (FLAG_WDM.EQ.1) THEN
        OPEN(4,FILE='./output_files/particles'//ITER_STRING,
     &       FORM='UNFORMATTED')
        WRITE(4) KONTA2
       END IF

       WRITE(3,*) '*********************NEW ITER*******************'
       WRITE(3,*) ITER, NCLUS, KONTA2, ZETA
       WRITE(3,*) '************************************************'

111    FORMAT(51A14)
112    FORMAT(2I14,3F14.6,E14.6,F14.6,E14.6,F14.6,2I14,3F14.6,3F14.6,
     &        6E14.6,3E14.6,E14.6,3F14.3,2F14.3,2E14.6,F14.3,E14.3,
     &        F14.6,F14.6,E14.6,F14.6,E14.6,F14.6,E14.6,F14.6,E14.6,
     &        F14.6,E14.6,F14.6,E14.6,F14.6,I14)


       WRITE(3,*) '=====================================================
     &==================================================================
     &==================================================================
     &==================================================================
     &==================================================================
     &================================================================='

       WRITE(3,111) 'Halo ID'     ,'Substr. of'  ,'Density peak',
     &            'coordinates' ,'(Mpc)'       ,'Virial mass' ,
     &            'Virial radi' ,'Substr. mass','Substr. radi',
     &            'Part. num.'  ,'Most bound'  ,'Center of'   ,
     &            'mass coords' ,'(Mpc)'       ,'Semiaxes'    ,
     &            '(Mpc)'       ,''            ,'Inertia'     ,
     &            'tensor'      ,'components'  ,'(cMpc^2)'    ,
     &            ''            ,''            ,'Spec. angul.',
     &            'momentum'    ,'(cMpc km/s)' ,'Veloc. disp.',
     &            'Bulk velocty','(km/s)'      ,''            ,
     &            'Max part vel','Mean V_rad'  ,'Kinetic E'   ,
     &            'Potential E' ,'Vcmax'       ,'Mass@Vcmax'  ,
     &            'r@Vcmax'     ,'R200m (Mpc)' ,'M200m (Msun)',
     &            'R200c (Mpc)' ,'M200c (Msun)','R500m (Mpc)' ,
     &            'M500m (Msun)','R500c (Mpc)' ,'M500c (Msun)',
     &            'R2500m (Mpc)','M2500m(Msun)','R2500c (Mpc)',
     &            'M2500c(Msun)','f_sub'       ,'N_subs'

       WRITE(3,111) ''            ,''            ,'x'           ,
     &            'y'           ,'z'           ,'(Msun)'      ,
     &            '(Mpc)'       ,'(Msun)'      ,'(Mpc)'       ,
     &            ''            ,'particle ID' ,'x'           ,
     &            'y'           ,'z'           ,'Major'       ,
     &            'Intermediate','Minor'       ,'Ixx'         ,
     &            'Ixy'         ,'Ixz'         ,'Iyy'         ,
     &            'Iyz'         ,'Izz'         ,'Lx'          ,
     &            'Ly'          ,'Lz'          ,'(km/s)'      ,
     &            'Vx'          ,'Vy'          ,'Vz'          ,
     &            '(km/s)'      ,'(km/s)'      ,'Msun(km/s)^2',
     &            'Msun(km/s)^2','(km/s)'      ,'(Msun)'      ,
     &            '(Mpc)'       ,''            ,''            ,
     &            ''            ,''            ,''            ,
     &            ''            ,''            ,''            ,
     &            ''            ,''            ,''            ,
     &            ''            ,''            ,''

       WRITE(3,*) '=====================================================
     &==================================================================
     &==================================================================
     &==================================================================
     &==================================================================
     &================================================================='

       KONTA2=0
       DO I=1,NCLUS

       IF (REALCLUS(I).NE.0) THEN
         WRITE(3,112) I,REALCLUS(I),CLUSRX(I),CLUSRY(I),CLUSRZ(I),
     &              MASA(I),RADIO(I),MSUB(I),RSUB(I),DMPCLUS(I),
     &              IPLIP(I),CLUSRXCM(I),CLUSRYCM(I),CLUSRZCM(I),
     &              (EIGENVAL(J,I),J=1,3),(INERTIA_TENSOR(J,I),J=1,6),
     &              (ANGULARM(J,I),J=1,3),VELOCITY_DISPERSION(I),
     &              VX(I)*UV,VY(I)*UV,VZ(I)*UV,VMAXCLUS(I),MEAN_VR(I),
     &              KINETIC_E(I),POTENTIAL_E(I),
     &              VCMAX(I),MCMAX(I),RCMAX(I),
     &              R200M(I),M200M(I),R200C(I),M200C(I),
     &              R500M(I),M500M(I),R500C(I),M500C(I),
     &              R2500M(I),M2500M(I),R2500C(I),M2500C(I),
     &              FSUB(I),NSUBS(I)
         IF (FLAG_WDM.EQ.1) THEN
          WRITE(4) I,(INDCS_PARTICLES_PER_HALO(J,I),J=1,2)
          KONTA2=MAX(KONTA2,INDCS_PARTICLES_PER_HALO(2,I))
         END IF
       END IF  !realclus

       END DO

       IF (FLAG_WDM.EQ.1) THEN
        WRITE(4) KONTA2
        WRITE(4) (PARTICLES_PER_HALO(J),J=1,KONTA2)
       END IF

       CLOSE(3)
       IF (FLAG_WDM.EQ.1) CLOSE(4)

*==========================================
*************************************************
*************************************************

       WRITE(*,*)'END ITER', ITER
       CALL IDATE(DATE)
       CALL ITIME(TIME)
       WRITE(*,*) 'DATE=',DATE(1),'/',DATE(2),'/',DATE(3)
       WRITE(*,*) 'TIME=',TIME(1),':',TIME(2),':',TIME(3)

*      Si no se hace merger_tree hay que inicializar todo lo que depende de ITER!!

       END DO    !FIN DE ITER
*/////////////////////////////////////////

       END

**//////////////////////////////////////////////////////////////

***********************************************************************
*      SUBROUTINES IN EXTERNAL FILES                                  *
***********************************************************************
*      Grid building
       INCLUDE 'grids.f'
*      Routines from 'Numerical Recipes in Fortran90', Press, Teukoslky et al.
       INCLUDE 'nr.f'
*      Halo finding procedures using the grid
       INCLUDE 'haloes_grids.f'
*      Halo finding procedures using particles
       INCLUDE 'haloes_particles.f'
*      Substructure search
       INCLUDE 'substructure.f'
*      Read MASCLET outputs (can be changed for other code outputs)
       INCLUDE 'reader.f'
*      Solve Poisson's equation for the gravitational potential
*       generated by DM
c       INCLUDE 'poisson.f'
*      Merger tree routines
       !INCLUDE 'merger_tree.f'
