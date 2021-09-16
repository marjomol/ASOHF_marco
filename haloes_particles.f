**********************************************************************
       SUBROUTINE REORDENAR(KONTA,NCLUSRX,NCLUSRY,NCLUSRZ,
     &                      RXPA,RYPA,RZPA,CONTADM,LIP,LIR,DISTA)
**********************************************************************
*      Sorts the particles with increasing distance to the center of
*      the halo
**********************************************************************

       IMPLICIT NONE

       INCLUDE 'input_files/asohf_parameters.dat'

       INTEGER I,J,K,KONTA,KONTA2


*      ---HALOS Y SUBHALOS---
       REAL*4 NCLUSRX
       REAL*4 NCLUSRY
       REAL*4 NCLUSRZ

*      ---PARTICULAS E ITERACIONES---
c       INTEGER LIP(PARTI), LIR(PARTI)
       INTEGER LIP(PARTIRED),LIR(PARTIRED),CONTADM(PARTIRED)

       REAL*4 RXPA(PARTIRED)
       REAL*4 RYPA(PARTIRED)
       REAL*4 RZPA(PARTIRED)

c       INTEGER CONTADM(PARTI)

       REAL*4 DISTA(0:PARTI)

       INTEGER INDICE(KONTA)
       REAL*4 DISTA2(0:KONTA)
       INTEGER QUIEN(KONTA)
       INTEGER QUIEN2(KONTA)

       REAL*4 AADMX(3),AADM

*      reordenar !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

       QUIEN=0
       QUIEN2=0
       DISTA=1.E10
       INDICE=0
       DISTA2=0.0


       KONTA2=0
       DO J=1, KONTA
         IF (CONTADM(J).EQ.0) THEN
         KONTA2=KONTA2+1

         AADMX(1)=RXPA(LIP(J))-NCLUSRX
         AADMX(2)=RYPA(LIP(J))-NCLUSRY
         AADMX(3)=RZPA(LIP(J))-NCLUSRZ

         AADM=SQRT(AADMX(1)**2+AADMX(2)**2+AADMX(3)**2)

         DISTA(KONTA2)=AADM
         QUIEN(KONTA2)=LIP(J)
         QUIEN2(KONTA2)=LIR(J)
         END IF
       END DO

       CALL INDEXX(KONTA2,DISTA(1:KONTA2),INDICE(1:KONTA2)) !las ordena todas
                   !no solo las seleccionadas


       DO J=1,KONTA2
        DISTA2(J)=DISTA(INDICE(J))
       END DO

       DISTA=1.E10
       LIP=0
       LIR=0

       CONTADM=1
       CONTADM(1:KONTA2)=0

       DO J=1,KONTA2
        DISTA(J)=DISTA2(J)
        LIP(J)=QUIEN(INDICE(J))
        LIR(J)=QUIEN2(INDICE(J))
       END DO

*      estan reordenados !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
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

c       INTEGER LIP(PARTI),CONTADM(PARTI)
       INTEGER LIP(PARTIRED),CONTADM(PARTIRED)

       REAL*4 CMX,CMY,CMZ,VCMX,VCMY,VCMZ,MASA

*      ---- DOBLE PRECISION ------------------------
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
       SUBROUTINE UNBINDING4(FAC,IFI,I,REF_MIN,REF_MAX,DISTA,
     &           U2DM,U3DM,U4DM,MASAP,RXPA,RYPA,RZPA,
     &           NR,NMASA,NCLUSRX,NCLUSRY,NCLUSRZ,
     &           LIP,LIR,KONTA,CONTADM,VX,VY,VZ)
***********************************************************
*      Finds and discards the unbound particles (those
*      with speed larger than the scape velocity)
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
       REAL*4 NR(MAXITER,NMAXNCLUS)
       REAL*4 NMASA(MAXITER,NMAXNCLUS)
       REAL*4 NCLUSRX(MAXITER,NMAXNCLUS)
       REAL*4 NCLUSRY(MAXITER,NMAXNCLUS)
       REAL*4 NCLUSRZ(MAXITER,NMAXNCLUS)
       REAL*4 VCM2(MAXITER,NMAXNCLUS)
       REAL*4 VX(MAXITER,NMAXNCLUS)
       REAL*4 VY(MAXITER,NMAXNCLUS)
       REAL*4 VZ(MAXITER,NMAXNCLUS)

*      ---PARTICULAS E ITERACIONES---
c       INTEGER LIP(PARTI), LIR(PARTI)
       INTEGER LIP(PARTIRED),LIR(PARTIRED),CONTADM(PARTIRED)
       INTEGER NPART(0:NLEVELS)
       REAL*4 U2DM(PARTIRED)
       REAL*4 U3DM(PARTIRED)
       REAL*4 U4DM(PARTIRED)
       REAL*4 MASAP(PARTIRED)
       REAL*4 RXPA(PARTIRED)
       REAL*4 RYPA(PARTIRED)
       REAL*4 RZPA(PARTIRED)

       INTEGER KONTA,IFI,KONTA3,KONTA2
c       INTEGER CONTADM(PARTI)

       REAL*4 DISTA(0:PARTI)

       REAL*4 VVV2,VESC,AADMX(3),AADM,DR, AA, BB, CC
       REAL*4 BAS
       REAL*4 CMX,CMY,CMZ,VCMX,VCMY,VCMZ,MASA
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

*      particulas ya ordenada!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
*      SOLO LAS PARTICULAS DE 1 A KONTA2 CONTRIBUYEN
       KONTA2=COUNT(CONTADM(1:KONTA).EQ.0)

*      masa maxima
       NORMA=MAXVAL(DBLE(MASAP))

       MASA8=0.D0
*      calculo del potencial en doble precision
COJO       MASA8=DBLE(MASAP(LIP(1)))/NORMA
       MASA8=DBLE(MASAP(1))/NORMA
       POT(1)=MASA8/DBLE(DISTA(1))

       DO J=2,KONTA2
         MASA8=MASA8+ DBLE(MASAP(LIP(J)))/NORMA
         BAS8=DISTA(J)-DISTA(J-1)
         POT(J)=POT(J-1)+ MASA8*BAS8/(DBLE(DISTA(J))**2)
       END DO

       POT1=POT(KONTA2) + MASA8/REF_MAX  ! INTEGRAL DE 0 A Rmax + CONSTANTE
       AA8=NORMA*DBLE(CGR/RETE)

       BB=2.0   !1.8
       IF (FAC.EQ.1) BB=8.0
       IF (FAC.EQ.2) BB=4.0
       IF (FAC.EQ.3) BB=2.0
CX       WRITE(*,*) ' ---> factor vesc:',bb

*      desligando particulas !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
       DO J=1,KONTA2

        POTOK=(POT(J) - POT1)*AA8

        VESC=SQRT(2.0*ABS(POTOK))

        VVV2=(U2DM(LIP(J))-VX(IFI,I))**2
     &      +(U3DM(LIP(J))-VY(IFI,I))**2
     &      +(U4DM(LIP(J))-VZ(IFI,I))**2

        VVV2=SQRT(VVV2)

        IF (VVV2.GT.BB*VESC)  CONTADM(J)=1
       END DO

CX       WRITE(*,*)'PARTICULAS NO LIGADAS=',
CX     &            COUNT(CONTADM(1:KONTA).NE.0)


*      NEW CENTRO DE MASAS Y VELOCIDAD
       CALL CENTROMASAS_PART(KONTA,CONTADM,LIP,
     &           U2DM,U3DM,U4DM,MASAP,RXPA,RYPA,RZPA,
     &           CMX,CMY,CMZ,VCMX,VCMY,VCMZ,MASA)

       KONTA3=COUNT(CONTADM(1:KONTA).EQ.0)

       IF (KONTA3.EQ.0) THEN

       NCLUSRX(IFI,I)=0.0
       NCLUSRY(IFI,I)=0.0
       NCLUSRZ(IFI,I)=0.0

       VX(IFI,I)=0.0
       VY(IFI,I)=0.0
       VZ(IFI,I)=0.0

       NMASA(IFI,I)=0.0

CX       WRITE(*,*) 'PART.LIGADAS_3=', KONTA3

       NR(IFI,I)=0.0

       ELSE

       NCLUSRX(IFI,I)=CMX
       NCLUSRY(IFI,I)=CMY
       NCLUSRZ(IFI,I)=CMZ

       VX(IFI,I)=VCMX
       VY(IFI,I)=VCMY
       VZ(IFI,I)=VCMZ

       NMASA(IFI,I)=MASA*9.1717e+18


*      estimacion nuevo radio

       REF_MIN=10.0E+10
       REF_MAX=-1.0

       DO J=1,KONTA
       IF (CONTADM(J).EQ.0) THEN

        AADMX(1)=RXPA(LIP(J))-CMX
        AADMX(2)=RYPA(LIP(J))-CMY
        AADMX(3)=RZPA(LIP(J))-CMZ

        AADM=SQRT(AADMX(1)**2+AADMX(2)**2+AADMX(3)**2)

        REF_MIN=MIN(REF_MIN,AADM)
        REF_MAX=MAX(REF_MAX,AADM)
       END IF
       END DO


CX       write(*,*) 'new_r',NR(IFI,I),REF_MAX
       NR(IFI,I)=REF_MAX

       END IF

       RETURN
       END
