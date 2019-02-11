! -------------------------------------------------------------------------
!       MPI F90 Code for Simulating 3D Decaying Homogeneous Isotropic 
!       Turbulence (DHIT) with finite-size freely-moving particles 
!       embedded in the cube.
!
!       Using LBM D3Q19 MRT Model.
!
!           x   y   z
!       {   0   0   0   }      rest
!
!       {   +   0   0   }      dir  1
!       {   -   0   0   }      dir  2
!       {   0   +   0   }      dir  3
!       {   0   -   0   }      dir  4
!       {   0   0   +   }      dir  5
!       {   0   0   -   }      dir  6
!
!       {   +   +   0   }      dir  7
!       {   -   +   0   }      dir  8
!       {   +   -   0   }      dir  9
!       {   -   -   0   }      dir  10
!       {   +   0   +   }      dir  11
!       {   -   0   +   }      dir  12
!       {   +   0   -   }      dir  13
!       {   -   0   -   }      dir  14
!       {   0   +   +   }      dir  15
!       {   0   -   +   }      dir  16
!       {   0   +   -   }      dir  17
!       {   0   -   -   }      dir  18
! -------------------------------------------------------------------------
! this code is identical with test23 code, except that new subroutines
! for statistics of particle and fluid rms velocities are added 
      PROGRAM main
      use mpi
      use var_inc
      implicit none
!     real,dimension(4999) :: time_stream_max_array
      integer:: i,j,k

      call MPI_INIT(ierr)
      call MPI_COMM_RANK(MPI_COMM_WORLD,myid,ierr)
      call MPI_COMM_SIZE(MPI_COMM_WORLD,nproc,ierr)      


      call para

      call allocarray

      IF(newrun)THEN   

      if(newinitflow)then  

!        call initrand(iflowseed)
         call initvel
! FORCING has to be called as it is used in collision_MRT
         call FORCING

!       ux = 0.0
!       uy = 0.0
!       uz = 0.0

        call initpop
        istep = 0

! For testing
!       call macrovar
!       call statistc 
!
! pre-relaxation of density field after initial forcing
! Note: during this stage, ONLY update density,  keep velocity unchanged
        do

          call streaming

          rhop = rho
          call rhoupdat

          call collision_MRT 

          rhoerr = maxval(abs(rho - rhop))        

          call MPI_ALLREDUCE(rhoerr,rhoerrmax,1,MPI_REAL8,MPI_MAX,      &
                             MPI_COMM_WORLD,ierr)
          if(myid == 0 .and. mod(istep,1) == 0)                        &
            write(*,*)istep, rhoerrmax 

          if(rhoerrmax <= rhoepsl .or. istep > 15000)then
            if(myid == 0) write(*,*)'final relaxation => ',            &
                                    istep, rhoerrmax
            exit
          end if

          istep = istep + 1 

        end do 

! Check the maximum density fluctuations relative to rho0 = 1.0
          rhoerr = maxval(rho)        
          call MPI_ALLREDUCE(rhoerr,rhomax,1,MPI_REAL8,MPI_MAX, &
                             MPI_COMM_WORLD,ierr)
          rhoerr = minval(rho)        
          call MPI_ALLREDUCE(rhoerr,rhomin,1,MPI_REAL8,MPI_MIN, &
                             MPI_COMM_WORLD,ierr)
          if(myid == 0 ) write(*,*)istep, rhomax, rhomin


! save population for input of next run 

! The next line is for checking only
!       call statistc

        call saveinitflow    
        call macrovar 
        istep0 = 0
        istep = istep0

! The next two lines for checking only
!       call outputflow
        call statistc
        call statistc2

      else     
! readin population from previous saving

        call loadinitflow     
!        goto 101
        call macrovar 
        istep0=0
        istep = istep0
        call statistc
        call statistc2
      
      end if     

      ELSE
! load data from same number of processes  
      call loadcntdflow      
!     call input_outputf(1)

      if(ipart .and. istpload > irelease)then
        call loadcntdpart    
        call beads_links
      end if

      call macrovar

      END IF

! main loop
! Forcing is independent of time so only call once here
         call FORCING
!        call FORCINGP

      time_start = MPI_WTIME()

      do istep = istep0+1,istep0+nsteps 

      if(myid.eq.0 .and. mod(istep,100).eq.0) write(*,*) 'istep= ',istep


! Release partilces only after proper skewness (~ -0.5) has been established
! Initialise particle center position and velocity
      if(ipart .and. istep == irelease)then
        istep00 = 0

        call initpartpos
!        call loadinitpartpos

        call initpartvel

        call initpartomg 

        call beads_links

        istep00 = 1
 
      end if

!        if(istep==2) call writeflowfieldstart

!       if(myid == 0 .and. mod(istep-1,1) == 0)                        &
!         write(*,*) 'istep = ', istep 

!       call FORCING
!       call FORCINGP

        call collision_MRT
! The next two lines are FOR TESTING
!       call macrovar 
!       call statistc

        if(ipart .and. istep >= irelease) call beads_collision

        call streaming

        if(ipart .and. istep >= irelease)then
          call beads_lubforce
          call beads_move
          call beads_redistribute
          call beads_links
          call beads_filling
        end if

        call macrovar
! THE NEXT LINE IS FOR TESTING
!       call statistc

!       call outputflow
!       call diag
!       call statistc

         if(mod(istep,ndiag) == 0) call diag 
         if(mod(istep,nstat) == 0)  call statistc 
         if(mod(istep,nstat) == 0)  call statistc2
         if(mod(istep,nflowout) == 0) call outputflow 

         if(ipart .and. istep >= irelease .and. mod(istep,npartout) == 0)call outputpart

! output fiels and profiles from the particle surface
!        if(ipart .and. istep >= irelease .and. mod(istep,nmovieout) == 0) then
!          call moviedata
!          call sijstat03
!          go to 101
!        end if

!        if(mod(istep,nstat) == 0) call rmsstat
!        if(mod(istep,nsij) == 0) call sijstat03   
!        if(mod(istep,nsij) == 0) call sijstat 

! stop and save in the middle to meet the 6 hour time limit
        if(time_max > time_bond) exit


!      call MPI_ALLREDUCE(time_stream,time_stream_max,1,   &
!                 MPI_REAL8,MPI_MAX,MPI_COMM_WORLD,ierr)

!     time_stream_max_array(istep) = time_stream_max

      end do

! main loop ends here

       time_end = MPI_WTIME()
       time_diff = time_end - time_start

       call MPI_BARRIER(MPI_COMM_WORLD,ierr)
       call MPI_ALLREDUCE(time_diff,time_max,1,MPI_REAL8,  &
                           MPI_MAX,MPI_COMM_WORLD,ierr)

! save data for continue run
      call savecntdflow
!     call input_outputf(2)
      if(ipart .and. istep > irelease) call savecntdpart    

101   continue

      if(myid.eq.0)then
      write(*,*)'time_max = ',time_max
!     write(50,*)' ',time_stream_max_array
      endif


      call MPI_FINALIZE(ierr)

      END PROGRAM main
