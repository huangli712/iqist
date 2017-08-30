!!!=========+=========+=========+=========+=========+=========+=========+!
!!! AZALEA @ iQIST                                                       !
!!!                                                                      !
!!! A highly optimized diagrammatic framework for dynamical mean field   ! 
!!! theory which can be used to treat non-local correlations in strongly !
!!! correlated systems
!!!                                                                      !
!!! author  : Li Huang (at IOP/CAS & SPCLab/CAEP & UNIFR)                !
!!! status  : (WARNING) IN TESTING STAGE, USE IT IN YOUR RISK            !
!!! comment : now only the dual fermion approach is implemented          !
!!!           any question, please contact with lihuang.dmft@gmail.com   !
!!!=========+=========+=========+=========+=========+=========+=========+!

!!========================================================================
  PROGRAM DT_MAIN !                                                    <<<
!!========================================================================

     use mmpi, only : mp_init      ! init mpi environment
     use mmpi, only : mp_finalize  ! finalize mpi environment
     use mmpi, only : mp_barrier   ! barrier to synchronize the data
     use mmpi, only : mp_comm_rank ! get index of current process
     use mmpi, only : mp_comm_size ! get number of processes

     use control, only : nprocs    ! number of processes
     use control, only : myid      ! index of current process
     use control, only : master    ! index of master process

     implicit none

! initialize mpi envirnoment
# if defined (MPI)

! initialize the mpi execution environment
     call mp_init()

! determines the rank of the calling process in the communicator
     call mp_comm_rank(myid)

! determines the size of the group associated with a communicator
     call mp_comm_size(nprocs)

# endif  /* MPI */

     DMFT_START: BLOCK

! print the welcome messages
         if ( myid == master ) then ! only master node can do it
             call dt_print_header()
         endif ! back if ( myid == master ) block

         call dt_config()

         call dt_setup_array()

         call dt_mesh_init()
         call dt_dmft_init()
         call dt_latt_init()
         call dt_dual_init()
         call dt_vert_init()

         if ( myid == master ) then
             call dt_print_summary()
         endif

     END BLOCK DMFT_START

     call dt_df_core()

     call dt_final_array()

     if ( myid == master ) then
         call dt_print_footer()
     endif

! finalize mpi envirnoment
# if defined (MPI)

! blocks until all processes have reached this routine
     call mp_barrier()

! terminates mpi execution environment
     call mp_finalize()

# endif  /* MPI */

  end program dt_main
