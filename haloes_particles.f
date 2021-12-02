**********************************************************************
       SUBROUTINE RE_SORT_HALOES(NCLUS,NHALLEV,REALCLUS,CLUSRX,CLUSRY,
     &                           CLUSRZ,RADIO,MASA,LEVHAL,PATCHCLUS,
     &                           DMPCLUS)
**********************************************************************
*      Resorts the clusters, getting rid of REALCLUS=0 ones
**********************************************************************
        IMPLICIT NONE
        INCLUDE 'input_files/asohf_parameters.dat'

        INTEGER NCLUS
        INTEGER NHALLEV(0:NLEVELS)
        INTEGER REALCLUS(MAXNCLUS)
        REAL*4 CLUSRX(MAXNCLUS),CLUSRY(MAXNCLUS),CLUSRZ(MAXNCLUS)
        REAL*4 MASA(MAXNCLUS), RADIO(MAXNCLUS)
        INTEGER LEVHAL(MAXNCLUS),PATCHCLUS(MAXNCLUS)
        INTEGER DMPCLUS(NMAXNCLUS)

        INTEGER I,J
        INTEGER,ALLOCATABLE::RESORT(:)

        NHALLEV(:)=0
        J=0
        ALLOCATE(RESORT(NCLUS))
        DO I=1,NCLUS
         IF (REALCLUS(I).EQ.0) CYCLE
         J=J+1
         RESORT(I)=J
         CLUSRX(J)=CLUSRX(I)
         CLUSRY(J)=CLUSRY(I)
         CLUSRZ(J)=CLUSRZ(I)
         RADIO(J)=RADIO(I)
         MASA(J)=MASA(I)
         LEVHAL(J)=LEVHAL(I)
         PATCHCLUS(J)=PATCHCLUS(I)
         DMPCLUS(J)=DMPCLUS(I)
         IF (REALCLUS(I).LE.0) THEN
          REALCLUS(J)=REALCLUS(I)
         ELSE
          REALCLUS(J)=RESORT(REALCLUS(I))
         END IF
         NHALLEV(LEVHAL(J))=NHALLEV(LEVHAL(J))+1
        END DO

        NCLUS=J
        DEALLOCATE(RESORT)

        RETURN
        END


**********************************************************************
        SUBROUTINE HALOES_BORDER(NCLUS,CLUSRX,CLUSRY,CLUSRZ,RADIO,
     &                           LADO0,HALBORDERS)
**********************************************************************
*       Identifies the haloes at the border of the box for special
*        treatment if necessary
**********************************************************************

        IMPLICIT NONE

        INCLUDE 'input_files/asohf_parameters.dat'

        INTEGER NCLUS
        REAL*4 CLUSRX(MAXNCLUS),CLUSRY(MAXNCLUS),CLUSRZ(MAXNCLUS)
        REAL*4 RADIO(MAXNCLUS)
        REAL LADO0
        INTEGER HALBORDERS(MAXNCLUS)

        INTEGER I
        REAL XL,XR,X1,X2,Y1,Y2,Z1,Z2,XC,YC,ZC,RC

        XL=-LADO0/2
        XR=LADO0/2

!$OMP PARALLEL DO SHARED(NCLUS,HALBORDERS),PRIVATE(I),DEFAULT(NONE)
        DO I=1,NCLUS
         HALBORDERS(I)=0
        END DO

!$OMP PARALLEL DO SHARED(NCLUS,RADIO,CLUSRX,CLUSRY,CLUSRZ,XL,XR,
!$OMP+                   HALBORDERS),
!$OMP+            PRIVATE(I,RC,XC,YC,ZC,X1,X2,Y1,Y2,Z1,Z2),
!$OMP+            DEFAULT(NONE)
        DO I=1,NCLUS
         RC=RADIO(I)
         XC=CLUSRX(I)
         YC=CLUSRY(I)
         ZC=CLUSRZ(I)
         X1=XC-1.25*RC
         X2=XC+1.25*RC
         Y1=YC-1.25*RC
         Y2=YC+1.25*RC
         Z1=ZC-1.25*RC
         Z2=ZC+1.25*RC
         IF (X1.LT.XL.OR.X2.GT.XR.OR.
     &       Y1.LT.XL.OR.Y2.GT.XR.OR.
     &       Z1.LT.XL.OR.Z2.GT.XR) THEN
          HALBORDERS(I)=1
         END IF
        END DO

        RETURN
        END


**********************************************************************
        SUBROUTINE COUNT_PARTICLES_HALO(RXPA,RYPA,RZPA,N_DM,
     &                                  CMX,CMY,CMZ,R,NUM_PART_HAL)
**********************************************************************
*       Counts number of particles inside a halo
**********************************************************************
         IMPLICIT NONE
         INCLUDE 'input_files/asohf_parameters.dat'

         REAL*4 RXPA(PARTIRED),RYPA(PARTIRED),RZPA(PARTIRED)
         INTEGER N_DM
         REAL CMX,CMY,CMZ,R
         INTEGER NUM_PART_HAL

         INTEGER I
         REAL BASR,R2

         NUM_PART_HAL=0
         R2=R**2

         DO I=1,N_DM
          BASR=(RXPA(I)-CMX)**2 + (RYPA(I)-CMY)**2 + (RZPA(I)-CMZ)**2
          IF (BASR.LT.R2) NUM_PART_HAL=NUM_PART_HAL+1
         END DO

         RETURN
         END

**********************************************************************
       SUBROUTINE PRUNE_POOR_HALOES(NCLUS,CLUSRX,CLUSRY,CLUSRZ,RADIO,
     &                              REALCLUS,RXPA,RYPA,RZPA,N_DM,
     &                              NUMPARTBAS,DMPCLUS,FACRAD)
**********************************************************************
*       Removes haloes with too few particles
**********************************************************************

        IMPLICIT NONE
        INCLUDE 'input_files/asohf_parameters.dat'

        INTEGER NCLUS
        REAL*4 CLUSRX(MAXNCLUS),CLUSRY(MAXNCLUS),CLUSRZ(MAXNCLUS)
        REAL*4 RADIO(MAXNCLUS)
        INTEGER REALCLUS(MAXNCLUS)
        REAL*4 RXPA(PARTIRED),RYPA(PARTIRED),RZPA(PARTIRED)
        INTEGER N_DM,NUMPARTBAS
        INTEGER DMPCLUS(NMAXNCLUS)
        REAL FACRAD

        INTEGER I,BASINT,KONTA2
        REAL CMX,CMY,CMZ,RR

        KONTA2=0

!$OMP PARALLEL DO SHARED(NCLUS,CLUSRX,CLUSRY,CLUSRZ,RADIO,N_DM,
!$OMP+                   NUMPARTBAS,REALCLUS,RXPA,RYPA,RZPA,FACRAD,
!$OMP+                   DMPCLUS),
!$OMP+            PRIVATE(I,CMX,CMY,CMZ,RR,BASINT),
!$OMP+            REDUCTION(+:KONTA2)
!$OMP+            DEFAULT(NONE)
*****************************
        DO I=1,NCLUS
****************************
         CMX=CLUSRX(I)
         CMY=CLUSRY(I)
         CMZ=CLUSRZ(I)
         RR=FACRAD*RADIO(I)

         CALL COUNT_PARTICLES_HALO(RXPA,RYPA,RZPA,N_DM,CMX,CMY,CMZ,RR,
     &                             BASINT)

         IF (BASINT.LT.NUMPARTBAS) THEN
          REALCLUS(I)=0
          KONTA2=KONTA2+1
          !WRITE(*,*) I,BASINT,RR
         END IF

         DMPCLUS(I)=BASINT

*****************************
        END DO        !I
*****************************

        WRITE(*,*)'CHECKING POOR HALOS----->', KONTA2

        RETURN
        END

**********************************************************************
        SUBROUTINE RECENTER_DENSITY_PEAK_PARTICLES(CX,CY,CZ,R,RXPA,RYPA,
     &                                             RZPA,MASAP,N_DM,
     &                                             DXPAMIN)
**********************************************************************
*       Recenters density peak using particles
**********************************************************************
        IMPLICIT NONE
        INCLUDE 'input_files/asohf_parameters.dat'

        REAL CX,CY,CZ,R
        REAL*4 RXPA(PARTIRED),RYPA(PARTIRED),RZPA(PARTIRED),
     &         MASAP(PARTIRED),DXPAMIN
        INTEGER N_DM

        INTEGER LIP(PARTIRED),KONTA,FLAG_LARGER,I,NN,IX,JY,KZ,IP
        INTEGER INMAX(3),KONTA2,FLAG_ITER,NUMPARTMIN
        REAL RADIO,BAS,XL,YL,ZL,DDXX
        REAL,ALLOCATABLE::DENS(:,:,:)

        NUMPARTMIN=32 !4**3/2

c        WRITE(*,*) CX,CY,CZ

        FLAG_LARGER=1
        RADIO=MAX(0.05*R,DXPAMIN)
        DO WHILE(FLAG_LARGER.EQ.1)
         KONTA=0
         DO I=1,N_DM
          IF (CX-RADIO.LT.RXPA(I).AND.RXPA(I).LT.CX+RADIO.AND.
     &        CY-RADIO.LT.RYPA(I).AND.RYPA(I).LT.CY+RADIO.AND.
     &        CZ-RADIO.LT.RZPA(I).AND.RZPA(I).LT.CZ+RADIO) THEN
           KONTA=KONTA+1
           LIP(KONTA)=I
          END IF
         END DO
         IF (KONTA.GT.NUMPARTMIN) THEN
          FLAG_LARGER=0
         ELSE
          RADIO=RADIO*1.2
         END IF
        END DO

c        WRITE(*,*) RADIO,KONTA,CX,CY,CZ
        NN=4

        ALLOCATE(DENS(NN,NN,NN))
        DDXX=2.0*RADIO/FLOAT(NN)
        XL=CX-RADIO
        YL=CY-RADIO
        ZL=CZ-RADIO
        FLAG_ITER=1
        DO WHILE (FLAG_ITER.EQ.1)
         DO KZ=1,NN
         DO JY=1,NN
         DO IX=1,NN
          DENS(IX,JY,KZ)=0.0
         END DO
         END DO
         END DO

         DO I=1,KONTA
          IP=LIP(I)
          IX=INT((RXPA(IP)-XL)/DDXX)+1
          JY=INT((RYPA(IP)-YL)/DDXX)+1
          KZ=INT((RZPA(IP)-ZL)/DDXX)+1
          !IF (JY.EQ.0) WRITE(*,*) (RYPA(IP)-YL)/DDXX
          DENS(IX,JY,KZ)=DENS(IX,JY,KZ)+MASAP(IP)
         END DO

         INMAX=MAXLOC(DENS)
         IX=INMAX(1)
         JY=INMAX(2)
         KZ=INMAX(3)
         CX=XL+(IX-0.5)*DDXX
         CY=YL+(JY-0.5)*DDXX
         CZ=ZL+(KZ-0.5)*DDXX
         RADIO=RADIO/2.0
         XL=CX-RADIO
         YL=CY-RADIO
         ZL=CZ-RADIO
         DDXX=DDXX/2.0

         KONTA2=0
         DO I=1,KONTA
          IP=LIP(I)
          IF (CX-RADIO.LT.RXPA(IP).AND.RXPA(IP).LT.CX+RADIO.AND.
     &        CY-RADIO.LT.RYPA(IP).AND.RYPA(IP).LT.CY+RADIO.AND.
     &        CZ-RADIO.LT.RZPA(IP).AND.RZPA(IP).LT.CZ+RADIO) THEN
           KONTA2=KONTA2+1
           LIP(KONTA2)=IP
          END IF
         END DO

         KONTA=KONTA2

         IF (KONTA2.LT.NUMPARTMIN) FLAG_ITER=0

c         WRITE(*,*) RADIO,KONTA2,CX,CY,CZ,DENS(IX,JY,KZ)/DDXX**3,
c     &              IX,JY,KZ,FLAG_ITER
        END DO

        DEALLOCATE(DENS)

        RETURN
        END


**********************************************************************
       SUBROUTINE HALOFIND_PARTICLES(NL,NCLUS,MASA,RADIO,CLUSRX,CLUSRY,
     &      CLUSRZ,REALCLUS,CONCENTRA,ANGULARM,VMAXCLUS,IPLIP,VX,VY,VZ,
     &      VCMAX,MCMAX,RCMAX,M200C,M500C,M2500C,M200M,M500M,M2500M,
     &      MSUB,R200C,R500C,R2500C,R200M,R500M,R2500M,RSUB,DMPCLUS,
     &      LEVHAL,EIGENVAL,N_DM,RXPA,RYPA,RZPA,MASAP,U2DM,U3DM,U4DM,
     &      ORIPA2,CONTRASTEC,OMEGAZ,UM,UV,LADO0,CLUSRXCM,CLUSRYCM,
     &      CLUSRZCM,MEAN_VR,INERTIA_TENSOR)
**********************************************************************
*      Refines halo identification with DM particles
**********************************************************************
       IMPLICIT NONE
       INCLUDE 'input_files/asohf_parameters.dat'

       INTEGER NL,NCLUS
       REAL*4 MASA(MAXNCLUS),RADIO(MAXNCLUS)
       REAL*4 CLUSRX(MAXNCLUS),CLUSRY(MAXNCLUS),CLUSRZ(MAXNCLUS)
       INTEGER REALCLUS(MAXNCLUS)
       REAL*4 CONCENTRA(NMAXNCLUS),ANGULARM(3,NMAXNCLUS)
       REAL*4 VMAXCLUS(NMAXNCLUS)
       INTEGER IPLIP(NMAXNCLUS)
       REAL*4 VX(NMAXNCLUS),VY(NMAXNCLUS),VZ(NMAXNCLUS)
       REAL*4 VCMAX(NMAXNCLUS),MCMAX(NMAXNCLUS),RCMAX(NMAXNCLUS)
       REAL*4 M200C(NMAXNCLUS),R200C(NMAXNCLUS)
       REAL*4 M500C(NMAXNCLUS),R500C(NMAXNCLUS)
       REAL*4 M2500C(NMAXNCLUS),R2500C(NMAXNCLUS)
       REAL*4 M200M(NMAXNCLUS),R200M(NMAXNCLUS)
       REAL*4 M500M(NMAXNCLUS),R500M(NMAXNCLUS)
       REAL*4 M2500M(NMAXNCLUS),R2500M(NMAXNCLUS)
       REAL*4 MSUB(NMAXNCLUS),RSUB(NMAXNCLUS)
       INTEGER DMPCLUS(NMAXNCLUS),LEVHAL(MAXNCLUS)
       REAL*4 EIGENVAL(3,NMAXNCLUS)
       INTEGER N_DM
       REAL*4 RXPA(PARTIRED),RYPA(PARTIRED),RZPA(PARTIRED)
       REAL*4 U2DM(PARTIRED),U3DM(PARTIRED),U4DM(PARTIRED)
       REAL*4 MASAP(PARTIRED)
       INTEGER ORIPA2(PARTIRED)
       REAL*4 CONTRASTEC,OMEGAZ,UM,UV,LADO0
       REAL*4 CLUSRXCM(MAXNCLUS),CLUSRYCM(MAXNCLUS),CLUSRZCM(MAXNCLUS)
       REAL*4 MEAN_VR(NMAXNCLUS),INERTIA_TENSOR(6,NMAXNCLUS)

       REAL*4 PI,ACHE,T0,RE0,PI4ROD
       COMMON /DOS/ACHE,T0,RE0
       REAL*4 UNTERCIO,CGR,CGR2,ZI,RODO,ROI,REI
       COMMON /CONS/PI4ROD,REI,CGR,PI
       REAL*4 OMEGA0

       REAL*4 RETE,HTE,ROTE
       COMMON /BACK/ RETE,HTE,ROTE

       REAL*4 DX,DY,DZ
       COMMON /ESPACIADO/ DX,DY,DZ

*      Local variables
       INTEGER DIMEN,KONTA1,KONTA2,I,PABAS,NUMPARTBAS,KK_ENTERO,NROT,II
       INTEGER KONTA,IR,J,CONTAERR,JJ,SALIDA,KONTA3,NSHELL_2,KONTA2PREV
       INTEGER IX,JY,KK1,KK2,FAC,ITER_SHRINK,COUNT_1,COUNT_2,JJCORE
       INTEGER FLAG200C,FLAG500C,FLAG2500C,FLAG200M,FLAG500M,FLAG2500M
       INTEGER FLAGVIR,JMINPROF
       INTEGER NCAPAS(NMAXNCLUS)
       INTEGER LIP(PARTIRED),CONTADM(PARTIRED)
       REAL ESP,REF,REF_MIN,REF_MAX,MASADM,BASMAS,DIS,VCM,MINOVERDENS
       REAL VVV2,VR,CONCEN,RS,BAS,AADM,CMX,CMY,CMZ,VCMX,VCMY,CX,CY,CZ
       REAL VCMZ,MASA2,NORMA,BAS1,BAS2,VOL,DELTA2,RSHELL,RCLUS,BASVEC(3)
       REAL DENSA,DENSB,DENSC,VKK,AA,BASX,BASY,BASZ,XP,YP,ZP,MP
       REAL INERTIA(3,3),BASEIGENVAL(3),RADII_ITER(7),BASVECCM(3)
       REAL BASVCM(3)
       REAL DENSITOT(0:1000),RADIAL(0:1000),DENSR(0:1000)
       REAL LOGDERIV(0:1000)
       REAL DISTA(0:PARTIRED)

       PI=DACOS(-1.D0)

       DIMEN=3   !DIMENSION DE LOS HALOS
       NCAPAS=0
       ESP=0.0
       REF=0.0
       KONTA1=0
       KONTA2=0

       MINOVERDENS=200.0

       DO I=0,NL
       WRITE(*,*)'Halos at level ', I,' =',
     &            COUNT(LEVHAL(1:NCLUS).EQ.I),
     &            COUNT(REALCLUS(1:NCLUS).NE.0.AND.
     &                       LEVHAL(1:NCLUS).EQ.I)
       END DO
       WRITE(*,*)'=================================='

       WRITE(*,*) 'Max num. of part. in a halo=',
     &            MAXVAL(DMPCLUS(1:NCLUS))
       KONTA1=100000000
       DO I=1,NCLUS
        IF (REALCLUS(I).NE.0) KONTA1=MIN(KONTA1,DMPCLUS(I))
       END DO
       WRITE(*,*) 'Min num. of part. in a halo=',KONTA1
       WRITE(*,*) 'NCLUS=', NCLUS

       PABAS=PARTIRED_PLOT
       NUMPARTBAS=NUMPART
       NORMA=MAXVAL(MASAP)

!$OMP  PARALLEL DO SHARED(NCLUS,REALCLUS,
!$OMP+           LEVHAL,RXPA,RYPA,RZPA,CLUSRX,CLUSRY,CLUSRZ,NL,MASAP,
!$OMP+           U2DM,U3DM,U4DM,VX,VY,VZ,ACHE,PI,RETE,ROTE,VCMAX,
!$OMP+           MCMAX,RCMAX,CONTRASTEC,OMEGAZ,CGR,UM,UV,DMPCLUS,
!$OMP+           CONCENTRA,ORIPA2,ANGULARM,PABAS,IPLIP,DIMEN,EIGENVAL,
!$OMP+           NUMPARTBAS,RADIO,MASA,VMAXCLUS,N_DM,NORMA,R200M,
!$OMP+           R500M,R2500M,R200C,R500C,R2500C,M200M,M500M,M2500M,
!$OMP+           M200C,M500C,M2500C,RSUB,MSUB,MINOVERDENS,CLUSRXCM,
!$OMP+           CLUSRYCM,CLUSRZCM,DX,MEAN_VR,INERTIA_TENSOR),
!$OMP+   PRIVATE(I,INERTIA,REF_MIN,REF_MAX,KK_ENTERO,MASADM,KONTA,
!$OMP+           BASMAS,DIS,VCM,VVV2,VR,LIP,CONCEN,RS,KONTA2,BAS,IR,J,
!$OMP+           AADM,KK1,KK2,CONTADM,CMX,CMY,CMZ,VCMX,VCMY,VCMZ,MASA2,
!$OMP+           DISTA,FAC,CONTAERR,JJ,DENSITOT,RADIAL,SALIDA,BAS1,BAS2,
!$OMP+           VOL,DELTA2,NCAPAS,RSHELL,KONTA3,NSHELL_2,KONTA1,
!$OMP+           DENSA,DENSB,DENSC,BASVEC,BASVECCM,VKK,AA,NROT,
!$OMP+           BASEIGENVAL,BASX,BASY,BASZ,XP,YP,ZP,MP,RCLUS,COUNT_1,
!$OMP+           COUNT_2,KONTA2PREV,FLAG200C,FLAG200M,FLAG500C,FLAG500M,
!$OMP+           FLAG2500C,FLAG2500M,FLAGVIR,JMINPROF,DENSR,LOGDERIV,
!$OMP+           CX,CY,CZ,JJCORE,RADII_ITER,BASVCM),
!$OMP+   SCHEDULE(DYNAMIC,2), DEFAULT(NONE)
*****************************
       DO I=1,NCLUS
****************************
       KK_ENTERO=REALCLUS(I)
       IF (KK_ENTERO.NE.0) THEN

        INERTIA=0.0
        REF_MIN=10.0e+10
        REF_MAX=-1.0
        MASADM=0.0
        KONTA=0
        BASMAS=0.0
        DIS=1.0E+10    !Distance (to the center) of the most central particle
        VCM=0.0
        VVV2=0.0    ! v propia de las particulas respecto al CM
        VR=0.0      ! v radial
        CMX=0.0
        CMY=0.0
        CMZ=0.0
        CX=0.0
        CY=0.0
        CZ=0.0
        VCMX=0.0
        VCMY=0.0
        VCMZ=0.0
        LIP=0
        CONCEN=0.0       !concentration NFW profile
        RS=0.0           !scale radius NFW profile
        KONTA2=0
        BASX=0.0
        BASY=0.0
        BASZ=0.0

*********************************************************************
*       RECENTERING AND COMPUTING VCM OF HALO I (SHRINKING SPHERE)
*********************************************************************

        CX=CLUSRX(I)
        CY=CLUSRY(I)
        CZ=CLUSRZ(I)
        BAS=RADIO(I)
        ! Find level used for recentering
        CALL RECENTER_DENSITY_PEAK_PARTICLES(CX,CY,CZ,BAS,RXPA,RYPA,
     &                                       RZPA,MASAP,N_DM,DX/2.0**NL)

        BAS=(CLUSRX(I)-CX)**2+(CLUSRY(I)-CY)**2+(CLUSRZ(I)-CZ)**2
        BAS=SQRT(BAS)
c        WRITE(*,*) 'Recentering shift', i, bas, bas/radio(i)

        CLUSRX(I)=CX
        CLUSRY(I)=CY
        CLUSRZ(I)=CZ

        DELTA2=100.0*MINOVERDENS ! just to ensure it enters the loop
        RCLUS=RADIO(I)
        DO WHILE (DELTA2.GT.0.9*MINOVERDENS)
         KONTA=0
         MASADM=0.0

         DO J=1,N_DM
          XP=RXPA(J)
          YP=RYPA(J)
          ZP=RZPA(J)
          MP=MASAP(J)
          AADM=SQRT((XP-CX)**2+(YP-CY)**2+(ZP-CZ)**2)
          IF(AADM.LT.RCLUS) THEN
           KONTA=KONTA+1
           LIP(KONTA)=J
           MASADM=MASADM+MP
          END IF
         END DO

         DELTA2=MASADM/(ROTE*RETE**3*(4*PI/3)*RCLUS**3)

         IF (DELTA2.GT.0.9*MINOVERDENS) RCLUS=1.05*RCLUS
        END DO
c        WRITE(*,*) DELTA2,MASADM*UM,RCLUS,KONTA

        IF (MASADM.LE.0.0.OR.KONTA.EQ.0) THEN
         REALCLUS(I)=0
         CYCLE
        END IF

        CONTADM(1:KONTA)=0     !en principio todas estas ligadas
        CALL CENTROMASAS_PART(KONTA,CONTADM,LIP,U2DM,U3DM,U4DM,MASAP,
     &                        RXPA,RYPA,RZPA,CMX,CMY,CMZ,VCMX,VCMY,VCMZ,
     &                        MASA2)

        VCM=SQRT(VCMX**2+VCMY**2+VCMZ**2)

        CLUSRXCM(I)=CMX
        CLUSRYCM(I)=CMY
        CLUSRZCM(I)=CMZ
        VX(I)=VCMX
        VY(I)=VCMY
        VZ(I)=VCMZ
        RADIO(I)=RCLUS
        MASA(I)=MASADM*UM
        DMPCLUS(I)=KONTA
c        WRITE(*,*) '*',sqrt((cmx-cx)**2+(cmy-cy)**2+(cmz-cz)**2)
c        write(*,*) '**',vcmx,vcmy,vcmz,vcm

*********************************************************************
*       END RECENTERING AND COMPUTING VCM OF HALO I (SHRINKING SPHERE)
*********************************************************************

********************************************************************
*      UNBINDING:SCAPE VELOCITY
********************************************************************

        CONTAERR=KONTA
        DISTA=0.0
        KONTA2=0
        CALL REORDENAR(KONTA,CX,CY,CZ,RXPA,RYPA,RZPA,CONTADM,LIP,
     &                 DISTA,KONTA2,1)
        REF_MAX=DISTA(KONTA2)
        REF_MIN=DISTA(1)

        FAC=0
        DO WHILE (CONTAERR.GT.0.OR.FAC.LT.3)
         FAC=FAC+1
         KONTA2PREV=KONTA2
         CALL UNBINDING8(FAC,I,REF_MIN,REF_MAX,DISTA,U2DM,U3DM,U4DM,
     &                   MASAP,RXPA,RYPA,RZPA,RADIO,MASA,CLUSRXCM,
     &                   CLUSRYCM,CLUSRZCM,LIP,KONTA,CONTADM,VX,VY,VZ,
     &                   REALCLUS,KONTA2)
         CALL REORDENAR(KONTA,CX,CY,CZ,RXPA,RYPA,RZPA,CONTADM,LIP,
     &                  DISTA,KONTA2,0)
         REF_MAX=DISTA(KONTA2)
         REF_MIN=DISTA(1)
         CONTAERR=KONTA2PREV-KONTA2
        END DO

        count_1=konta-konta2
        count_2=konta2 !backup
c        write(*,*) 'Unbinding V_ESC',i,'. ',konta,'-->',konta2,
c     &             '. Pruned:',count_1,'. Iters:', FAC

********************************************************************
*      UNBINDING: PHASE SPACE
********************************************************************

        FAC=0
        CONTAERR=KONTA2
        DO WHILE (CONTAERR.GT.0.OR.FAC.LT.4)
         FAC=FAC+1
         KONTA2PREV=KONTA2
         CALL UNBINDING_SIGMA(FAC,I,REF_MIN,REF_MAX,U2DM,U3DM,U4DM,RXPA,
     &                        RYPA,RZPA,MASAP,RADIO,MASA,CLUSRXCM,
     &                        CLUSRYCM,CLUSRZCM,LIP,KONTA,CONTADM,VX,
     &                        VY,VZ,REALCLUS,KONTA2)
         CALL REORDENAR(KONTA,CX,CY,CZ,RXPA,RYPA,RZPA,CONTADM,LIP,
     &                  DISTA,KONTA2,0)
         REF_MAX=DISTA(KONTA2)
         REF_MIN=DISTA(1)
         CONTAERR=KONTA2PREV-KONTA2
         !write(*,*) 'sigma unbinding: iter,unbound',fac,contaerr
        END DO

        count_2=count_2-konta2
c        write(*,*) 'Unbinding SIGMA',i,'. ',konta,'-->',konta2,
c     &             '. Pruned:',count_2,'. Iters:', FAC
c        write(*,*) '--'

********************************************************************
*      DISCARD POOR HALOES
********************************************************************
        IF (KONTA2.LT.NUMPARTBAS) THEN
         REALCLUS(I)=0
        ELSE
**************************************************************
*      DENSITY PROFILE
**************************************************************
         REF_MIN=DISTA(1)
         REF_MAX=DISTA(KONTA2) ! DISTANCE TO THE FURTHERST BOUND PARTICLE
         JJ=0
         DENSITOT=0.0
         RADIAL=0.0
****************** stopping condition
         SALIDA=0
******************
         BAS=0.0 ! to store cummulative mass profile
         BAS1=-1.0 ! to store vcmax
         BAS2=0.0 ! to store vc(r)
*        VCMAX=-1.0
         ! Initialise flags (whether each overdensity has been found)
         FLAG200C=0
         FLAG500C=0
         FLAG2500C=0
         FLAG200M=0
         FLAG500M=0
         FLAG2500M=0
         FLAGVIR=0

         FAC=MAX(100,INT(0.05*KONTA2))
         KONTA3=INT(REAL(KONTA2)/FAC)*FAC
         NSHELL_2=0
         JJCORE=INT(MAX(10.0,KONTA2/100.0))
         DO J=1,JJCORE
          BAS=BAS+(MASAP(LIP(J))/NORMA)
         END DO
         DO J=JJCORE+1,KONTA2      !!!!! DEJO 80 por ciento de BINS DE SEGURIDAD
          VOL=PI*(4.0/3.0)*(DISTA(J)*RETE)**3
          BAS=BAS+(MASAP(LIP(J))/NORMA)

          DELTA2=NORMA*BAS/VOL/ROTE ! overdensity

          BAS2=BAS/DISTA(J) ! vc(r)
          IF (BAS2.GT.BAS1) THEN
           VCMAX(I)=BAS2
           MCMAX(I)=BAS
           RCMAX(I)=DISTA(J)
           BAS1=BAS2
          END IF

          IF (FLAG2500C.EQ.0) THEN
           IF (DELTA2.LE.2500.0/OMEGAZ) THEN
            M2500C(I)=DELTA2*VOL*ROTE*UM
            R2500C(I)=DISTA(J)
            FLAG2500C=1
            IF (J.EQ.JJCORE+1) THEN
             M2500C(I)=-1.0
             R2500C(I)=-1.0
            END IF
           END IF
          END IF

          IF (FLAG500C.EQ.0) THEN
           IF (DELTA2.LE.500.0/OMEGAZ) THEN
            M500C(I)=DELTA2*VOL*ROTE*UM
            R500C(I)=DISTA(J)
            FLAG500C=1
            IF (J.EQ.JJCORE+1) THEN
             M500C(I)=-1.0
             R500C(I)=-1.0
            END IF
           END IF
          END IF

          IF (FLAG200C.EQ.0) THEN
           IF (DELTA2.LE.200.0/OMEGAZ) THEN
            M200C(I)=DELTA2*VOL*ROTE*UM
            R200C(I)=DISTA(J)
            FLAG200C=1
            IF (J.EQ.JJCORE+1) THEN
             M200C(I)=-1.0
             R200C(I)=-1.0
            END IF
           END IF
          END IF

          IF (FLAG2500M.EQ.0) THEN
           IF (DELTA2.LE.2500.0) THEN
            M2500M(I)=DELTA2*VOL*ROTE*UM
            R2500M(I)=DISTA(J)
            FLAG2500M=1
            IF (J.EQ.JJCORE+1) THEN
             M2500M(I)=-1.0
             R2500M(I)=-1.0
            END IF
           END IF
          END IF

          IF (FLAG500M.EQ.0) THEN
           IF (DELTA2.LE.500.0) THEN
            M500M(I)=DELTA2*VOL*ROTE*UM
            R500M(I)=DISTA(J)
            FLAG500M=1
            IF (J.EQ.JJCORE+1) THEN
             M500M(I)=-1.0
             R500M(I)=-1.0
            END IF
           END IF
          END IF

          IF (FLAG200M.EQ.0) THEN
           IF (DELTA2.LE.200.0) THEN
            M200M(I)=DELTA2*VOL*ROTE*UM
            R200M(I)=DISTA(J)
            FLAG200M=1
            IF (J.EQ.JJCORE+1) THEN
             M200M(I)=-1.0
             R200M(I)=-1.0
            END IF
           END IF
          END IF

          ! STOPPING CONDITIONS
          ! 1. Below virial overdensity
          IF (FLAGVIR.EQ.0) THEN
           IF (DELTA2.LE.CONTRASTEC.AND.J.GT.INT(0.1*KONTA2)) THEN
            SALIDA=1 ! this means we've found the virial radius
                     ! but we don't exit straightaway because we still
                     ! want to find 200m
            FLAGVIR=1
            MASA(I)=DELTA2*VOL*ROTE*UM
            RADIO(I)=DISTA(J)

            NCAPAS(I)=J
            IF (J.EQ.KONTA2) THEN
             RSHELL=DISTA(J)
            ELSE
             RSHELL=DISTA(J+1)
            END IF

           END IF
          END IF

          ! profile
          IF (MOD(J,FAC).EQ.0) THEN
           NSHELL_2=NSHELL_2+1
           DENSITOT(NSHELL_2)=NORMA*BAS*UM
           RADIAL(NSHELL_2)=DISTA(J)
          END IF

          IF (SALIDA.EQ.1.AND.FLAG200M.EQ.1) EXIT
         END DO ! J=1,KONTA2

         !WRITE(*,*) RADIAL(1:NSHELL_2)
         !WRITE(*,*) DENSITOT(1:NSHELL_2)

         IF (MOD(J,FAC).NE.0) THEN
          NSHELL_2=NSHELL_2+1
          DENSITOT(NSHELL_2)=NORMA*BAS*UM
          RADIAL(NSHELL_2)=DISTA(J)
         END IF

c         WRITE(*,*) 'HALO I,KONTA2,NSHELL_2,KK_ENTERO=',
c     &               I,KONTA2,NSHELL_2,KK_ENTERO
c         WRITE(*,*) CLUSRX(I),CLUSRY(I),CLUSRZ(I)
c         WRITE(*,*) R2500C(I),R500C(I),R200C(I),R2500M(I),R500M(I),
c     &              R200M(I),RADIO(I)
c         WRITE(*,*) M2500C(I),M500C(I),M200C(I),M2500M(I),M500M(I),
c     &              M200M(I),MASA(I)
c         WRITE(*,*) '---'

         BAS=VCMAX(I)*NORMA*CGR/RETE
         VCMAX(I)=SQRT(BAS)*UV
         MCMAX(I)=MCMAX(I)*NORMA*UM
         RCMAX(I)=RCMAX(I)   !*RETE

         IF (KK_ENTERO.EQ.-1.AND.SALIDA.NE.1) THEN
          WRITE(*,*) 'PROBLEM WITH HALO',I,DELTA2,CMX,CMY,CMZ,
     &               NSHELL_2,RADIAL(NSHELL_2)
         END IF

***********************************************************
*      GUARDAMOS LAS PARTICULAS LIGADAS  DEL HALO I
***********************************************************
         KONTA=KONTA2
         KONTA2=0
         BASMAS=0.0
         DMPCLUS(I)=0

         VCMX=VX(I)
         VCMY=VY(I)
         VCMZ=VZ(I)

         BASX=0.0
         BASY=0.0
         BASZ=0.0
         INERTIA=0.0

         DIS=1000000.0
         VMAXCLUS(I)=-1.0
         DO J=1,KONTA
          IF (CONTADM(J).EQ.0) THEN
           JJ=LIP(J)
           BASVEC(1)=RXPA(JJ)-CX
           BASVEC(2)=RYPA(JJ)-CY
           BASVEC(3)=RZPA(JJ)-CZ
           AADM=SQRT(BASVEC(1)**2+BASVEC(2)**2+BASVEC(3)**2)
           IF (AADM.LE.RSHELL) THEN
            KONTA2=KONTA2+1
            BASMAS=BASMAS+(MASAP(JJ)/NORMA)

            BASVECCM(1)=RXPA(JJ)-CMX
            BASVECCM(2)=RYPA(JJ)-CMY
            BASVECCM(3)=RZPA(JJ)-CMZ

            BASVCM(1)=U2DM(JJ)-VCMX
            BASVCM(2)=U3DM(JJ)-VCMY
            BASVCM(3)=U4DM(JJ)-VCMZ

            VVV2=BASVCM(1)**2+BASVCM(2)**2+BASVCM(3)**2

**          ANGULAR MOMENTUM
            BASX=BASX+MASAP(JJ)*(BASVECCM(2)*BASVCM(3)
     &                          -BASVECCM(3)*BASVCM(2))
            BASY=BASY+MASAP(JJ)*(BASVECCM(3)*BASVCM(1)
     &                          -BASVECCM(1)*BASVCM(3))
            BASZ=BASZ+MASAP(JJ)*(BASVECCM(1)*BASVCM(2)
     &                          -BASVECCM(2)*BASVCM(1))

**          INERTIA TENSOR
            DO JY=1,3
            DO IX=1,3
              INERTIA(IX,JY)=INERTIA(IX,JY)
     &                       +MASAP(JJ)*BASVECCM(IX)*BASVECCM(JY)
            END DO
            END DO

**        VELOCITY OF THE FASTEST PARTICLE IN THE HALO
            VKK=0.0
            VKK=SQRT(U2DM(JJ)**2+U3DM(JJ)**2+U4DM(J)**2)

            IF (VKK.GT.VMAXCLUS(I)) THEN
             VMAXCLUS(I)=VKK
            END IF

**        CLOSEST PARTICLE TO THE CENTER OF THE HALO
            IF (AADM.LT.DIS) THEN
             DIS=AADM
             IPLIP(I)=ORIPA2(JJ)
            END IF

            IF(AADM.NE.0.0) THEN
             AA=(BASVEC(1)/AADM)*BASVCM(1)+
     &          (BASVEC(2)/AADM)*BASVCM(2)+
     &          (BASVEC(3)/AADM)*BASVCM(3)
             VR=VR+AA*MASAP(JJ)
            END IF
           END IF    !AADM.LT.RSHELL
          END IF     !CONTADM
         END DO      !KONTA

*******************************************************
*      SAVING MASSES, RADII, PROFILES AND SHAPES...
*******************************************************
         DMPCLUS(I)=KONTA2
         IF (KONTA2.LT.NUMPARTBAS) REALCLUS(I)=0
         MASA(I)=BASMAS*NORMA*UM
         RADIO(I)=RSHELL
         ANGULARM(1,I)=BASX*UV / (BASMAS*NORMA)
         ANGULARM(2,I)=BASY*UV / (BASMAS*NORMA)
         ANGULARM(3,I)=BASZ*UV / (BASMAS*NORMA)
         MEAN_VR(I)=VR/(BASMAS*NORMA)

         INERTIA(1:3,1:3)=INERTIA(1:3,1:3)/(BASMAS*NORMA)
         INERTIA_TENSOR(1,I)=INERTIA(1,1)
         INERTIA_TENSOR(2,I)=INERTIA(1,2)
         INERTIA_TENSOR(3,I)=INERTIA(1,3)
         INERTIA_TENSOR(4,I)=INERTIA(2,2)
         INERTIA_TENSOR(5,I)=INERTIA(2,3)
         INERTIA_TENSOR(6,I)=INERTIA(3,3)

         BASEIGENVAL(1:3)=0.0
         IF (DMPCLUS(I).GE.NUMPARTBAS) THEN
          CALL JACOBI(INERTIA,DIMEN,BASEIGENVAL,NROT)
          CALL SORT(BASEIGENVAL,DIMEN,DIMEN)
         END IF

         DO II=1,DIMEN
          EIGENVAL(II,I)=BASEIGENVAL(II)
          EIGENVAL(II,I)=SQRT(EIGENVAL(II,I))
         END DO

C         WRITE(*,*)
C         WRITE(*,*)I,CLUSRX(I),CLUSRY(I),CLUSRZ(I),
C     &         MASA(I),RADIO(I),DMPCLUS(I),
C     &         REALCLUS(I), LEVHAL(I),(INERTIA_TENSOR(IX,I),IX=1,6),
C     &         EIGENVAL(1,I),EIGENVAL(2,I),EIGENVAL(3,I),MEAN_VR(I)*UV,
C     &         CONCENTRA(I),(ANGULARM(J,I),J=1,3),
C     &         VCMAX(I),MCMAX(I),RCMAX(I),
C     &         R200M(I),M200M(I),R200C(I),M200C(I),
C     &         R500M(I),M500M(I),R500C(I),M500C(I),
C     &         R2500M(I),M2500M(I),R2500C(I),M2500C(I),
C     &         VX(I)*UV,VY(I)*UV,VZ(I)*UV

******************************************
************ FIN HALO I ******************
******************************************
        END IF ! (ELSE of KONTA2.LT.NUMPARTBAS) (poor haloes after unbinding)
       END IF ! (realclus(i).ne.0)

*****************
       END DO   !I=IP,IP2
****************


       RETURN
       END




**********************************************************************
       SUBROUTINE REORDENAR(KONTA,CX,CY,CZ,RXPA,RYPA,RZPA,CONTADM,LIP,
     &                      DISTA,KONTA2,DO_SORT)
**********************************************************************
*      Sorts the particles with increasing distance to the center of
*      the halo. Only particles with CONTADM=0 are sorted (the others
*      are already pruned particles and therefore they are ignored)
*      Do_sort=1: particles are sorted by distance
*      Do_sort=0: particles are assumed to be sorted; just prune unbound
**********************************************************************

       IMPLICIT NONE

       INCLUDE 'input_files/asohf_parameters.dat'

       INTEGER I,J,K,KONTA,KONTA2,JJ,DO_SORT

*      ---HALOS Y SUBHALOS---
       REAL*4 CX,CY,CZ

*      ---PARTICULAS E ITERACIONES---
       INTEGER LIP(PARTIRED),CONTADM(PARTIRED)

       REAL*4 RXPA(PARTIRED)
       REAL*4 RYPA(PARTIRED)
       REAL*4 RZPA(PARTIRED)

c       INTEGER CONTADM(PARTI)

       REAL*4 DISTA(0:PARTIRED)

       INTEGER INDICE(KONTA)
       REAL*4 DISTA2(0:KONTA)
       INTEGER QUIEN(KONTA)

       REAL*4 AADMX,AADMY,AADMZ,AADM

       IF (DO_SORT.EQ.1) THEN ! we have to sort the particles
        QUIEN=0
        DISTA=1.E10
        INDICE=0
        DISTA2=0.0

        KONTA2=0
        DO J=1,KONTA
         IF (CONTADM(J).EQ.0) THEN
          KONTA2=KONTA2+1
          JJ=LIP(J)
          AADMX=RXPA(JJ)-CX
          AADMY=RYPA(JJ)-CY
          AADMZ=RZPA(JJ)-CZ
          AADM=SQRT(AADMX**2+AADMY**2+AADMZ**2)

          DISTA(KONTA2)=AADM
          QUIEN(KONTA2)=JJ
         END IF
        END DO

        CALL INDEXX(KONTA2,DISTA(1:KONTA2),INDICE(1:KONTA2))

        DO J=1,KONTA2
         DISTA2(J)=DISTA(J)
        END DO

        DISTA=1.E10
        LIP=0

        DO J=1,KONTA2
         JJ=INDICE(J)
         DISTA(J)=DISTA2(JJ)
         LIP(J)=QUIEN(JJ)
        END DO
       ELSE ! they are already sorted (since the center does not change)
        KONTA2=0
        DO J=1,KONTA
         IF (CONTADM(J).EQ.0) THEN
          KONTA2=KONTA2+1
          DISTA(KONTA2)=DISTA(J)
          LIP(KONTA2)=LIP(J)
         END IF
        END DO
       END IF

       CONTADM=1
       CONTADM(1:KONTA2)=0

       RETURN
       END

***********************************************************
       SUBROUTINE CENTROMASAS_PART(N,CONTADM,LIP,
     &            U2DM,U3DM,U4DM,MASAP,RXPA,RYPA,RZPA,
     &            CMX,CMY,CMZ,VCMX,VCMY,VCMZ,MASA)
***********************************************************
*      Computes the center of mass of the particles
*      within the halo
***********************************************************

       IMPLICIT NONE

       INCLUDE 'input_files/asohf_parameters.dat'

       INTEGER I,J,N

       REAL*4 U2DM(PARTIRED)
       REAL*4 U3DM(PARTIRED)
       REAL*4 U4DM(PARTIRED)
       REAL*4 MASAP(PARTIRED)
       REAL*4 RXPA(PARTIRED)
       REAL*4 RYPA(PARTIRED)
       REAL*4 RZPA(PARTIRED)

       INTEGER LIP(PARTIRED),CONTADM(PARTIRED)

       REAL*4 CMX,CMY,CMZ,VCMX,VCMY,VCMZ,MASA

*      ---- DOUBLE PRECISION -----------------------
       REAL*8 CMX8,CMY8,CMZ8,VCMX8,VCMY8,VCMZ8,MASA8
       REAL*8 NORMA,BAS
*      ---------------------------------------------


       CMX8=0.D0
       CMY8=0.D0
       CMZ8=0.D0

       VCMX8=0.D0
       VCMY8=0.D0
       VCMZ8=0.D0

       MASA8=0.D0

       NORMA=DBLE(MAXVAL(MASAP))  ! NORMALIZACION MASA

       DO I=1,N
        IF (CONTADM(I).EQ.0) THEN
         J=LIP(I)

         BAS=DBLE(MASAP(J))/NORMA

         CMX8=CMX8 + DBLE(RXPA(J))*BAS
         CMY8=CMY8 + DBLE(RYPA(J))*BAS
         CMZ8=CMZ8 + DBLE(RZPA(J))*BAS

         VCMX8=DBLE(U2DM(J))*BAS + VCMX8
         VCMY8=DBLE(U3DM(J))*BAS + VCMY8
         VCMZ8=DBLE(U4DM(J))*BAS + VCMZ8

         MASA8=MASA8+BAS

        END IF
       END DO

       IF (MASA8.GT.0.D0) THEN

       CMX8=(CMX8/MASA8)
       CMY8=(CMY8/MASA8)
       CMZ8=(CMZ8/MASA8)

       VCMX8=(VCMX8/MASA8)
       VCMY8=(VCMY8/MASA8)
       VCMZ8=(VCMZ8/MASA8)

       MASA8=MASA8*NORMA

       ELSE

       CMX8=0.D0
       CMY8=0.D0
       CMZ8=0.D0

       VCMX8=0.D0
       VCMY8=0.D0
       VCMZ8=0.D0

       MASA8=0.D0

       END IF

*      TRANSFORMACION   A REAL*4

       CMX=CMX8
       CMY=CMY8
       CMZ=CMZ8

       VCMX=VCMX8
       VCMY=VCMY8
       VCMZ=VCMZ8

       MASA=MASA8

       RETURN
       END
********************************************************************

***********************************************************
       SUBROUTINE UNBINDING8(FAC,I,REF_MIN,REF_MAX,DISTA,
     &           U2DM,U3DM,U4DM,MASAP,RXPA,RYPA,RZPA,
     &           RADIO,MASA,CLUSRXCM,CLUSRYCM,CLUSRZCM,
     &           LIP,KONTA,CONTADM,VX,VY,VZ,REALCLUS,KONTA2)
***********************************************************
*      Finds and discards the unbound particles (those
*      with speed larger than the scape velocity).
*      Potential is computed in double precision.
***********************************************************

       IMPLICIT NONE

       INCLUDE 'input_files/asohf_parameters.dat'

       INTEGER I,J,K,IX,IMAX,JJ,FAC

       REAL*4 REI,CGR,PI,PI4ROD
       COMMON /CONS/PI4ROD,REI,CGR,PI

       REAL*4 RETE,HTE,ROTE
       COMMON /BACK/ RETE,HTE,ROTE

       REAL*4 REF_MIN,REF_MAX

*      ---HALOS Y SUBHALOS---
       REAL*4 RADIO(MAXNCLUS)
       REAL*4 MASA(MAXNCLUS)
       REAL*4 CLUSRXCM(MAXNCLUS)
       REAL*4 CLUSRYCM(MAXNCLUS)
       REAL*4 CLUSRZCM(MAXNCLUS)
       REAL*4 VX(NMAXNCLUS)
       REAL*4 VY(NMAXNCLUS)
       REAL*4 VZ(NMAXNCLUS)
       INTEGER REALCLUS(MAXNCLUS)

*      ---PARTICULAS E ITERACIONES---
       INTEGER LIP(PARTIRED),CONTADM(PARTIRED)
       INTEGER NPART(0:NLEVELS)
       REAL*4 U2DM(PARTIRED)
       REAL*4 U3DM(PARTIRED)
       REAL*4 U4DM(PARTIRED)
       REAL*4 MASAP(PARTIRED)
       REAL*4 RXPA(PARTIRED)
       REAL*4 RYPA(PARTIRED)
       REAL*4 RZPA(PARTIRED)

       INTEGER KONTA,KONTA3,KONTA2
c       INTEGER CONTADM(PARTI)

       REAL*4 DISTA(0:PARTIRED)

       REAL*4 VVV2,VESC2,AADMX(3),AADM,DR, AA, BB, CC
       REAL*4 BAS
       REAL*4 CMX,CMY,CMZ,VCMX,VCMY,VCMZ,MMM
       REAL*4 POTOK

*!!!!! ESPECIAL DOBLE PRECISON !!!!!!!!!!!!!!!!!!!!!
COJO       REAL*8 POT(KONTA)
       REAL*8 POT(0:KONTA)
       REAL*8 POT1
       REAL*8 BAS8
       REAL*8 MASA8,NORMA
       REAL*8 AA8
***********************************************

       POT=0.D0

       IF (KONTA2.GT.0) THEN
*      Max mass
        NORMA=DBLE(MAXVAL(MASAP))
        MASA8=DBLE(MASAP(1))/NORMA

        !POT(1)=MASA8/DBLE(DISTA(1))
        !WRITE(*,*) 'IN UNBINDING, KONTA2=',KONTA2
        DO J=1,KONTA2
         IF (DISTA(J).GT.0.01*REF_MAX) EXIT
        END DO
        JJ=J
        MASA8=0.D0
        DO J=1,JJ
         MASA8=MASA8+DBLE(MASAP(LIP(J)))/NORMA
        END DO
        DO J=1,JJ
         POT(J)=MASA8/DISTA(JJ)
        END DO

        !WRITE(*,*) 'KONTA2,JJ=',konta2,jj

        DO J=JJ+1,KONTA2
          MASA8=MASA8+DBLE(MASAP(LIP(J)))/NORMA
          IF (DISTA(J).NE.DISTA(J-1)) THEN
           BAS8=DISTA(J)-DISTA(J-1)
          ELSE
           BAS8=0.D0
          END IF
          POT(J)=POT(J-1)+MASA8*BAS8/(DBLE(DISTA(J))**2)
        END DO

        POT1=POT(KONTA2) + MASA8/REF_MAX
        !POT1 is the constant to be subtracted to the computed potential
        !so that the potential origin is located at infinity

        AA8=NORMA*DBLE(CGR/RETE)

        BB=2.0
        IF (FAC.EQ.1) BB=8.0
        IF (FAC.EQ.2) BB=4.0

        BB=BB**2 !(we compare the squared velocities)

*      Find particles able to escape the potential well
        DO J=1,KONTA2

         POTOK=(POT(J)-POT1)*AA8
         VESC2=2.0*ABS(POTOK)

         VVV2=(U2DM(LIP(J))-VX(I))**2
     &       +(U3DM(LIP(J))-VY(I))**2
     &       +(U4DM(LIP(J))-VZ(I))**2

         IF (VVV2.GT.BB*VESC2)  CONTADM(J)=1
        END DO

*      NEW CENTER OF MASS AND ITS VELOCITY
        CALL CENTROMASAS_PART(KONTA,CONTADM,LIP,
     &           U2DM,U3DM,U4DM,MASAP,RXPA,RYPA,RZPA,
     &           CMX,CMY,CMZ,VCMX,VCMY,VCMZ,MMM)

       END IF

       KONTA3=COUNT(CONTADM(1:KONTA2).EQ.0)

       IF (KONTA3.EQ.0) THEN

        CLUSRXCM(I)=0.0
        CLUSRYCM(I)=0.0
        CLUSRZCM(I)=0.0

        VX(I)=0.0
        VY(I)=0.0
        VZ(I)=0.0

        MASA(I)=0.0
        RADIO(I)=0.0

        REALCLUS(I)=0

       ELSE

        CLUSRXCM(I)=CMX
        CLUSRYCM(I)=CMY
        CLUSRZCM(I)=CMZ

        VX(I)=VCMX
        VY(I)=VCMY
        VZ(I)=VCMZ

        MASA(I)=MMM*9.1717e+18

       END IF

       RETURN
       END


***********************************************************
       SUBROUTINE UNBINDING_SIGMA(FAC,I,REF_MIN,REF_MAX,U2DM,U3DM,U4DM,
     &                            RXPA,RYPA,RZPA,MASAP,RADIO,MASA,
     &                            CLUSRXCM,CLUSRYCM,CLUSRZCM,LIP,KONTA,
     &                            CONTADM,VX,VY,VZ,REALCLUS,KONTA2)
***********************************************************
*      Finds and discards the unbound particles (those
*      with speed larger than the scape velocity).
*      Potential is computed in double precision.
***********************************************************

       IMPLICIT NONE

       INCLUDE 'input_files/asohf_parameters.dat'

       INTEGER FAC
       INTEGER I
       REAL REF_MIN,REF_MAX
       REAL*4 U2DM(PARTIRED),U3DM(PARTIRED),U4DM(PARTIRED)
       REAL*4 RXPA(PARTIRED),RYPA(PARTIRED),RZPA(PARTIRED)
       REAL*4 MASAP(PARTIRED)
       REAL*4 RADIO(MAXNCLUS),MASA(MAXNCLUS)
       REAL*4 CLUSRXCM(MAXNCLUS),CLUSRYCM(MAXNCLUS),
     &        CLUSRZCM(MAXNCLUS)
       INTEGER LIP(PARTIRED),CONTADM(PARTIRED)
       INTEGER KONTA
       REAL*4 VX(NMAXNCLUS),VY(NMAXNCLUS),VZ(NMAXNCLUS)
       INTEGER REALCLUS(MAXNCLUS)

       REAL CMX,CMY,CMZ,VXCM,VYCM,VZCM,BAS,SIGMA2,BB,AADM,AADMX,AADMY
       REAL AADMZ,MMM
       INTEGER J,JJ,KONTA2,KONTA3
       REAL,ALLOCATABLE::DESV2(:)

       BB=MAX(6.0-1.0*(FAC-1), 3.0)
       BB=BB**2 ! This is because we compare velocities squared

       CMX=CLUSRXCM(I)
       CMY=CLUSRYCM(I)
       CMZ=CLUSRZCM(I)
       VXCM=VX(I)
       VYCM=VY(I)
       VZCM=VZ(I)

       ALLOCATE(DESV2(1:KONTA2))

       IF (KONTA2.GT.0) THEN
        SIGMA2=0.0
        DO J=1,KONTA2
         JJ=LIP(J)
         BAS=(U2DM(JJ)-VXCM)**2+(U3DM(JJ)-VYCM)**2+(U4DM(JJ)-VZCM)**2
         DESV2(J)=BAS
         SIGMA2=SIGMA2+BAS
        END DO

        IF (KONTA2.GT.1) SIGMA2=SIGMA2/(KONTA2-1)

*       Find particles with too large relative velocity
        DO J=1,KONTA2
         IF (DESV2(J).GT.BB*SIGMA2) CONTADM(J)=1
        END DO

*       NEW CENTER OF MASS AND ITS VELOCITY
        CALL CENTROMASAS_PART(KONTA,CONTADM,LIP,
     &           U2DM,U3DM,U4DM,MASAP,RXPA,RYPA,RZPA,
     &           CMX,CMY,CMZ,VXCM,VYCM,VZCM,MMM)

       END IF

       KONTA3=COUNT(CONTADM(1:KONTA2).EQ.0)

       IF (KONTA3.EQ.0) THEN

        CLUSRXCM(I)=0.0
        CLUSRYCM(I)=0.0
        CLUSRZCM(I)=0.0

        VX(I)=0.0
        VY(I)=0.0
        VZ(I)=0.0

        MASA(I)=0.0
        RADIO(I)=0.0

        REALCLUS(I)=0

       ELSE

        CLUSRXCM(I)=CMX
        CLUSRYCM(I)=CMY
        CLUSRZCM(I)=CMZ

        VX(I)=VXCM
        VY(I)=VYCM
        VZ(I)=VZCM

        MASA(I)=MMM*9.1717e+18

       END IF

       DEALLOCATE(DESV2)


       RETURN
       END
