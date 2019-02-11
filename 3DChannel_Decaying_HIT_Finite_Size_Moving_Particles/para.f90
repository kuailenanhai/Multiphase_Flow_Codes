      subroutine para
      use var_inc
      implicit none

      integer i,j,k

      pi = 4.0*atan(1.0) 
      pi2 = 2.0*pi

! specify the force magnitude
!     visc = 0.0032
!     Rstar = 200.0
      visc = 0.0036
      Rstar = 180.0
      ustar = 2.0*Rstar*visc/real(nx)
! force per unit volume
      force_in_y = 2.*rho0*ustar*ustar/real(nx)
      ystar = visc/ustar

! not used
      kpeak = 4         ! It does not matter. Starting from stagnant flow
      u0in = 0.0503     ! It does not matter. Starting from stagnant flow

      iseedf = 232300

! get rid of vscale
      vscale = 1.0
      escale = 1.0/(vscale*vscale)
      dscale = pi2/real(ny)/vscale**3
      tscale = pi2*vscale/real(ny)

      istep0 = 0
      istep00 = 1 
      istat = 0
      imovie = 0 

! wall clock time limit, must be the same as in RUN file, unit in [min]
      time_lmt = 1440.0
! wall clock time buffer, for saving the data, [min]
      time_buff = 10.0
! wall clock time upper bound, for computation, [s]
      time_bond = (time_lmt - time_buff)*60.d0

! "istpload" is to determine from which step the code will load up flow and 
! particle data for continue run. Usually istpload = the latest (istep), but 
! it can be any step # at which the "endrunflow" & "endrunpart" data are saved
! Note: this variable needs to be manually setup for each continue run

      istpload = 55000    !!!!THIS NEEDS TO BE CHANGED WHEN STARTING NEW RUNS
      force_mag = 1.0
      nsteps = 50000

!     nek = nx/3
      nek = int(nx7/2 - 1.5)

!     newrun = .true.
!     newinitflow = .true.
      newrun = .false.
      newinitflow = .false.
 
      tau = 3.0*visc + 0.5

! below are the coefficients for MRT collision step
! Linear analysis data for stability 
!      MRTtype = 1
! To recover LBGK  
       MRTtype = 2
! To reduce dissipation
!      MRTtype = 3 

      select case(MRTtype) 
      case(1)
        omegepsl = 0.0
        omegepslj = -475.0/63.0
        omegxx = 0.0
      case(2,3)
        omegepsl = 3.0
        omegepslj = -11.0/2.0
        omegxx = -1.0/2.0
      end select

      s9 = 1.0/tau
      s13 = s9

      select case(MRTtype) 
      case(1)
        s1 = 1.19
        s2 = 1.4
        s4 = 1.2
        s10 = 1.4
        s16 = 1.98
      case(2)
        s1 = s9
        s2 = s9
        s4 = s9
        s10 = s9
        s16 = s9
      case(3)
        s1 = 1.8
        s2 = s1
        s4 = s9
        s10 = s1
        s16 = s1
      end select

      coef1 = -2.0/3.0
      coef2 = -11.0
      coef3 = 8.0
      coef4 = -4.0
      coef5 = 2.0

      coef3i = 1.0/coef3
      coef4i = 1.0/coef4

      val1 = 19.0
      val2 = 2394.0
      val3 = 252.0
      val4 = 10.0
      val5 = 40.0
      val6 = 36.0
      val7 = 72.0
      val8 = 12.0
      val9 = 24.0

      val1i = 1.0/val1 
      val2i = 1.0/val2
      val3i = 1.0/val3
      val4i = 1.0/val4
      val5i = 1.0/val5
      val6i = 1.0/val6
      val7i = 1.0/val7
      val8i = 1.0/val8
      val9i = 1.0/val9
! MRT-realated parameters end here

      ww0 = 1.0/3.0
      ww1 = 1.0/18.0
      ww2 = 1.0/36.0

! The order must be exactly as in D'Humieres et al (2002), (A1)
!      Phil. Trans. R. Soc. Lond. A (2002) 360, 437-451
! index 0:  ( 0  0  0)
! index 1:  ( 1  0  0)
! index 2:  (-1  0  0)
! index 3:  ( 0  1  0)
! index 4:  ( 0 -1  0)
! index 5:  ( 0  0  1)
! index 6:  ( 0  0 -1)
!
! index 7:  (+1 +1  0)
! index 8:  (-1 +1  0)
! index 9:  (+1 -1  0)
! index 10: (-1 -1  0)
!
! index 11: (+1  0 +1)
! index 12: (-1  0 +1)
! index 13: (+1  0 -1)
! index 14: (-1  0 -1)
!
! index 15: ( 0 +1 +1)
! index 16: ( 0 -1 +1)
! index 17: ( 0 +1 -1)
! index 18: ( 0 -1 -1)
!
      cix = (/0, 1, -1, 0, 0, 0, 0,1,-1, 1,-1,1,-1, 1,-1,0, 0, 0, 0 /) 
      ciy = (/0, 0, 0, 1, -1, 0, 0,1, 1,-1,-1,0, 0, 0, 0,1,-1, 1,-1 /) 
      ciz = (/0, 0, 0, 0, 0,  1,-1,0, 0, 0, 0,1, 1,-1,-1,1, 1,-1,-1/) 

      ipopp=(/0, 2, 1, 4, 3, 6, 5, 10, 9, 8, 7, 14, 13, 12, 11, 18, 17, 16, 15/)


! find the neighboring nodes to each processor

!****changes

      nprocY = 20   !!!!THIS IS MEANT TO BE CHANGED WITH NPROC
      nprocZ = nproc/nprocY

      ly = ny/nprocY         !local division of dist for procs in y dir
      lz = nz/nprocZ         !local division of dist for procs in z dir

      if((mod(myid,nprocY)+1).eq.nprocY) then
        lyext=2
      else
        lyext=0
      endif
      lly = ly+lyext

!******create index for proccessors*******
      indy = mod(myid,nprocY)
      indz = int(myid/nprocY)

      mzp = mod(indz+1,nprocZ) * nprocY + indy  !top
      mzm = mod(indz + nprocZ - 1,nprocZ) * nprocY + indy !bottom

      myp = indz*nprocY + mod(indy+1,nprocY) !right
      mym = indz*nprocY + mod(indy+nprocY-1,nprocY) !left


      mypzp = mod(indz+1,nprocZ)*nprocY + mod(indy+1,nprocY) 
      mypzm = mod(indz+nprocZ-1,nprocZ)*nprocY + mod(indy+1,nprocY)
      mymzp = mod(indz+1,nprocZ)*nprocY + mod(indy+nprocY-1,nprocY)
      mymzm = mod(indz+nprocZ-1,nprocZ)*nprocY + mod(indy+nprocY-1,nprocY)


      rhoepsl = 1.e-05

! saving and loading directories relevant to flow
!     dircntdflow0 = trim('/glade/scratch/lwang/Particle_Resolved/LBM2Ddd/Channel0/cntdflow/')
      dirgenr = '/glade/scratch/cpeng/Channel_MRT/'
      dirdiag = trim(dirgenr)//'diag/'
      dirstat = trim(dirgenr)//'stat/'
      dirinitflow = trim(dirgenr)//'initflow/'
      dircntdflow = trim(dirgenr)//'cntdflow/'
      dirflowout = trim(dirgenr)//'flowout/'
      dirmoviedata = trim(dirgenr)//'moviedata/'
! particle-related parameters
       ipart = .false.
!      ipart = .true.

      if(ipart)then
        volp = 4.0/3.0*pi*rad**3
        amp = rhopart*volp
        aip = 0.4*amp*rad**2 ! moment of inertia for solid sphere

! rhog is used to calculate the (body force - buoyancy)
! Define g by setting Stokes settling velocity / ustar
! ws_normalized =  Stokes settling velocity / ustar
! (1) For with gravity case
!       ws_normalized = 1.0
!       g_lbm = 9.0/2.0*ws_normalized/(rhopart/rho0 - 1.0)  
!       g_lbm = g_lbm/rad**2*visc*ustar
!       rhog = (rhopart/rho0 - 1.0)*rho0*g_lbm
! (2) For no gravity case
        rhog = 0.0
        g_lbm = ustar*ustar/ystar

! stiff coefficient from Feng & Michaelides (2005) JCP 202, pp 20-51, eqn(28)
        stf0 = 0.025
        stf1 = 0.002
        stf0_w = 0.025
        stf1_w = 0.002
!       stf0 = 0.01
!       stf1 = 0.001
!       stf0_w = 0.01
!       stf1_w = 0.001

        iseedp = 12345
        msize = int(10.0*real(npart)/real(nproc))
!        msize = 5
 
        wwp = (/ww1, ww1, ww1, ww1, ww1, ww1, ww2, ww2, ww2,           &
                ww2, ww2, ww2, ww2, ww2, ww2, ww2, ww2, ww2/) 

! saving and loading directories relevant to particle
        dircntdpart = trim(dirgenr)//'cntdpart/'
        dirpartout = trim(dirgenr)//'partout/'
      end if

! Computing wave numbers and other values for the forcing
      do i = 1, nx+2, 2
       kxr(i)   = int(i/2)
       kxr(i+1) = kxr(i)
      end do

      do j = 1, ny
       if ( j.lt.ny/2+2 ) then
        kyr(j) = j - 1
       else
        kyr(j) = -(ny+1-j)
       endif
      end do

      do k = 1, nz
       if ( k.lt.nz/2+2 ) then
        kzr(k) = k - 1
       else
        kzr(k) = -(nz+1-k)
       endif
      end do

      iseedf = -iseedf
      ivf(:)  = 0
      iyf     = 0
      b1r = 0.0
      b2r = 0.0
      b3r = 0.0

      end subroutine para
!==================================================================

      subroutine allocarray
      use var_inc
      implicit none

      allocate (f(0:npop-1,lx,ly,lz))
      allocate (rho(lx,ly,lz))
      allocate (rhop(lx,ly,lz))
      allocate (ux(lx,ly,lz))
      allocate (uy(lx,ly,lz))
      allocate (uz(lx,ly,lz))
      allocate (ox(lx,ly,lz))
      allocate (oy(lx,ly,lz))
      allocate (oz(lx,ly,lz))
      allocate (kx(lx+2,ly+lyext,lz))
      allocate (ky(lx+2,ly+lyext,lz))
      allocate (kz(lx+2,ly+lyext,lz))
      allocate (k2(lx+2,ly+lyext,lz))
      allocate (ik2(lx+2,ly+lyext,lz))
      allocate (vx(lx+2,ly+lyext,lz))
      allocate (vy(lx+2,ly+lyext,lz))
      allocate (vz(lx+2,ly+lyext,lz))
      allocate (wx(lx+2,ly+lyext,lz))
      allocate (wy(lx+2,ly+lyext,lz))
      allocate (wz(lx+2,ly+lyext,lz))
      allocate (ibnodes(lx,ly,lz))

      allocate(force_realx(lx,ly,lz))
      allocate(force_realy(lx,ly,lz))
      allocate(force_realz(lx,ly,lz))

      ibnodes = -1

      if(ipart)then
      
      allocate (ovlpflag(npart))
      allocate (ovlpflagt(npart))
      allocate (ipglb(msize))
      allocate (ypglb(3,npart))
      allocate (ypglbp(3,npart))
      allocate (yp(3,msize))
      allocate (thetap(3,msize))
      allocate (wp(3,npart))
      allocate (wpp(3,npart))
      allocate (omgp(3,npart))
      allocate (omgpp(3,npart))
      allocate (dwdt(3,msize))
      allocate (domgdt(3,msize))
      allocate (fHIp(3,npart))
      allocate (flubp(3,npart))
      allocate (forcep(3,msize))
      allocate (forcepp(3,msize))
      allocate (torqp(3,npart))
      allocate (torqpp(3,msize))
      allocate (ilink(1:npop-1,lx,ly,lz))
      allocate (mlink(1:npop-1,lx,ly,lz))
      allocate (alink(1:npop-1,lx,ly,lz))
      allocate (ibnodes0(lx,ly,lz))
      allocate (isnodes(lx,ly,lz))
      allocate (isnodes0(lx,ly,lz))



      end if

      end subroutine allocarray
!==================================================================



