!!!----------------------------------------------------------------------------
!!! project : jasmine
!!! program : atomic_make_sfmat
!!!           atomic_make_shmat
!!!           atomic_diag_shmat
!!!           atomic_rotate_fmat
!!!           atomic_make_construct
!!!           atomic_make_eliminate
!!!           atomic_mksectors
!!!           atomic_mkgood_sz
!!!           atomic_mkgood_jz
!!! source  : atomic_sector.f90
!!! type    : subroutines
!!! author  : yilin wang (email: qhwyl2006@126.com)
!!! history : 07/09/2014 by yilin wang
!!! purpose : make fmat
!!! status  : unstable
!!! comment : these subroutines are based on Dr. LiangDu's (duleung@gmail.com) 
!!!           atomic program
!!!----------------------------------------------------------------------------

!!>>> atomic_make_sfmat: build fmat for good quantum numbers (GQNs) algorithm
  subroutine atomic_make_sfmat()
     use constants, only : zero
     use control, only : norbs

     use m_basis_fullspace, only : dec_basis, index_basis
     use m_glob_sectors, only : nsectors, sectors
     use m_sector, only : alloc_one_fmat
  
     implicit none
  
! local variables
! loop index 
     integer :: iorb
     integer :: ifermi
     integer :: isect, jsect
     integer :: ibas, jbas
     integer :: i

! sign change due to commute relation
     integer :: isgn

! auxiliary integer variables
     integer :: jold, jnew
  
! loop over all the sectors
     do isect=1, nsectors
! loop over all the orbitals
         do iorb=1,norbs
! loop over the creation and annihilation fermion operators
             do ifermi=0, 1 
                 jsect = sectors(isect)%next_sector(iorb, ifermi) 
                 if (jsect == -1) cycle
! allocate memory for fmat
                 sectors(isect)%myfmat(iorb, ifermi)%n = sectors(jsect)%ndim
                 sectors(isect)%myfmat(iorb, ifermi)%m = sectors(isect)%ndim
                 call alloc_one_fmat(sectors(isect)%myfmat(iorb, ifermi))
                 sectors(isect)%myfmat(iorb,ifermi)%item = zero
! build fmat
                 do jbas=1, sectors(isect)%ndim
                     jold = dec_basis(sectors(isect)%mybasis(jbas))
! for creation fermion operator
                     if (ifermi == 1 .and. ( btest(jold, iorb-1) .eqv. .false. )) then
                         call atomic_make_construct(iorb, jold, jnew, isgn)
! for annihilation fermion operator
                     elseif (ifermi == 0 .and. ( btest(jold, iorb-1) .eqv. .true. )) then
                         call atomic_make_eliminate(iorb, jold, jnew, isgn)
                     else
                         cycle
                     endif
                     ibas = index_basis(jnew)
                     do i=1, sectors(jsect)%ndim 
                         if (ibas == sectors(jsect)%mybasis(i)) then
                             ibas = i
                             sectors(isect)%myfmat(iorb, ifermi)%item(ibas, jbas) = dble(isgn)
                             exit
                         endif
                     enddo
                 enddo  ! over jbas={1, sectors(isect)%ndim} loop
! roate fmat to atomic eigenstates basis
                 call atomic_rotate_fmat(sectors(jsect)%ndim, sectors(isect)%ndim, sectors(jsect)%myeigvec, &
                     sectors(isect)%myfmat(iorb, ifermi)%item, sectors(isect)%myeigvec)
             enddo ! over ifermi={0,1} loop
         enddo ! over iorb={1, norbs} loop
     enddo ! over isect={1,nsectors} loop
  
     return
  end subroutine atomic_make_sfmat

!!>>> atomic_make_shmat: make Hamiltonian for each sector one by one
  subroutine atomic_make_shmat()
     use constants, only : dp, czero, epst
     use control, only : norbs, ncfgs

     use m_basis_fullspace, only : dec_basis, index_basis, bin_basis
     use m_spmat, only : eimpmat, cumat
     use m_glob_sectors, only : nsectors, sectors
  
     implicit none
  
! local variables
! loop index
     integer :: i
     integer :: isect
     integer :: ibas, jbas
     integer :: alpha, betta
     integer :: delta, gamma

! sign change due to fermion anti-commute relation
     integer :: isgn

! new basis state after four fermion operation
     integer :: knew

! binary form of a Fock state
     integer :: code(norbs)

! whether in some sector
     logical :: insect
      
     do isect=1, nsectors
         sectors(isect)%myham = czero
  
!---------------------------------------------------------------------------------------!
! two fermion operators
         do jbas=1,sectors(isect)%ndim
  
             alploop: do alpha=1,norbs
             betloop: do betta=1,norbs
  
                 isgn = 0
                 knew = dec_basis(sectors(isect)%mybasis(jbas))
                 code(1:norbs) = bin_basis(1:norbs, sectors(isect)%mybasis(jbas))
  
                 if ( abs(eimpmat(alpha, betta)) .lt. epst ) cycle
  
! simulate one annihilation operator
                 if (code(betta) == 1) then
                     do i=1,betta-1
                         if (code(i) == 1) isgn = isgn + 1
                     enddo 
                     code(betta) = 0
  
! simulate one creation operator
                     if (code(alpha) == 0) then
                         do i=1,alpha-1
                             if (code(i) == 1) isgn = isgn + 1
                         enddo
                         code(alpha) = 1
  
! determine the row number and hamiltonian matrix elememt
                         knew = knew - 2**(betta-1)
                         knew = knew + 2**(alpha-1)
                         isgn  = mod(isgn, 2)
                         ibas = index_basis(knew)
                         if (ibas == 0) then
                             call s_print_error('atomic_mkhmat_sectors', &
                                                'error while determining row1')
                         endif
  
                         insect = .false.
                         do i=1, sectors(isect)%ndim 
                             if (sectors(isect)%mybasis(i) == ibas) then
                                 ibas = i
                                 insect = .true.
                             endif
                         enddo
  
                         if (insect) then
                             sectors(isect)%myham(ibas,jbas) = sectors(isect)%myham(ibas,jbas) + &
                                                            eimpmat(alpha, betta) * (-1.0d0)**isgn 
                         endif
  
                     endif ! back if (code(alpha) == 0) block
                 endif ! back if (betta == 1) block
  
             enddo betloop ! over betta={1,norbs} loop
             enddo alploop ! over alpha={1,norbs} loop
         enddo ! over jbas={1,sectors(isect)%ndim} loop
!---------------------------------------------------------------------------------------!
  
!---------------------------------------------------------------------------------------!
! four fermion operators
         do jbas=1,sectors(isect)%ndim
             alphaloop : do alpha=1,norbs
             bettaloop : do betta=1,norbs
             gammaloop : do gamma=1,norbs
             deltaloop : do delta=1,norbs
  
                 isgn = 0
                 knew = dec_basis(sectors(isect)%mybasis(jbas))
                 code(1:norbs) = bin_basis(1:norbs, sectors(isect)%mybasis(jbas))
  
! very important if single particle basis has been rotated
                 if ((alpha .eq. betta) .or. (delta .eq. gamma)) cycle
                 if ( abs(cumat(alpha,betta,delta,gamma)) .lt. epst ) cycle
  
! simulate two annihilation operators
                 if ((code(delta) == 1) .and. (code(gamma) == 1)) then
                     do i=1,gamma-1
                         if(code(i) == 1) isgn = isgn + 1
                     enddo 
                     code(gamma) = 0
  
                     do i=1,delta-1
                         if(code(i) == 1) isgn = isgn + 1
                     enddo 
                     code(delta) = 0
  
! simulate two creation operators
                     if ((code(alpha) == 0) .and. (code(betta) == 0)) then
                         do i=1,betta-1
                             if(code(i) == 1) isgn = isgn + 1
                         enddo 
                         code(betta) = 1
  
                         do i=1,alpha-1
                             if(code(i) == 1) isgn = isgn + 1
                         enddo
                         code(alpha) = 1
  
! determine the row number and hamiltonian matrix elememt
                         knew = knew - 2**(gamma-1) - 2**(delta-1)
                         knew = knew + 2**(betta-1) + 2**(alpha-1)
                         ibas = index_basis(knew)
                         isgn = mod(isgn, 2)
                         if (ibas == 0) then
                             call s_print_error('atomic_mkhmat_sectors', &
                                                'error while determining row3')
                         endif
  
                         insect = .false.
                         do i=1, sectors(isect)%ndim 
                             if (sectors(isect)%mybasis(i) == ibas) then
                                 ibas = i
                                 insect = .true.
                             endif
                         enddo
  
                         if (insect) then
                             sectors(isect)%myham(ibas,jbas) = sectors(isect)%myham(ibas,jbas) + &
                                                  cumat(alpha,betta,delta,gamma) * (-1.0d0)**isgn
                         endif
  
                     endif ! back if ((code(delta) == 1) .and. (code(gamma) == 1)) block
                 endif ! back if ((code(alpha) == 0) .and. (code(betta) == 0)) block
  
             enddo deltaloop ! over delta={gamma+1,norbs} loop
             enddo gammaloop ! over gamma={1,norbs-1} loop
             enddo bettaloop ! over betta={alpha+1,norbs} loop
             enddo alphaloop ! over alpha={1,norbs-1} loop
         enddo ! over jbas={1,sectors(isect)%ndim} loop
!---------------------------------------------------------------------------------------!
  
     enddo ! over i={1, nsectors}
  
     return
  end subroutine atomic_make_shmat

!!>>> atomic_diag_shmat: diagonalize the Hamiltonian for each sector one by one
  subroutine atomic_diag_shmat()
     use constants, only : dp
     use m_glob_sectors, only : nsectors, sectors
  
     implicit none
  
! local variables
     integer :: i

     real(dp), allocatable :: hmat(:,:)
     
     do i=1, nsectors
         allocate( hmat(sectors(i)%ndim, sectors(i)%ndim) )
         hmat = real( sectors(i)%myham )
         call s_eig_sy( sectors(i)%ndim, sectors(i)%ndim, hmat, sectors(i)%myeigval, sectors(i)%myeigvec )
         deallocate( hmat )
     enddo
  
     return
  end subroutine atomic_diag_shmat






!!>>> atomic_mksectors: determine all the sectors for good quantum numbers
!!>>> a sector consists of some many particle Fock states labeled by 
!!>>> good quantum numbers
  subroutine atomic_mksectors()
     use constants, only : mytmp, zero
     use control, only : nband, norbs, ncfgs, ictqmc

     use m_basis_fullspace, only : dim_sub_n, bin_basis
     use m_sector, only : alloc_one_sector
     use m_glob_sectors, only : nsectors, sectors, alloc_m_glob_sectors
     use m_glob_sectors, only : max_dim_sect, ave_dim_sect
  
     implicit none
  
! local variables
! the maximum number of sectors
     integer :: max_nsect

! the maximum dimension of each sector
     integer :: max_ndim

! the sz value for each orbital
     integer :: orb_good_sz(norbs)
     integer :: orb_good_jz(norbs)

! good quantum number N, Sz, PS for each Fock state
     integer, allocatable :: fock_good_ntot(:)
     integer, allocatable :: fock_good_sz(:)
     integer, allocatable :: fock_good_jz(:)
     integer, allocatable :: fock_good_ps(:)

! good quantum number N, Sz, PS for each sector
     integer, allocatable :: sect_good_ntot(:)
     integer, allocatable :: sect_good_sz(:)
     integer, allocatable :: sect_good_jz(:)
     integer, allocatable :: sect_good_ps(:)

! dimension of each sector
     integer, allocatable :: ndims(:)

! sector basis index
     integer, allocatable :: sector_basis(:,:)

! number of sectors
     integer :: nsect

! which sector point to
     integer :: which_sect

! a temp binary form of Fock basis
     integer :: tmp_basis(norbs)

! total electrons
     integer :: myntot

! Sz value
     integer :: mysz

! Jz value
     integer :: myjz

! PS value
     integer :: myps

! a counter
     integer :: counter

! index of Fock basis
     integer :: ibasis

! loop index
     integer :: i,j,k,l

! can point to next sector
     logical :: can  
  
! allocate status
     integer :: istat

     max_nsect = ncfgs
     max_ndim = ncfgs

! allocate memory
     allocate( fock_good_ntot(ncfgs),             stat=istat )
     allocate( fock_good_sz(ncfgs),               stat=istat )
     allocate( fock_good_ps(ncfgs),               stat=istat )
     allocate( fock_good_jz(ncfgs),               stat=istat )

     allocate( sect_good_ntot(max_nsect),         stat=istat )
     allocate( sect_good_sz(max_nsect),           stat=istat )
     allocate( sect_good_ps(max_nsect),           stat=istat )
     allocate( sect_good_jz(max_nsect),           stat=istat )

     allocate( ndims(max_nsect),                  stat=istat )
     allocate( sector_basis(max_ndim, max_nsect), stat=istat )
  
! check status
     if ( istat /= 0 ) then
         call s_print_error('atomic_mksectors','can not allocate enough memory')
     endif

!----------------------------------------------------------------
! make good_sz and good_jz
     orb_good_sz = 0
     orb_good_jz = 0
     call atomic_mkgood_sz(orb_good_sz)
     
! jz only valid for nband==3, 5, 7
     if (nband == 3 .or. nband == 5 .or. nband == 7 ) then
         call atomic_mkgood_jz(orb_good_jz)
     endif

! build good quantum numbers for each Fock state
     counter = 0
     fock_good_ntot = 0
     fock_good_sz = 0
     fock_good_ps = 0
     fock_good_jz = 0
! loop over all number of total electrons
     do i=0, norbs
! loop over each state 
         do j=1, dim_sub_n(i)
             counter = counter + 1
! build N
             fock_good_ntot(counter) = i
! build Sz
             mysz = 0
             do k=1, norbs
                 mysz = mysz + orb_good_sz(k) * bin_basis(k, counter) 
             enddo
             fock_good_sz(counter) = mysz
! build Jz
              myjz = 0
              do k=1, norbs
                  myjz = myjz + orb_good_jz(k) * bin_basis(k, counter) 
              enddo
              fock_good_jz(counter) = myjz
! build PS number
             do k=1, nband
                 fock_good_ps(counter) = fock_good_ps(counter) + &
                 2**k * (bin_basis(2*k-1,counter) - bin_basis(2*k,counter))**2
             enddo
         enddo  
     enddo
!----------------------------------------------------------------
  
!----------------------------------------------------------------
! loop over all the Fock states to determine sectors
     nsect = 0
     ndims = 0
     sector_basis = 0
     do i=1, ncfgs    
         myntot = fock_good_ntot(i)
         if (ictqmc == 3 .or. ictqmc == 4) then
             mysz   = fock_good_sz(i)
         endif
         if (ictqmc == 4) then
             myps   = fock_good_ps(i)
         endif
         if (ictqmc == 5) then
             myjz   = fock_good_jz(i)
         endif

         if (nsect==0) then
             sect_good_ntot(1) = myntot
             if (ictqmc == 3 .or. ictqmc == 4) then
                 sect_good_sz(1)   = mysz
             endif
             if (ictqmc == 4) then
                 sect_good_ps(1)   = myps
             endif
             if ( ictqmc == 5 ) then
                 sect_good_jz(1)   = myjz
             endif

             nsect = nsect + 1
             ndims(1) = ndims(1) + 1 
             sector_basis(ndims(1),1) = i
         else
! loop over the exists sectors
             which_sect = -1
             do j=1, nsect
! compare two sectors
                 select case(ictqmc)
                     case(2)
                         if ( sect_good_ntot(j) == myntot ) then
                             which_sect = j
                             EXIT
                         endif
                     case(3)
                         if ( sect_good_ntot(j) == myntot .and. sect_good_sz(j) == mysz ) then
                             which_sect = j
                             EXIT
                         endif
                     case(4)
                         if ( sect_good_ntot(j) == myntot .and. sect_good_sz(j) == mysz &
                             .and. sect_good_ps(j) == myps) then
                             which_sect = j
                             EXIT
                         endif
                     case(5)
                         if ( sect_good_ntot(j) == myntot .and. sect_good_jz(j) == myjz ) then
                             which_sect = j
                             EXIT
                         endif
                 end select
             enddo  ! over j={1, nsect} loop
! new sector
             if( which_sect == -1 ) then
                 nsect = nsect + 1
                 sect_good_ntot(nsect) = myntot
                 if (ictqmc == 3 .or. ictqmc == 4) then
                     sect_good_sz(nsect)   = mysz
                 endif
                 if (ictqmc == 4) then
                     sect_good_ps(nsect)   = myps
                 endif
                 if (ictqmc == 5) then
                     sect_good_jz(nsect)   = myjz
                 endif
                 ndims(nsect) = ndims(nsect) + 1
                 sector_basis(ndims(nsect), nsect) = i
! old sector
             else
                 ndims(which_sect) = ndims(which_sect) + 1 
                 sector_basis(ndims(which_sect), which_sect) = i
             endif
         endif ! back to if (nsect == 0) then block 
     enddo ! over i={1,ncfgs} loop
!----------------------------------------------------------------
  
!----------------------------------------------------------------
! after we know how many sectors and the dimension of each sector,
! we can allocate memory for global variables for sectors
     max_dim_sect = 0
     ave_dim_sect = zero
     nsectors = nsect
     call alloc_m_glob_sectors()
! now we will build each sector
     counter = 1
     do i=1, nsect
         sectors(i)%ndim = ndims(i)
         sectors(i)%nelectron = sect_good_ntot(i)
         sectors(i)%nops = norbs
         sectors(i)%istart = counter 
         counter = counter + ndims(i)
! allocate memory for each sector 
         call alloc_one_sector( sectors(i) )  
! set basis for each sector
         do j=1, ndims(i)
             sectors(i)%mybasis(j) = sector_basis(j,i) 
         enddo
     enddo
!----------------------------------------------------------------
  
!----------------------------------------------------------------
! make next_sector index
! loop over all the sectors
     do i=1, nsectors
! loop over all the orbtials
         do j=1, norbs 
! loop over creation and annihilation fermion operators
             do k=0,1 
                 which_sect = -1
! we should check each state in this sector
                 can = .false.
                 do l=1, sectors(i)%ndim
                     ibasis = sectors(i)%mybasis(l)
! for creation fermion operator
                     if (k==1 .and. bin_basis(j,ibasis) == 0) then
                         tmp_basis = bin_basis(:, ibasis)
                         can = .true.
                         exit
! for annihilation fermion operator
                     elseif (k==0 .and. bin_basis(j, ibasis) == 1) then
                         tmp_basis = bin_basis(:, ibasis)
                         can = .true. 
                         exit
                     endif 
                 enddo 
  
                 if (can == .true.) then
                     select case(ictqmc)
                         case(2)
                             if (k==1) then
                                 myntot = sect_good_ntot(i) + 1
                             else
                                 myntot = sect_good_ntot(i) - 1
                             endif
! loop over all sectors to see which sector it will point to 
                             do l=1, nsectors
                                 if (sect_good_ntot(l) == myntot ) then
                                     which_sect = l
                                     exit 
                                 endif 
                             enddo 

                         case(3)
                             if (k==1) then
                                 myntot = sect_good_ntot(i) + 1
                                 mysz   = sect_good_sz(i) + orb_good_sz(j)
                             else
                                 myntot = sect_good_ntot(i) - 1
                                 mysz   = sect_good_sz(i) - orb_good_sz(j)
                             endif
! loop over all sectors to see which sector it will point to 
                             do l=1, nsectors
                                 if (sect_good_ntot(l) == myntot .and. sect_good_sz(l) == mysz ) then
                                     which_sect = l
                                     exit 
                                 endif 
                             enddo 

                         case(4)
                             if (k==1) then
                                 myntot = sect_good_ntot(i) + 1
                                 mysz   = sect_good_sz(i) + orb_good_sz(j)
                                 tmp_basis(j) = 1
                             else
                                 myntot = sect_good_ntot(i) - 1
                                 mysz   = sect_good_sz(i) - orb_good_sz(j)
                                 tmp_basis(j) = 0
                             endif
! calculate new PS number
                             myps = 0
                             do l=1, nband
                                 myps = myps + 2**l * ( tmp_basis(2*l-1) - tmp_basis(2*l) )**2
                             enddo
! loop over all sectors to see which sector it will point to 
                             do l=1, nsectors
                                 if (sect_good_ntot(l) == myntot .and. sect_good_sz(l) == mysz &
                                     .and. sect_good_ps(l) == myps) then
                                     which_sect = l
                                     exit 
                                 endif 
                             enddo 

                         case(5)
                             if (k==1) then
                                 myntot = sect_good_ntot(i) + 1
                                 myjz   = sect_good_jz(i) + orb_good_jz(j)
                             else
                                 myntot = sect_good_ntot(i) - 1
                                 myjz   = sect_good_jz(i) - orb_good_jz(j)
                             endif
! loop over all sectors to see which sector it will point to 
                             do l=1, nsectors
                                 if (sect_good_ntot(l) == myntot .and. sect_good_jz(l) == myjz ) then
                                     which_sect = l
                                     exit 
                                 endif 
                             enddo 
                     end select ! back select case(ictqmc) block
                 endif  ! back to if (can == .true.) block
                 sectors(i)%next_sector(j,k) = which_sect 
             enddo ! over k={0,1} loop
         enddo ! over j={1,norbs} loop
     enddo ! over i={1, nsectors} loop
!----------------------------------------------------------------
  
!----------------------------------------------------------------
! dump sector information for reference
! calculate the maximum and average dimensions of sectors
     max_dim_sect = 0
     counter = 0 
     do i=1, nsectors
         if (sectors(i)%ndim > max_dim_sect) max_dim_sect = sectors(i)%ndim
         counter = counter + sectors(i)%ndim
     enddo
     ave_dim_sect = real(counter) / real(nsectors)
  
     open(mytmp, file='atom.sector.dat')
     write(mytmp, '(a,I10)')    '#number_sectors : ', nsectors
     write(mytmp, '(a,I10)')    '#max_dim_sectors: ', max_dim_sect
     write(mytmp, '(a,F16.8)')  '#ave_dim_sectors: ', ave_dim_sect
 
     select case(ictqmc)
         case(2)
             write(mytmp, '(a)') '#      i | electron(i) |     ndim(i) |           j |   fock_basis(j,i) |  '
             do i=1, nsectors
                 do j=1, sectors(i)%ndim
                     write(mytmp,'(I10,4X,I10,4X,I10,4X,I10,8X, 14I1)') i, sectors(i)%nelectron, &
                                           sectors(i)%ndim, j, bin_basis(:, sectors(i)%mybasis(j)) 
                 enddo
             enddo

         case(3)
             write(mytmp, '(a)') '#      i | electron(i) |       Sz(i) |     ndim(i) |           j |   fock_basis(j,i) |  '
             do i=1, nsectors
                 do j=1, sectors(i)%ndim
                     write(mytmp,'(I10,4X,I10,4X,I10,4X,I10,4X,I10,8X,14I1)') i, sect_good_ntot(i),&
                          sect_good_sz(i), sectors(i)%ndim, j, bin_basis(:, sectors(i)%mybasis(j)) 
                 enddo
             enddo

         case(4)
             write(mytmp, '(a)') '#      i | electron(i) |       Sz(i) |       PS(i) |     nd&
                                 im(i) |           j |    fock_basis(j,i) |  '
             do i=1, nsectors
                 do j=1, sectors(i)%ndim
                     write(mytmp,'(I10,4X,I10,4X,I10,4X,I10,4X,I10,4X,I10,8X,14I1)') i, sect_good_ntot(i), &
                   sect_good_sz(i), sect_good_ps(i), sectors(i)%ndim, j, bin_basis(:, sectors(i)%mybasis(j)) 
                 enddo
             enddo

          case(5)
              write(mytmp, '(a)') '#      i | electron(i) |       Jz(i) |     ndim(i) |           j |   fock_basis(j,i) |  '
              do i=1, nsectors
                  do j=1, sectors(i)%ndim
                      write(mytmp,'(I10,4X,I10,4X,I10,4X,I10,4X,I10,8X,14I1)') i, sect_good_ntot(i),&
                           sect_good_jz(i), sectors(i)%ndim, j, bin_basis(:, sectors(i)%mybasis(j)) 
                  enddo
              enddo
     end select ! back select case(ictqmc) block

     close(mytmp)
!----------------------------------------------------------------
  
! free memeory
     if (allocated(fock_good_ntot)) deallocate(fock_good_ntot)
     if (allocated(fock_good_sz))   deallocate(fock_good_sz)
     if (allocated(fock_good_jz))   deallocate(fock_good_jz)
     if (allocated(fock_good_ps))   deallocate(fock_good_ps)

     if (allocated(sect_good_ntot)) deallocate(sect_good_ntot)
     if (allocated(sect_good_sz))   deallocate(sect_good_sz)
     if (allocated(sect_good_jz))   deallocate(sect_good_jz)
     if (allocated(sect_good_ps))   deallocate(sect_good_ps)

     if (allocated(ndims))          deallocate(ndims)
     if (allocated(sector_basis))   deallocate(sector_basis)
  
     return
  end subroutine atomic_mksectors
 
!!>>> atomic_mkgood_sz: make sz for each orbital
  subroutine atomic_mkgood_sz(good_sz)
     use control, only : norbs
  
     implicit none
  
! external variables
     integer, intent(out) :: good_sz(norbs)

! local variables
     integer :: i
  
     do i=1, norbs
         if (mod(i,2) /= 0 ) then
             good_sz(i) = 1
         else
             good_sz(i) = -1
         endif
     enddo
  
     return
  end subroutine atomic_mkgood_sz
  
!>>> atomic_mkgood_jz: make jz for each orbital
  subroutine atomic_mkgood_jz(good_jz)
     use control, only : nband, norbs
  
     implicit none
  
! external variables
     integer, intent(out) :: good_jz(norbs)
  
     if (nband == 3) then
! j=1/2
         good_jz(1) = -1
         good_jz(2) =  1
! j=3/2
         good_jz(3) = -3
         good_jz(4) = -1
         good_jz(5) =  1
         good_jz(6) =  3
     elseif (nband == 5) then
! j=3/2
         good_jz(1) = -3
         good_jz(2) = -1
         good_jz(3) =  1
         good_jz(4) =  3
! j=5/2
         good_jz(5) = -5
         good_jz(6) = -3
         good_jz(7) = -1
         good_jz(8) =  1
         good_jz(9) =  3
         good_jz(10)=  5
     elseif (nband == 7) then
! j=5/2
         good_jz(1) = -5
         good_jz(2) = -3
         good_jz(3) = -1
         good_jz(4) =  1
         good_jz(5) =  3
         good_jz(6) =  5
! j=7/2
         good_jz(7) = -7
         good_jz(8) = -5
         good_jz(9) = -3
         good_jz(10)= -1
         good_jz(11)=  1
         good_jz(12)=  3
         good_jz(13)=  5
         good_jz(14)=  7
     else
         call s_print_error('atomic_make_good_jz', &
            'not implemented for this norbs value !')
     endif
  
     return
  end subroutine atomic_mkgood_jz


!!>>> atomic_rotate_fmat: rotate fmat from Fock basis to eigenstates basis
  subroutine atomic_rotate_fmat(ndimx, ndimy, amat, bmat, cmat)
     use constants, only: dp, zero, one
     implicit none
     
! external variables
     integer, intent(in) :: ndimx
     integer, intent(in) :: ndimy
     real(dp), intent(in) :: amat(ndimx, ndimx)
     real(dp), intent(inout) :: bmat(ndimx, ndimy)
     real(dp), intent(in) :: cmat(ndimy, ndimy)
  
! local variables
     real(dp) :: tmp_mat(ndimx, ndimy)
     real(dp) :: amat_t(ndimx, ndimx)
     real(dp) :: alpha
     real(dp) :: betta
  
     amat_t = transpose(amat)
     tmp_mat = zero
  
     alpha = one; betta = zero
     call dgemm('N', 'N', ndimx, ndimy, ndimy, &
                           alpha, bmat, ndimx, &
                                  cmat, ndimy, &
                        betta, tmp_mat, ndimx  )
  
     alpha = one; betta = zero
     call dgemm('N', 'N', ndimx, ndimy, ndimx, &
                         alpha, amat_t, ndimx, &
                               tmp_mat, ndimx, &
                           betta, bmat, ndimx  )
  
  
     return
  end subroutine atomic_rotate_fmat

!!>>> atomic_make_construct: create one electron on ipos 
!!>>> of |jold> to deduce |jnew>
  subroutine atomic_make_construct(ipos, jold, jnew, isgn)
     implicit none
  
! external argument
! position number (serial number of orbit)
     integer, intent(in) :: ipos
  
! old Fock state and new Fock state
     integer, intent(in ):: jold
     integer, intent(out):: jnew
  
! sgn due to anti-commute relation between fernions
     integer, intent(out):: isgn
  
! local variables
! loop index over orbit
     integer :: iorb
  
     if (btest(jold, ipos-1) .eqv. .true.) then
         call s_print_error("atomic_construct", "severe error happened")
     endif
  
     isgn = 0
     do iorb=1,ipos-1
        if (btest(jold, iorb-1)) isgn = isgn + 1
     enddo
     isgn = mod(isgn, 2)
  
     isgn = (-1)**isgn
     jnew = jold + 2**(ipos-1)
  
     return
  end subroutine atomic_make_construct

!!>>> atomic_make_eliminate: destroy one electron on ipos 
!!>>> of |jold> to deduce |jnew>
  subroutine atomic_make_eliminate(ipos, jold, jnew, isgn)
      implicit none
  
! external argument
! position number (serial number of orbit)
      integer, intent(in)  :: ipos
  
! old Fock state and new Fock state
      integer, intent(in ) :: jold
      integer, intent(out) :: jnew
  
! sgn due to anti-commute relation between fernions
      integer, intent(out) :: isgn
  
! local variables
! loop index
      integer :: iorb
  
      if (btest(jold, ipos-1) .eqv. .false.) then
          call s_print_error("atomic_eliminate", "severe error happened")
      endif 
  
      isgn = 0
      do iorb=1,ipos-1
          if (btest(jold, iorb-1)) isgn = isgn + 1
      enddo
      isgn = mod(isgn, 2)
  
      isgn = (-1)**isgn
      jnew = jold - 2**(ipos-1)
  
      return
  end subroutine atomic_make_eliminate



