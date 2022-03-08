********************************************************************
      SUBROUTINE STELLAR_HALOES(NCLUS,MASA,RADIO,MSUB,RSUB,REALCLUS,
     &                          DMPCLUS,CLUSRX,CLUSRY,CLUSRZ,RXPA,RYPA,
     &                          RZPA,MASAP,U2DM,U3DM,U4DM,ORIPA,N_DM,
     &                          N_ST,NX,LADO0,PARTICLES_PER_HALO,
     &                          INDCS_PARTICLES_PER_HALO,UM,UV,
     &                          MIN_NUM_PART_ST,FLAG_WDM,ITER,ZETA)
********************************************************************

      IMPLICIT NONE
      INCLUDE 'input_files/asohf_parameters.dat'

      INTEGER NCLUS
      REAL*4 MASA(MAXNCLUS),RADIO(MAXNCLUS)
      REAL*4 MSUB(MAXNCLUS),RSUB(MAXNCLUS)
      INTEGER REALCLUS(MAXNCLUS), DMPCLUS(MAXNCLUS)
      REAL*4 CLUSRX(MAXNCLUS),CLUSRY(MAXNCLUS),CLUSRZ(MAXNCLUS)
      REAL*4 RXPA(PARTIRED),RYPA(PARTIRED),RZPA(PARTIRED)
      REAL*4 MASAP(PARTIRED)
      REAL*4 U2DM(PARTIRED),U3DM(PARTIRED),U4DM(PARTIRED)
      INTEGER ORIPA(PARTIRED)
      INTEGER N_DM,N_ST,NX
      REAL*4 LADO0
      INTEGER PARTICLES_PER_HALO(PARTIRED)
      INTEGER INDCS_PARTICLES_PER_HALO(2,NMAXNCLUS)
      REAL*4 UM,UV
      INTEGER MIN_NUM_PART_ST,FLAG_WDM,ITER
      REAL*4 ZETA

      INTEGER NSTPART_X(0:NMAX),I,LOWP1,LOWP2,J,JJ,NST_HALO,NDM_HALO
      INTEGER MAX_NUM_PART_LOCAL,WELL_ALLOCATED,MINORIPA,MAXORIPA
      INTEGER NPART_HALO,BASINT,KONTA,KONTA2,FAC,CONTAERR,IX,JY
      INTEGER COUNT_1,COUNT_2,KONTA2PREV,NCLUS_ST,J_HALFMASS
      REAL XLDOM,CX,CY,CZ,RCLUS,RCLUS2,XP,YP,ZP,CMX,CMY,CMZ
      REAL VCMX,VCMY,VCMZ,BASMAS,REF_MIN,REF_MAX,BASVECCM(3),BASVCM(3)
      REAL RHALFMASS,MHALFMASS,XPEAK,YPEAK,ZPEAK,VVV2,INERTIA4(3,3)
      REAL BASEIGENVAL(3)

      REAL*8 M8,X8,Y8,Z8,VX8,VY8,VZ8,LX8,LY8,LZ8,INERTIA8(3,3)
      REAL*8 SIGMA_HALO8

      INTEGER STPCLUS(NCLUS)
      REAL ST_HALFMASS(NCLUS),ST_HALFMASSRADIUS(NCLUS)
      REAL ST_XPEAK(NCLUS),ST_YPEAK(NCLUS),ST_ZPEAK(NCLUS)
      REAL ST_XCM(NCLUS),ST_YCM(NCLUS),ST_ZCM(NCLUS)
      REAL ST_VXCM(NCLUS),ST_VYCM(NCLUS),ST_VZCM(NCLUS)
      REAL ST_ANGULARM(3,NCLUS),ST_INERTIATENSOR(6,NCLUS)
      REAL ST_EIGENVALUES(3,NCLUS),ST_VELOCITYDISPERSION(NCLUS)

      INTEGER,ALLOCATABLE::ORIPADM_LUT(:)
      INTEGER,ALLOCATABLE::LIP(:),CONTADM(:),LIPST(:)
      REAL,ALLOCATABLE::DISTA(:),DISTAST(:)

      ! For writing stellar particles
      INTEGER,ALLOCATABLE::PARTICLES_PROC(:,:),PROC_NPARTICLES(:)
      INTEGER,ALLOCATABLE::HALOES_PROC(:,:)
      INTEGER NUM_PROC,ID_PROC,IPART_PROC,OMP_GET_THREAD_NUM
      COMMON /PROCESADORES/ NUM_PROC

      INTEGER PARTICLES_PER_HALO_ST(N_ST)
      INTEGER INDCS_PARTICLES_PER_HALO_ST(2,NCLUS)

      CHARACTER*5 ITER_STRING
      WRITE(ITER_STRING, '(I5.5)') ITER !For saving files to disk

      WRITE(*,*) 'DM, stellar particles:', N_DM, N_ST

      XLDOM=-LADO0/2.0

**********************************************************************
*     Sort stellar particles
**********************************************************************
      CALL SORT_STELLAR_PARTICLES_X(U2DM,U3DM,U4DM,MASAP,RXPA,RYPA,RZPA,
     &                              ORIPA,N_DM,N_ST,NSTPART_X,NX,LADO0)

**********************************************************************
*     Build ORIPA_DM Look-up table to get particles from the oripas
**********************************************************************
      MINORIPA=MINVAL(ORIPA(1:N_DM))
      MAXORIPA=MAXVAL(ORIPA(1:N_DM))
      ALLOCATE(ORIPADM_LUT(MINORIPA:MAXORIPA))
!$OMP PARALLEL DO SHARED(MINORIPA,MAXORIPA,ORIPADM_LUT),
!$OMP+            PRIVATE(I),
!$OMP+            DEFAULT(NONE)
      DO I=MINORIPA,MAXORIPA
       ORIPADM_LUT(I)=-1
      END DO

!$OMP PARALLEL DO SHARED(N_DM,ORIPADM_LUT,ORIPA),
!$OMP+            PRIVATE(I),
!$OMP+            DEFAULT(NONE)
      DO I=1,N_DM
       ORIPADM_LUT(ORIPA(I))=I
      END DO

      !WRITE(*,*) 'ORIPA LOT DONE!',MINORIPA,MAXORIPA

      IF (FLAG_WDM.EQ.1) THEN
       ALLOCATE(PARTICLES_PROC(N_ST,NUM_PROC),
     &          HALOES_PROC(3,NCLUS),
     &          PROC_NPARTICLES(NUM_PROC))
       PROC_NPARTICLES(1:NUM_PROC)=0
      END IF

**********************************************************************
*     Main loop through DM haloes
**********************************************************************
      NCLUS_ST=0

!$OMP PARALLEL DO SHARED(NCLUS,REALCLUS,STPCLUS,CLUSRX,CLUSRY,CLUSRZ,
!$OMP+                   RADIO,RSUB,XLDOM,NSTPART_X,RXPA,RYPA,RZPA,
!$OMP+                   MIN_NUM_PART_ST,DMPCLUS,ORIPADM_LUT,
!$OMP+                   PARTICLES_PER_HALO,INDCS_PARTICLES_PER_HALO,
!$OMP+                   ST_HALFMASS,ST_HALFMASSRADIUS,ST_XPEAK,
!$OMP+                   ST_YPEAK,ST_ZPEAK,ST_XCM,ST_YCM,ST_ZCM,ST_VXCM,
!$OMP+                   ST_VYCM,ST_VZCM,ST_ANGULARM,ST_INERTIATENSOR,
!$OMP+                   ST_EIGENVALUES,ST_VELOCITYDISPERSION,MASAP,
!$OMP+                   U2DM,U3DM,U4DM,N_DM,UM,UV,FLAG_WDM,
!$OMP+                   PROC_NPARTICLES,HALOES_PROC,PARTICLES_PROC,
!$OMP+                   ORIPA),
!$OMP+            PRIVATE(I,CX,CY,CZ,RCLUS,RCLUS2,LOWP1,LOWP2,
!$OMP+                    MAX_NUM_PART_LOCAL,J,LIPST,JJ,NDM_HALO,
!$OMP+                    NST_HALO,NPART_HALO,LIP,CONTADM,DISTA,DISTAST,
!$OMP+                    KONTA,KONTA2,BASINT,REF_MIN,REF_MAX,FAC,
!$OMP+                    CONTAERR,KONTA2PREV,COUNT_1,COUNT_2,CMX,CMY,
!$OMP+                    CMZ,VCMX,VCMY,VCMZ,BASMAS,M8,MHALFMASS,
!$OMP+                    RHALFMASS,XPEAK,YPEAK,ZPEAK,X8,Y8,Z8,VX8,VY8,
!$OMP+                    VZ8,LX8,LY8,LZ8,INERTIA8,INERTIA4,J_HALFMASS,
!$OMP+                    SIGMA_HALO8,VVV2,BASVECCM,BASVCM,BASEIGENVAL,
!$OMP+                    ID_PROC,IPART_PROC),
!$OMP+            REDUCTION(+:NCLUS_ST)
!$OMP+            DEFAULT(NONE), SCHEDULE(DYNAMIC)
      DO I=1,NCLUS
       STPCLUS(I)=0
       IF (REALCLUS(I).EQ.0) CYCLE

       !***********************************************
       !!! IDENTIFY STELLAR PARTICLES INSIDE THE HALO
       !***********************************************
       CX=CLUSRX(I)
       CY=CLUSRY(I)
       CZ=CLUSRZ(I)
       IF (REALCLUS(I).EQ.-1) THEN
        RCLUS=RADIO(I)
       ELSE
        RCLUS=RSUB(I)
       END IF
       RCLUS2=RCLUS**2

       CALL FIND_PARTICLE_INDICES(CX,RCLUS,XLDOM,NSTPART_X,LOWP1,LOWP2)

       MAX_NUM_PART_LOCAL=0
       DO J=LOWP1,LOWP2
        IF ((RXPA(J)-CX)**2+(RYPA(J)-CY)**2+(RZPA(J)-CZ)**2.LT.RCLUS2)
     &    MAX_NUM_PART_LOCAL=MAX_NUM_PART_LOCAL+1
       END DO  !J=LOWP1,LOWP2

C       WRITE(*,*) 'HALO, NUM STARS:',I,MAX_NUM_PART_LOCAL,LOWP1,LOWP2
       IF (MAX_NUM_PART_LOCAL.EQ.0) CYCLE

       ALLOCATE(LIPST(MAX_NUM_PART_LOCAL))

       JJ=0
       DO J=LOWP1,LOWP2
        IF ((RXPA(J)-CX)**2+(RYPA(J)-CY)**2+(RZPA(J)-CZ)**2
     &      .LT.RCLUS2) THEN
         JJ=JJ+1
         LIPST(JJ)=J
        END IF
       END DO  !J=LOWP1,LOWP2

       IF (JJ.NE.MAX_NUM_PART_LOCAL) THEN
        WRITE(*,*) 'Wrong allocation of stars',JJ,MAX_NUM_PART_LOCAL
        STOP
       END IF

       IF (JJ.LT.MIN_NUM_PART_ST) THEN
        DEALLOCATE(LIPST)
        CYCLE
       END IF

       !***********************************************
       !!! RESCUE DM PARTICLES
       !***********************************************
       NDM_HALO=DMPCLUS(I)
       NST_HALO=MAX_NUM_PART_LOCAL
       NPART_HALO=NDM_HALO+NST_HALO

       ALLOCATE(LIP(NPART_HALO),CONTADM(NPART_HALO),DISTA(0:NPART_HALO))

       LOWP1=INDCS_PARTICLES_PER_HALO(1,I)
       LOWP2=INDCS_PARTICLES_PER_HALO(2,I)
       JJ=0
       DO J=LOWP1,LOWP2
        JJ=JJ+1
        LIP(JJ)=ORIPADM_LUT(PARTICLES_PER_HALO(J))
       END DO
       DO J=1,NST_HALO
        JJ=JJ+1
        LIP(JJ)=LIPST(J)
       END DO
       IF (JJ.NE.NPART_HALO) THEN
        WRITE(*,*) 'Problem with halo',I,JJ,NPART_HALO
        STOP
       END IF
c       WRITE(*,*) I,MINVAL(DISTA(1:NPART_HALO)),
c     &            MAXVAL(DISTA(1:NPART_HALO)),RCLUS

       !***********************************************
       !!! SORT DM AND STELLAR PARTICLES ALTOGETHER
       !***********************************************
       ! Stellar particles will have LIP>N_DM
       KONTA=NPART_HALO
       BASINT=KONTA
       CONTADM(1:KONTA)=0
       CALL REORDENAR(KONTA,CX,CY,CZ,RXPA,RYPA,RZPA,CONTADM,LIP,
     &                DISTA,KONTA2,1,NPART_HALO,BASINT)

C       JJ=-1
C       DO J=2,NPART_HALO
C        IF (DISTA(J).LT.DISTA(J-1)) THEN
C         WRITE(*,*) 'HALO',I,'UNSORTED PARTICLES!',J,DISTA(J),DISTA(J-1)
C         EXIT
C        END IF
C       END DO

C       IF (COUNT(LIP.GT.N_DM).NE.NST_HALO) THEN
C        WRITE(*,*) 'HAVE LOST STARS,',COUNT(LIP.GT.N_DM),NST_HALO
C        STOP
C       END IF

       !***********************************************
       !!! UNBINDING: SCAPE VELOCITY
       !***********************************************

       REF_MIN=DISTA(1)
       REF_MAX=DISTA(NPART_HALO)

       CALL CENTROMASAS_PART(KONTA,CONTADM,LIP,U2DM,U3DM,U4DM,MASAP,
     &                       RXPA,RYPA,RZPA,CMX,CMY,CMZ,VCMX,VCMY,VCMZ,
     &                       BASMAS,NPART_HALO)
C       WRITE(*,*) VCMX,VCMY,VCMZ

       FAC=0
       DO WHILE (CONTAERR.GT.0.OR.FAC.LT.3)
        FAC=FAC+1
        KONTA2PREV=KONTA2
        CALL UNBINDING8_STARS(FAC,REF_MIN,REF_MAX,DISTA,U2DM,U3DM,
     &                  U4DM,MASAP,RXPA,RYPA,RZPA,LIP,KONTA,
     &                  CONTADM,KONTA2,NPART_HALO,UM,VCMX,VCMY,VCMZ,
     &                  N_DM)
        BASINT=KONTA
        CALL REORDENAR(KONTA,CX,CY,CZ,RXPA,RYPA,RZPA,CONTADM,LIP,
     &                 DISTA,KONTA2,0,NPART_HALO,BASINT)
        REF_MAX=DISTA(KONTA2)
        REF_MIN=DISTA(1)
        CONTAERR=KONTA2PREV-KONTA2
       END DO

       count_1=konta-konta2
       count_2=konta2 !backup
C       write(*,*) 'Unbinding V_ESC',i,'. ',konta-ndm_halo,'-->',
C     &             konta2-ndm_halo,'. Pruned:',count_1,'. Iters:', FAC

       !***********************************************
       !!! GET RID OF DM PARTICLES (WE NO LONGER WANT THEM)
       !***********************************************
       NST_HALO=COUNT(LIP.GT.N_DM.AND.CONTADM.EQ.0)
       IF (NST_HALO.LT.MIN_NUM_PART_ST) THEN
         DEALLOCATE(LIPST,LIP,CONTADM,DISTA)
         CYCLE
       END IF
       DEALLOCATE(LIPST)
       ALLOCATE(DISTAST(0:NST_HALO),LIPST(NST_HALO))

       JJ=0
       DO J=1,KONTA2
        IF (LIP(J).GT.N_DM.AND.CONTADM(J).EQ.0) THEN
         JJ=JJ+1
         LIPST(JJ)=LIP(J)
         DISTAST(JJ)=DISTA(J)
        END IF
       END DO
       KONTA2=JJ
C       write(*,*) 'now we have stellar particles:',KONTA2,NST_HALO

       DEALLOCATE(LIP,DISTA,CONTADM)
       ALLOCATE(CONTADM(NST_HALO))
       CONTADM=1
       CONTADM(1:KONTA2)=0

       CALL CENTROMASAS_PART(KONTA2,CONTADM,LIPST,
     &          U2DM,U3DM,U4DM,MASAP,RXPA,RYPA,RZPA,
     &          CMX,CMY,CMZ,VCMX,VCMY,VCMZ,BASMAS,NST_HALO)

       !***********************************************
       !!! UNBINDING: PHASE SPACE
       !***********************************************
       FAC=0
       CONTAERR=KONTA2
       KONTA=KONTA2
       DO WHILE (CONTAERR.GT.0.OR.FAC.LT.4)
        FAC=FAC+1
        KONTA2PREV=KONTA2
        CALL UNBINDING_SIGMA_STARS(FAC,REF_MIN,REF_MAX,U2DM,U3DM,U4DM,
     &               RXPA,RYPA,RZPA,MASAP,LIPST,CONTADM,KONTA2,
     &               NST_HALO,UM,VCMX,VCMY,VCMZ,N_DM)
        BASINT=KONTA
        CALL REORDENAR(KONTA,CX,CY,CZ,RXPA,RYPA,RZPA,CONTADM,LIPST,
     &                 DISTAST,KONTA2,0,NST_HALO,BASINT)
        REF_MAX=DISTAST(KONTA2)
        REF_MIN=DISTAST(1)
        CONTAERR=KONTA2PREV-KONTA2
        !write(*,*) 'sigma unbinding: iter,unbound',fac,contaerr
       END DO

       count_2=konta-konta2
C       write(*,*) 'Unbinding SIGMA',i,'. ',konta,'-->',konta2,
C     &            '. Pruned:',count_2,'. Iters:', FAC
C       write(*,*) '--'

       IF (KONTA2.LT.MIN_NUM_PART_ST) THEN
        DEALLOCATE(CONTADM,LIPST,DISTAST)
        CYCLE
       END IF

       NCLUS_ST=NCLUS_ST+1
C       WRITE(*,*) 'ACCEPTED STELLAR HALO',I,NCLUS_ST,KONTA2

       !***********************************************
       !!! PRE-ESTIMATION OF THE HALF-MASS RADIUS
       !***********************************************
       M8=0.D0
       DO J=1,KONTA2
        JJ=LIPST(J)
        BASMAS=MASAP(JJ)
        M8=M8+BASMAS
       END DO

       MHALFMASS=M8/2.D0
       M8=0.D0
       DO J=1,KONTA2
        JJ=LIPST(J)
        BASMAS=MASAP(JJ)
        M8=M8+BASMAS
        IF (M8.GT.MHALFMASS) EXIT
       END DO
       IF (J.LT.KONTA2) THEN
        J_HALFMASS=J
       ELSE
        J_HALFMASS=KONTA2
       END IF
       RHALFMASS=DISTAST(J_HALFMASS)

c       write(*,*) j_halfmass,konta2,mhalfmass
c       WRITE(*,*) RHALFMASS,RCLUS
c       WRITE(*,*) MHALFMASS*UM
c       WRITE(*,*) CX,CY,CZ
c       write(*,*) distast(1:konta2)

       !***********************************************
       !!! RECENTER
       !***********************************************
       XPEAK=CX
       YPEAK=CY
       ZPEAK=CZ

       CALL RECENTER_DENSITY_PEAK_STARS(XPEAK,YPEAK,ZPEAK,RHALFMASS,
     &               RXPA,RYPA,RZPA,MASAP,NST_HALO,LIPST,KONTA2)

C       WRITE(*,*) '-->',XPEAK,YPEAK,ZPEAK

       BASINT=NST_HALO
       KONTA=KONTA2
       CALL REORDENAR(KONTA,XPEAK,YPEAK,ZPEAK,RXPA,RYPA,RZPA,CONTADM,
     &                LIPST,DISTAST,KONTA2,1,NST_HALO,BASINT)

       !***********************************************
       !!! CORRECT HALF-MASS RADIUS, DETERMINE CM PROPERTIES
       !***********************************************
       M8=0.D0
       X8=0.D0
       Y8=0.D0
       Z8=0.D0
       VX8=0.D0
       VY8=0.D0
       VZ8=0.D0
       DO J=1,KONTA2
        JJ=LIPST(J)
        BASMAS=MASAP(JJ)
        M8=M8+BASMAS
        X8=X8+BASMAS*RXPA(JJ)
        Y8=Y8+BASMAS*RYPA(JJ)
        Z8=Z8+BASMAS*RZPA(JJ)
        VX8=VX8+BASMAS*U2DM(JJ)
        VY8=VY8+BASMAS*U3DM(JJ)
        VZ8=VZ8+BASMAS*U4DM(JJ)
        IF (M8.GT.MHALFMASS) EXIT
       END DO
       IF (J.LT.KONTA2) THEN
        J_HALFMASS=J
       ELSE
        J_HALFMASS=KONTA2
       END IF
       RHALFMASS=DISTAST(J_HALFMASS)
       MHALFMASS=M8*UM
       CMX=X8/M8
       CMY=Y8/M8
       CMZ=Z8/M8
       VCMX=VX8/M8
       VCMY=VY8/M8
       VCMZ=VZ8/M8
C       write(*,*) j_halfmass,konta2,mhalfmass
C       WRITE(*,*) '-->',RHALFMASS,MHALFMASS
C       WRITE(*,*) '-->',CMX,CMY,CMZ
C       WRITE(*,*) '-->',VCMX,VCMY,VCMZ

       LX8=0.D0
       LY8=0.D0
       LZ8=0.D0
       INERTIA8(1:3,1:3)=0.D0
       SIGMA_HALO8=0.D0
       DO J=1,J_HALFMASS
        JJ=LIPST(J)

        BASVECCM(1)=RXPA(JJ)-CMX
        BASVECCM(2)=RYPA(JJ)-CMY
        BASVECCM(3)=RZPA(JJ)-CMZ

        BASVCM(1)=U2DM(JJ)-VCMX
        BASVCM(2)=U3DM(JJ)-VCMY
        BASVCM(3)=U4DM(JJ)-VCMZ

        VVV2=BASVCM(1)**2+BASVCM(2)**2+BASVCM(3)**2
        SIGMA_HALO8=SIGMA_HALO8+VVV2

**          ANGULAR MOMENTUM
        LX8=LX8+MASAP(JJ)*(BASVECCM(2)*BASVCM(3)
     &                    -BASVECCM(3)*BASVCM(2))
        LY8=LY8+MASAP(JJ)*(BASVECCM(3)*BASVCM(1)
     &                    -BASVECCM(1)*BASVCM(3))
        LZ8=LZ8+MASAP(JJ)*(BASVECCM(1)*BASVCM(2)
     &                    -BASVECCM(2)*BASVCM(1))

**          INERTIA TENSOR
        DO JY=1,3
        DO IX=1,3
          INERTIA8(IX,JY)=INERTIA8(IX,JY)
     &                   +MASAP(JJ)*BASVECCM(IX)*BASVECCM(JY)
        END DO
        END DO
       END DO

       STPCLUS(I)=J_HALFMASS
       ST_HALFMASS(I)=MHALFMASS
       ST_HALFMASSRADIUS(I)=RHALFMASS
       ST_XPEAK(I)=XPEAK
       ST_YPEAK(I)=YPEAK
       ST_ZPEAK(I)=ZPEAK
       ST_XCM(I)=CMX
       ST_YCM(I)=CMY
       ST_ZCM(I)=CMZ
       ST_VXCM(I)=VCMX*UV
       ST_VYCM(I)=VCMY*UV
       ST_VZCM(I)=VCMZ*UV
       ST_ANGULARM(1,I)=LX8*UV/M8
       ST_ANGULARM(2,I)=LY8*UV/M8
       ST_ANGULARM(3,I)=LZ8*UV/M8

       INERTIA4(1:3,1:3)=INERTIA8(1:3,1:3)/M8
       INERTIA4(1,2)=INERTIA4(2,1)
       INERTIA4(1,3)=INERTIA4(3,1)
       INERTIA4(2,3)=INERTIA4(3,2)
       ST_INERTIATENSOR(1,I)=INERTIA4(1,1)
       ST_INERTIATENSOR(2,I)=INERTIA4(1,2)
       ST_INERTIATENSOR(3,I)=INERTIA4(1,3)
       ST_INERTIATENSOR(4,I)=INERTIA4(2,2)
       ST_INERTIATENSOR(5,I)=INERTIA4(2,3)
       ST_INERTIATENSOR(6,I)=INERTIA4(3,3)

       ST_VELOCITYDISPERSION(I)=SQRT(SIGMA_HALO8/FLOAT(J_HALFMASS))*UV
       BASEIGENVAL(1:3)=0.0
       CALL JACOBI(INERTIA4,3,BASEIGENVAL,BASINT)
       CALL SORT(BASEIGENVAL,3,3)
       DO IX=1,3
        ST_EIGENVALUES(IX,I)=SQRT(5.0*BASEIGENVAL(IX))
       END DO

       IF (FLAG_WDM.EQ.1) THEN
        ID_PROC=OMP_GET_THREAD_NUM()+1
        IPART_PROC=PROC_NPARTICLES(ID_PROC)
        HALOES_PROC(1,I)=ID_PROC
        HALOES_PROC(2,I)=IPART_PROC+1
        DO J=1,J_HALFMASS
         JJ=LIPST(J)
         IPART_PROC=IPART_PROC+1
         PARTICLES_PROC(IPART_PROC,ID_PROC)=ORIPA(JJ)
        END DO
        PROC_NPARTICLES(ID_PROC)=IPART_PROC
        HALOES_PROC(3,I)=IPART_PROC
       END IF


       DEALLOCATE(LIPST,CONTADM,DISTAST)
      END DO !(I=1,NCLUS)

      IF (FLAG_WDM.EQ.1) THEN
       J=0
       DO I=1,NCLUS
        IF (STPCLUS(I).EQ.0) THEN
         INDCS_PARTICLES_PER_HALO_ST(1,I)=-1
         INDCS_PARTICLES_PER_HALO_ST(2,I)=-1
         CYCLE
        END IF

        INDCS_PARTICLES_PER_HALO_ST(1,I)=J+1

        ID_PROC=HALOES_PROC(1,I)
        LOWP1=HALOES_PROC(2,I)
        LOWP2=HALOES_PROC(3,I)

        DO IPART_PROC=LOWP1,LOWP2
         J=J+1
         PARTICLES_PER_HALO_ST(J)=PARTICLES_PROC(IPART_PROC,ID_PROC)
        END DO

        INDCS_PARTICLES_PER_HALO_ST(2,I)=J
       END DO

       DEALLOCATE(HALOES_PROC, PARTICLES_PROC, PROC_NPARTICLES)
      END IF

      WRITE(*,*) '===> Finally found',NCLUS_ST,'stellar haloes <==='
      WRITE(*,*)

*****************************************************************
*     WRITE STARS (we do it inside the routine so as to not
*                  mess the main program)
*****************************************************************
      KONTA2=COUNT(STPCLUS(1:NCLUS).GT.0)

      OPEN(3,FILE='./output_files/stellar_haloes'//ITER_STRING,
     &       STATUS='UNKNOWN')
      IF (FLAG_WDM.EQ.1) THEN
       OPEN(4,FILE='./output_files/stellar_particles'//ITER_STRING,
     &        FORM='UNFORMATTED')
       WRITE(4) KONTA2
      END IF

      WRITE(3,*) '*********************NEW ITER*******************'
      WRITE(3,*) ITER, NCLUS, KONTA2, ZETA
      WRITE(3,*) '************************************************'

111   FORMAT(30A14)
112   FORMAT(2I14,6F14.6,E14.6,F14.6,I14,3F14.6,3F14.6,6E14.6,
     &        3E14.6,F14.6,3F14.3)


      WRITE(3,*) '=====================================================
     &==================================================================
     &==================================================================
     &==================================================================
     &==================================================================
     &================================================================='

      WRITE(3,111) '* Halo ID'   ,'DM Halo ID'  ,'Density peak',
     &             'coordinates' ,'(DM, Mpc)'   ,'Density peak',
     &             'coordinates' ,'(*, Mpc)'    ,'M_1/2'       ,
     &             'R_1/2'       ,'Part. num.'  ,'Center of'   ,
     &             'mass coords' ,'(Mpc)'       ,'Semiaxes'    ,
     &             '(kpc)'       ,''            ,'Inertia'     ,
     &             'tensor'      ,'components'  ,'(ckpc^2)'    ,
     &             ''            ,''            ,'Spec. angul.',
     &             'momentum'    ,'(ckpc km/s)' ,'Veloc. disp.',
     &             'Bulk velocty','(km/s)'      ,''

      WRITE(3,111) ''            ,''            ,'x'           ,
     &             'y'           ,'z'           ,'x'           ,
     &             'y'           ,'z'           ,'(Msun)'      ,
     &             '(kpc)'       ,'r < R_1/2'   ,'x'           ,
     &             'y'           ,'z'           ,'Major'       ,
     &             'Intermediate','Minor'       ,'Ixx'         ,
     &             'Ixy'         ,'Ixz'         ,'Iyy'         ,
     &             'Iyz'         ,'Izz'         ,'Lx'          ,
     &             'Ly'          ,'Lz'          ,'(km/s)'      ,
     &             'Vx'          ,'Vy'          ,'Vz'

      WRITE(3,*) '=====================================================
     &==================================================================
     &==================================================================
     &==================================================================
     &==================================================================
     &================================================================='

      KONTA=0
      KONTA2=0
      DO I=1,NCLUS
       IF (STPCLUS(I).GT.0) THEN
        KONTA=KONTA+1
        WRITE(3,112) KONTA,I,CLUSRX(I),CLUSRY(I),CLUSRZ(I),ST_XPEAK(I),
     &               ST_YPEAK(I),ST_ZPEAK(I),ST_HALFMASS(I),
     &               ST_HALFMASSRADIUS(I)*1000.0,STPCLUS(I),ST_XCM(I),
     &               ST_YCM(I),ST_ZCM(I),
     &               (ST_EIGENVALUES(J,I)*1000.0,J=1,3),
     &               (ST_INERTIATENSOR(J,I)*1000000.0,J=1,6),
     &               (ST_ANGULARM(J,I)*1000.0,J=1,3),
     &               ST_VELOCITYDISPERSION(I),
     &               ST_VXCM(I),ST_VYCM(I),ST_VZCM(I)
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

      RETURN
      END


**********************************************************************
        SUBROUTINE RECENTER_DENSITY_PEAK_STARS(CX,CY,CZ,R,RXPA,RYPA,
     &               RZPA,MASAP,NST_HALO,LIPST,LAST_PARTICLE)
**********************************************************************
*       Recenters density peak using particles
**********************************************************************
        IMPLICIT NONE
        INCLUDE 'input_files/asohf_parameters.dat'

        REAL CX,CY,CZ,R,XLDOM
        REAL*4 RXPA(PARTIRED),RYPA(PARTIRED),RZPA(PARTIRED),
     &         MASAP(PARTIRED)
        INTEGER NST_HALO,LAST_PARTICLE
        INTEGER LIPST(NST_HALO)

        INTEGER KONTA,FLAG_LARGER,I,NN,IX,JY,KZ,IP
        INTEGER INMAX(3),KONTA2,FLAG_ITER,NUMPARTMIN,WELL_ALLOCATED
        INTEGER LOWP1,LOWP2
        REAL RADIO,BAS,XL,YL,ZL,DDXX,BASX,BASY,BASZ
        REAL,ALLOCATABLE::DENS(:,:,:)
        INTEGER,ALLOCATABLE::LIP(:)

        NUMPARTMIN=27 !3**3
        NN=3

        ALLOCATE(DENS(NN,NN,NN), LIP(1:LAST_PARTICLE))
        RADIO=R
        DDXX=2.0*RADIO/FLOAT(NN)
        XL=CX-RADIO
        YL=CY-RADIO
        ZL=CZ-RADIO

        DO I=1,LAST_PARTICLE
         LIP(I)=LIPST(I)
        END DO

        FLAG_ITER=1
        KONTA=LAST_PARTICLE

        IF (KONTA.LT.NUMPARTMIN) FLAG_ITER=0

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
          IF (IX.LT.1) IX=1
          IF (IX.GT.NN) IX=NN
          IF (JY.LT.1) JY=1
          IF (JY.GT.NN) JY=NN
          IF (KZ.LT.1) KZ=1
          IF (KZ.GT.NN) KZ=NN
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

C         WRITE(*,*) RADIO,KONTA2,CX,CY,CZ,DENS(IX,JY,KZ)/DDXX**3,
C     &              IX,JY,KZ,FLAG_ITER
        END DO

        DEALLOCATE(DENS)

        IF (KONTA.GT.0) THEN
         BAS=0.0
         BASX=0.0
         BASY=0.0
         BASZ=0.0
         DO I=1,KONTA
          IP=LIP(I)
          BAS=BAS+MASAP(IP)
          BASX=BASX+RXPA(IP)*MASAP(IP)
          BASY=BASY+RYPA(IP)*MASAP(IP)
          BASZ=BASZ+RZPA(IP)*MASAP(IP)
         END DO

         CX=BASX/BAS
         CY=BASY/BAS
         CZ=BASZ/BAS
        END IF

        RETURN
        END

***********************************************************
       SUBROUTINE UNBINDING_SIGMA_STARS(FAC,REF_MIN,REF_MAX,U2DM,U3DM,
     &              U4DM,RXPA,RYPA,RZPA,MASAP,LIP,CONTADM,
     &              KONTA2,MAX_NUM_PART,UM,VCMX,VCMY,VCMZ,N_DM)
***********************************************************
*      Finds and discards the unbound particles (those
*      with speed larger than the scape velocity).
*      VERSION FOR STARS (dark matter particles have already been treated)
***********************************************************

       IMPLICIT NONE

       INCLUDE 'input_files/asohf_parameters.dat'

       INTEGER FAC
       REAL REF_MIN,REF_MAX
       REAL*4 U2DM(PARTIRED),U3DM(PARTIRED),U4DM(PARTIRED)
       REAL*4 RXPA(PARTIRED),RYPA(PARTIRED),RZPA(PARTIRED)
       REAL*4 MASAP(PARTIRED)
       INTEGER LIP(MAX_NUM_PART),CONTADM(MAX_NUM_PART)
       INTEGER KONTA2,MAX_NUM_PART
       REAL*4 UM,VCMX,VCMY,VCMZ
       INTEGER N_DM

       REAL CMX,CMY,CMZ,BAS,BB,AADM,AADMX,AADMY
       REAL AADMZ,MMM
       INTEGER J,JJ,KONTA3
       REAL,ALLOCATABLE::DESV2(:)

*      DOUBLE PRECISION VARIABLES
       REAL*8 SIGMA2

       BB=MAX(6.0-1.0*(FAC-1), 3.0)
       BB=BB**2 ! This is because we compare velocities squared

       IF (KONTA2.GT.0) THEN

        ALLOCATE(DESV2(1:KONTA2))

        SIGMA2=0.D0
        DO J=1,KONTA2
         JJ=LIP(J)
         BAS=(U2DM(JJ)-VCMX)**2+(U3DM(JJ)-VCMY)**2+(U4DM(JJ)-VCMZ)**2
         DESV2(J)=BAS
         SIGMA2=SIGMA2+BAS
        END DO

        IF (KONTA2.GT.1) SIGMA2=SIGMA2/(KONTA2-1)

*       Find particles with too large relative velocity
        DO J=1,KONTA2
         IF (DESV2(J).GT.BB*SIGMA2) CONTADM(J)=1
        END DO

*       NEW CENTER OF MASS AND ITS VELOCITY
        CALL CENTROMASAS_PART(KONTA2,CONTADM,LIP,
     &           U2DM,U3DM,U4DM,MASAP,RXPA,RYPA,RZPA,
     &           CMX,CMY,CMZ,VCMX,VCMY,VCMZ,MMM,MAX_NUM_PART)

        DEALLOCATE(DESV2)

       END IF


       RETURN
       END

***********************************************************
       SUBROUTINE UNBINDING8_STARS(FAC,REF_MIN,REF_MAX,DISTA,
     &           U2DM,U3DM,U4DM,MASAP,RXPA,RYPA,RZPA,
     &           LIP,KONTA,CONTADM,KONTA2,MAX_NUM_PART,UM,
     &           VCMX,VCMY,VCMZ,N_DM)
***********************************************************
*      Finds and discards the unbound particles (those
*      with speed larger than the scape velocity).
*      Potential is computed in double precision.
*      VERSION FOR STARS (dark matter particles have already been treated)
***********************************************************

       IMPLICIT NONE

       INCLUDE 'input_files/asohf_parameters.dat'

       INTEGER FAC
       REAL*4 REF_MIN,REF_MAX
       REAL*4 DISTA(0:MAX_NUM_PART)
       REAL*4 U2DM(PARTIRED),U3DM(PARTIRED),U4DM(PARTIRED)
       REAL*4 MASAP(PARTIRED)
       REAL*4 RXPA(PARTIRED),RYPA(PARTIRED),RZPA(PARTIRED)
       INTEGER LIP(MAX_NUM_PART),CONTADM(MAX_NUM_PART)
       INTEGER KONTA,KONTA2,MAX_NUM_PART
       REAL*4 UM
       REAL*4 VCMX,VCMY,VCMZ
       INTEGER N_DM

       INTEGER J,K,IX,IMAX,JJ

       REAL*4 REI,CGR,PI,PI4ROD
       COMMON /CONS/PI4ROD,REI,CGR,PI

       REAL*4 RETE,HTE,ROTE
       COMMON /BACK/ RETE,HTE,ROTE

       INTEGER KONTA3
       REAL*4 VVV2,VESC2,AADMX(3),AADM,DR, AA, BB, CC
       REAL*4 BAS
       REAL*4 CMX,CMY,CMZ,MMM
       REAL*4 POTOK

*!!!!! ESPECIAL DOBLE PRECISON !!!!!!!!!!!!!!!!!!!!!
COJO       REAL*8 POT(KONTA)
       REAL*8 POT(0:KONTA)
       REAL*8 POT1
       REAL*8 BAS8
       REAL*8 MASA8
       REAL*8 AA8
***********************************************

       POT=0.D0

       IF (KONTA2.GT.0) THEN
*      Max mass
       MASA8=DBLE(MASAP(1))

       !POT(1)=MASA8/DBLE(DISTA(1))
       !WRITE(*,*) 'IN UNBINDING, KONTA2=',KONTA2
       DO J=1,KONTA2
        IF (DISTA(J).GT.0.01*REF_MAX) EXIT
       END DO
       JJ=J
       MASA8=0.D0
       DO J=1,JJ
        MASA8=MASA8+DBLE(MASAP(LIP(J)))
       END DO
       DO J=1,JJ
        POT(J)=MASA8/DISTA(JJ)
       END DO

       DO J=JJ+1,KONTA2
         MASA8=MASA8+DBLE(MASAP(LIP(J)))
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

       AA8=DBLE(CGR/RETE)

       BB=2.0
       IF (FAC.EQ.1) BB=8.0
       IF (FAC.EQ.2) BB=4.0

       BB=BB**2 !(we compare the squared velocities)

*      Find particles able to escape the potential well
       DO J=1,KONTA2
        IF (LIP(J).LE.N_DM) CYCLE

        POTOK=(POT(J)-POT1)*AA8
        VESC2=2.0*ABS(POTOK)

        VVV2=(U2DM(LIP(J))-VCMX)**2
     &      +(U3DM(LIP(J))-VCMY)**2
     &      +(U4DM(LIP(J))-VCMZ)**2

C        WRITE(*,*) SQRT(VVV2),SQRT(VESC2),DISTA(J)/REF_MAX,
C     &              DISTA(J),REF_MAX
        IF (VVV2.GT.BB*VESC2)  CONTADM(J)=1
       END DO

*      NEW CENTER OF MASS AND ITS VELOCITY
       CALL CENTROMASAS_PART(KONTA2,CONTADM,LIP,
     &          U2DM,U3DM,U4DM,MASAP,RXPA,RYPA,RZPA,
     &          CMX,CMY,CMZ,VCMX,VCMY,VCMZ,MMM,MAX_NUM_PART)

       END IF

       RETURN
       END


*********************************************************************
       SUBROUTINE SORT_STELLAR_PARTICLES_X(U2DM,U3DM,U4DM,MASAP,RXPA,
     &                  RYPA,RZPA,ORIPA,N_DM,N_ST,NSTPART_X,NX,LADO0)
*********************************************************************
*      Reorders DM particles by species (assumes there are N_ESP
*       especies, each 8 times lighter than the previous one)
*********************************************************************

       IMPLICIT NONE
       INCLUDE 'input_files/asohf_parameters.dat'

       REAL*4 U2DM(PARTIRED),U3DM(PARTIRED),U4DM(PARTIRED)
       REAL*4 MASAP(PARTIRED)
       REAL*4 RXPA(PARTIRED),RYPA(PARTIRED),RZPA(PARTIRED)
       INTEGER ORIPA(PARTIRED)
       INTEGER N_DM,N_ST,NSTPART_X(0:NMAX),NX
       REAL*4 LADO0

       INTEGER I,CONTA,IX,IXLAST
       REAL XL,DX,RADXR(0:NMAX)
       INTEGER,ALLOCATABLE::INDICES(:)
       REAL,ALLOCATABLE::SCR(:,:)
       INTEGER,ALLOCATABLE::SCRINT(:,:)

       WRITE(*,*) 'Sorting stellar particles by X coordinate',
     &            ' (for faster search)'

       DO I=1,NX
        NSTPART_X(I)=0
       END DO

       ALLOCATE(INDICES(1:N_ST))
       CALL INDEXX(N_ST,RXPA(N_DM+1:N_DM+N_ST),INDICES)

       ALLOCATE(SCR(1:7,1:N_ST), SCRINT(1,1:N_ST))

!$OMP PARALLEL DO SHARED(SCR,SCRINT,RXPA,RYPA,RZPA,U2DM,U3DM,U4DM,MASAP,
!$OMP+                   ORIPA,INDICES,N_DM,N_ST),
!$OMP+            PRIVATE(I),
!$OMP+            DEFAULT(NONE)
       DO I=1,N_ST
        SCR(1,I)=RXPA(N_DM+INDICES(I))
        SCR(2,I)=RYPA(N_DM+INDICES(I))
        SCR(3,I)=RZPA(N_DM+INDICES(I))
        SCR(4,I)=U2DM(N_DM+INDICES(I))
        SCR(5,I)=U3DM(N_DM+INDICES(I))
        SCR(6,I)=U4DM(N_DM+INDICES(I))
        SCR(7,I)=MASAP(N_DM+INDICES(I))
        SCRINT(1,I)=ORIPA(N_DM+INDICES(I))
       END DO

       DEALLOCATE(INDICES)

!$OMP PARALLEL DO SHARED(SCR,SCRINT,RXPA,RYPA,RZPA,U2DM,U3DM,U4DM,MASAP,
!$OMP+                   ORIPA,INDICES,N_DM,N_ST),
!$OMP+            PRIVATE(I),
!$OMP+            DEFAULT(NONE)
       DO I=1,N_ST
        RXPA(N_DM+I)=SCR(1,I)
        RYPA(N_DM+I)=SCR(2,I)
        RZPA(N_DM+I)=SCR(3,I)
        U2DM(N_DM+I)=SCR(4,I)
        U3DM(N_DM+I)=SCR(5,I)
        U4DM(N_DM+I)=SCR(6,I)
        MASAP(N_DM+I)=SCR(7,I)
        ORIPA(N_DM+I)=SCRINT(1,I)
       END DO

       DEALLOCATE(SCR,SCRINT)

       XL=-LADO0/2
       DX=LADO0/NX
       DO I=0,NX
        !RADXL(I)=XL+(I-1)*DX ! X left interface of cell I
        RADXR(I)=XL+I*DX ! X right interface of cell I
       END DO

       NSTPART_X(0)=N_DM
       IX=1
       DO I=N_DM+1,N_DM+N_ST
        IF (RXPA(I).GT.RADXR(IX)) THEN
         NSTPART_X(IX)=I-1
         IX=IX+1
         DO WHILE (RXPA(I).GT.RADXR(IX))
          NSTPART_X(IX)=I-1
          IX=IX+1
         END DO
        END IF
       END DO

       IXLAST=IX
       DO IX=IXLAST,NX
        NSTPART_X(IX)=I-1
       END DO

C       WRITE(*,*) 'CHECKING'
C       DO IX=1,NX
C        WRITE(*,*) IX,':',NSTPART_X(IX-1)+1,NSTPART_X(IX),':',
C     &             radxr(ix-1),radxr(ix),NSTPART_X(IX)-NSTPART_X(IX-1)
C        if (ix.eq.1) then
C         WRITE(*,*) ' --> just before left',' first particle'
C        else
C         WRITE(*,*) ' --> just before left',RXPA(NSTPART_X(IX-1))
C        end if
C
C        WRITE(*,*) ' --> just after left', RXPA(NSTPART_X(IX-1)+1)
C        WRITE(*,*) ' --> just before right',RXPA(NSTPART_X(IX))
C        if (ix.eq.nx) then
C         WRITE(*,*) ' --> just after right',' last particle'
C        else
C         WRITE(*,*) ' --> just after right',RXPA(NSTPART_X(IX)+1)
C        end if
C
C       END DO
C
C       WRITE(*,*)

       RETURN
       END
