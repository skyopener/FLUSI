subroutine Dump_Runtime_Backup(time,dt0,dt1,n1,it,nbackup,uk,nlk,workvis)
  use mpi_header 
  use share_vars
  implicit none
  real(kind=pr),intent(in) :: time,dt1,dt0
  integer,intent(inout) :: n1,nbackup,it
  complex(kind=pr),dimension(ca(1):cb(1),ca(2):cb(2),ca(3):cb(3),1:3),&
       intent(in) :: uk
  complex(kind=pr),dimension(ca(1):cb(1),ca(2):cb(2),ca(3):cb(3),1:3,0:1),&
       intent(in):: nlk
  real(kind=pr),dimension(ca(1):cb(1),ca(2):cb(2),ca(3):cb(3)),&
       intent(in) :: workvis
  integer :: filedesc,mpicode
  real(kind=pr) :: t1,tmp,tmp_local
  integer,dimension(MPI_STATUS_SIZE) :: mpistatus
  character(len=17) :: name
  character(len=1) :: name1

  t1=MPI_wtime()

  if(mpirank ==0) then
     write(*,'("*** info: time=",es8.2," dumping runtime_backup",i1," to disk....")') time,nbackup
  endif

  write(name1,'(I1)') nbackup

  ! ---------------------------------------------------------------------------
  ! first part: delete existing file, create new one, and save scalars
  ! ----------------------------------------------------------------------------
  call MPI_FILE_DELETE('runtime_backup'//name1,MPI_INFO_NULL,mpicode)
  call MPI_FILE_OPEN(MPI_COMM_WORLD,'runtime_backup'//name1,&
       MPI_MODE_WRONLY+MPI_MODE_CREATE,MPI_INFO_NULL,filedesc,mpicode)
  ! dump time 
  call MPI_FILE_WRITE_ALL(filedesc,time,1,mpireal,mpistatus,mpicode)
  ! dump n1(important when running AB2 scheme!!)
  call MPI_FILE_WRITE_ALL(filedesc,n1,1,mpiinteger,mpistatus,mpicode)
  call MPI_FILE_WRITE_ALL(filedesc,it,1,mpiinteger,mpistatus,mpicode)
  call MPI_FILE_WRITE_ALL(filedesc,nx,1,mpiinteger,mpistatus,mpicode)
  call MPI_FILE_WRITE_ALL(filedesc,ny,1,mpiinteger,mpistatus,mpicode)
  call MPI_FILE_WRITE_ALL(filedesc,nz,1,mpiinteger,mpistatus,mpicode)
  ! dump a few other parameters
  call MPI_FILE_WRITE_ALL(filedesc,(/dt0,dt1/),2,mpireal,mpistatus,mpicode)  
  call MPI_FILE_CLOSE(filedesc,mpicode) 
  ! close file(I really don't yet know why)


  !-----------------------------------------------------------------------------
  ! 2nd part: open file again and read all the fields, one by one.
  ! NOTE: you cannot store uk(:,:,:,1:3) directly, since the ordering
  ! won't match if you use different #cpu for writing and reading
  ! ----------------------------------------------------------------------------

  call MPI_FILE_OPEN(MPI_COMM_WORLD,'runtime_backup'//name1,&
       MPI_MODE_WRONLY+MPI_MODE_APPEND,MPI_INFO_NULL,filedesc,mpicode)
  call MPI_FILE_WRITE_ORDERED(filedesc,uk(:,:,:,1),product(cs),&
       mpicomplex,mpistatus,mpicode)
  call MPI_FILE_WRITE_ORDERED(filedesc,uk(:,:,:,2),product(cs),&
       mpicomplex,mpistatus,mpicode)
  call MPI_FILE_WRITE_ORDERED(filedesc,uk(:,:,:,3),product(cs),&
       mpicomplex,mpistatus,mpicode)
  call MPI_FILE_WRITE_ORDERED(filedesc,nlk(:,:,:,1,0),product(cs),&
       mpicomplex,mpistatus,mpicode)
  call MPI_FILE_WRITE_ORDERED(filedesc,nlk(:,:,:,2,0),product(cs),&
       mpicomplex,mpistatus,mpicode)
  call MPI_FILE_WRITE_ORDERED(filedesc,nlk(:,:,:,3,0),product(cs),&
       mpicomplex,mpistatus,mpicode)
  call MPI_FILE_WRITE_ORDERED(filedesc,nlk(:,:,:,1,1),product(cs),&
       mpicomplex,mpistatus,mpicode)
  call MPI_FILE_WRITE_ORDERED(filedesc,nlk(:,:,:,2,1),product(cs),&
       mpicomplex,mpistatus,mpicode)
  call MPI_FILE_WRITE_ORDERED(filedesc,nlk(:,:,:,3,1),product(cs),&
       mpicomplex,mpistatus,mpicode)
  call MPI_FILE_WRITE_ORDERED(filedesc,workvis,product(cs),mpireal,&
       mpistatus,mpicode)     
  call MPI_FILE_CLOSE(filedesc,mpicode)


  nbackup=1 - nbackup
  time_bckp=time_bckp + MPI_wtime() -t1
end subroutine Dump_Runtime_Backup




subroutine Read_Runtime_Backup(time,dt0,dt1,n1,it,uk,nlk,workvis)
  use mpi_header 
  use share_vars
  implicit none
  real(kind=pr),intent(out) :: time,dt1,dt0
  integer,intent(out) :: n1,it
  complex(kind=pr),dimension(ca(1):cb(1),ca(2):cb(2),ca(3):cb(3),1:3),&
       intent(out) :: uk
  complex(kind=pr),dimension(ca(1):cb(1),ca(2):cb(2),ca(3):cb(3),1:3,0:1),&
       intent(out):: nlk
  real(kind=pr),dimension(ca(1):cb(1),ca(2):cb(2),ca(3):cb(3)),&
       intent(out) :: workvis
  integer :: filedesc,mpicode,ibackup,nx_file,ny_file,nz_file
  real(kind=pr) :: time1
  integer,dimension(MPI_STATUS_SIZE) :: mpistatus
  integer(kind=MPI_OFFSET_KIND) :: mpioffset
  character(len=17) :: name
  character(len=1) :: name1 
  time=0.d0

  if(mpirank==0) then
     write(*,'("---------")')
     write(*,'(A)') "!!! warning: trying to resume a backup file"
  endif

  ! Read from backup file   
  do ibackup=0,1
     write(name1,'(I1)') ibackup

     call MPI_FILE_OPEN(MPI_COMM_WORLD,'runtime_backup'//name1,&
          MPI_MODE_RDONLY,MPI_INFO_NULL,filedesc,mpicode)

     if(mpicode == 0) then
        ! read time from backup file
        call MPI_FILE_READ_ALL(filedesc,time1,1,mpireal,mpistatus,mpicode)
        !------------------------------------
        ! if the backup is newer, read it
        !------------------------------------
        if(time1 > time) then
           time=time1
           if(mpirank == 0) then
              write(*,'("*** runtime_backup",i1," is at time=",es8.2)') &
                   ibackup,time
           endif

           call MPI_FILE_READ_ALL(filedesc,n1,1,mpiinteger,mpistatus,mpicode)
           call MPI_FILE_READ_ALL(filedesc,it,1,mpiinteger,mpistatus,mpicode)
           call MPI_FILE_READ_ALL(filedesc,nx_file,1,mpiinteger,mpistatus,&
                mpicode)
           call MPI_FILE_READ_ALL(filedesc,ny_file,1,mpiinteger,mpistatus,&
                mpicode)
           call MPI_FILE_READ_ALL(filedesc,nz_file,1,mpiinteger,mpistatus,&
                mpicode)
           call MPI_FILE_READ_ALL(filedesc,dt0,1,mpireal,mpistatus,mpicode)
           call MPI_FILE_READ_ALL(filedesc,dt1,1,mpireal,mpistatus,mpicode)

           if((nx_file/=nx).or.(ny_file/=ny).or.(nz_file/=nz) ) then
              call MPI_FILE_CLOSE(filedesc,mpicode)
              if(mpirank==0) write(*,*) &
                   "resolution of backup file and PARAMS.ini file do not match."
              stop
           endif

           if(mpirank == 0) then
              write(*,'("*** read n1=",i1," it=",i5," dt0=",es12.4," dt1=",es12.4)') n1,it,dt0,dt1
           endif

           call MPI_FILE_GET_POSITION(filedesc,mpioffset,mpicode)
           call MPI_FILE_SET_VIEW(filedesc,mpioffset,MPI_INTEGER,MPI_INTEGER,&
                "native",MPI_INFO_NULL,mpicode)
           !----------------------------
           ! read all the fields
           !----------------------------	  
           call MPI_FILE_READ_ORDERED(filedesc,uk(:,:,:,1),product(cs),&
                mpicomplex,mpistatus,mpicode)
           call MPI_FILE_READ_ORDERED(filedesc,uk(:,:,:,2),product(cs),&
                mpicomplex,mpistatus,mpicode)
           call MPI_FILE_READ_ORDERED(filedesc,uk(:,:,:,3),product(cs),&
                mpicomplex,mpistatus,mpicode)
           call MPI_FILE_READ_ORDERED(filedesc,nlk(:,:,:,1,0),product(cs),&
                mpicomplex,mpistatus,mpicode)
           call MPI_FILE_READ_ORDERED(filedesc,nlk(:,:,:,2,0),product(cs),&
                mpicomplex,mpistatus,mpicode)
           call MPI_FILE_READ_ORDERED(filedesc,nlk(:,:,:,3,0),product(cs),&
                mpicomplex,mpistatus,mpicode)
           call MPI_FILE_READ_ORDERED(filedesc,nlk(:,:,:,1,1),product(cs),&
                mpicomplex,mpistatus,mpicode)
           call MPI_FILE_READ_ORDERED(filedesc,nlk(:,:,:,2,1),product(cs),&
                mpicomplex,mpistatus,mpicode)
           call MPI_FILE_READ_ORDERED(filedesc,nlk(:,:,:,3,1),product(cs),&
                mpicomplex,mpistatus,mpicode)
           call MPI_FILE_READ_ORDERED(filedesc,workvis,product(cs),mpireal,&
                mpistatus,mpicode)	  
        endif
     endif
     call MPI_FILE_CLOSE(filedesc,mpicode)
  enddo


  if(time1 == 0) then
     if(mpirank == 0) then
	write(*,*) 'Unable to resume'
     endif
     stop
  endif

  if(mpirank == 0) then
     write(*,'("!!! DONE READING BACKUP (succes!)")') 
     write(*,'("---------")')
  endif

end subroutine Read_Runtime_Backup






subroutine save_fields_new(time,dt1,uk,u,vort,nlk,work)
  use mpi_header 
  use share_vars
  implicit none
  real(kind=pr),intent(in) :: time,dt1  
  complex(kind=pr),dimension(ca(1):cb(1),ca(2):cb(2),ca(3):cb(3),1:3),&
       intent(in) :: uk
  complex(kind=pr),dimension(ca(1):cb(1),ca(2):cb(2),ca(3):cb(3),1:3),&
       intent(out):: nlk
  real(kind=pr),dimension(ra(1):rb(1),ra(2):rb(2),ra(3):rb(3)),&
       intent(inout) :: work
  real(kind=pr),dimension(ra(1):rb(1),ra(2):rb(2),ra(3):rb(3),1:3),&
       intent(inout) :: vort,u  
  integer :: ix,iy,iz
  integer :: filedesc,mpicode
  integer,dimension(MPI_STATUS_SIZE) :: mpistatus
  character(len=17) :: name
  character(len=1) :: name1
  real(kind=pr) :: u_max_w,divu,divumax,t1=0.d0,t2=0.d0,t3=0.d0,t4=0.d0,&
       t5=0.d0,t6=0.d0
  real(kind=pr) :: kx,ky,kz,kx2,ky2,kz2,k_abs_2
  real(kind=pr),dimension(3) :: u_max,u_loc
  complex(kind=pr) :: qk

  ! -------------------------------------------------------
  ! - interface for SaveFile subroutine
  ! -------------------------------------------------------
  interface                                                                
     subroutine SaveFile(filename,field_out)
       use mpi_header ! Module incapsulates mpif.
       use share_vars
       implicit none
       integer,parameter :: pr_out=8   ! double precision array for output
       integer,parameter :: mpireal_out=MPI_DOUBLE_PRECISION 
       ! double precision array for output
       character(len=*),intent(in) :: filename
       real(kind=pr_out),dimension(:,:,:),intent(in) :: field_out
     end subroutine SaveFile

     subroutine SaveVTK(fname,u,vort,p) 
       use share_vars
       implicit none
       real(kind=pr),dimension(ra(1):rb(1),ra(2):rb(2),ra(3):rb(3)),&
            intent(in) :: p
       real(kind=pr),dimension(ra(1):rb(1),ra(2):rb(2),ra(3):rb(3),1:3),&
            intent(in) :: vort,u 
       character(len=*),intent(in) :: fname
     end subroutine SaveVTK

  end interface

  t1=MPI_wtime()

  !--Set up file name base 
  write(name,'(i5.5)') floor(time*100.d0)

  if(mpirank == 0 ) then 
     write(*,&
          '("*** info: Saving data.... time= ",es8.2,1x," saveflags= ",5(i1))')&
          time,iSaveVelocity,iSaveVorticity,iSavePress,iSaveMask,&
          iSaveSolidVelocity
  endif

  if((iSaveVelocity.ne.0).or.(iSaveVorticity.ne.0).or.(iSavePress.ne.0)) then
     !-----------------------------------------------
     !--Calculate ux and uy in physical space
     !-----------------------------------------------
     call cofitxyz(uk(:,:,:,1),u(:,:,:,1))
     call cofitxyz(uk(:,:,:,2),u(:,:,:,2))
     call cofitxyz(uk(:,:,:,3),u(:,:,:,3))
     !-----------------------------------------------
     !-- SaveVelocity
     !----------------------------------------------- 
     if(iSaveVelocity == 1) then
        call SaveFile('ux_'//trim(adjustl(name))//'.mpiio' ,u(:,:,:,1) )
        call SaveFile('uy_'//trim(adjustl(name))//'.mpiio' ,u(:,:,:,2) )
        call SaveFile('uz_'//trim(adjustl(name))//'.mpiio' ,u(:,:,:,3) )
     endif

     if((iSaveVorticity.ne.0).or.(iSavePress.ne.0)) then
        !-----------------------------------------------
        !-- compute vorticity
        !-----------------------------------------------
        do iy=ca(3),cb(3)  		! ky : 0..ny/2-1 ,then,-ny/2..-1     
           ky=scaley*dble(modulo(iy+ny/2,ny)-ny/2)     
           do ix=ca(2),cb(2)		! kx : 0..nx/2
              kx=scalex*dble(ix)                
              do iz=ca(1),cb(1) ! kz : 0..nz/2-1 ,then,-nz/2..-1           
                 kz=scalez*dble(modulo(iz+nz/2,nz)-nz/2)
                 nlk(iz,ix,iy,1)=dcmplx(0d0,1d0)*(ky*uk(iz,ix,iy,3) &
                      - kz*uk(iz,ix,iy,2) )
                 nlk(iz,ix,iy,2)=dcmplx(0d0,1d0)*(kz*uk(iz,ix,iy,1) &
                      - kx*uk(iz,ix,iy,3) )
                 nlk(iz,ix,iy,3)=dcmplx(0d0,1d0)*(kx*uk(iz,ix,iy,2) &
                      - ky*uk(iz,ix,iy,1) )
              enddo
           enddo
        enddo
        ! Transform it to physical space
        call cofitxyz(nlk(:,:,:,1),vort(:,:,:,1)) 
        call cofitxyz(nlk(:,:,:,2),vort(:,:,:,2))
        call cofitxyz(nlk(:,:,:,3),vort(:,:,:,3))
        !-----------------------------------------------
        !-- Save Vorticity
        !----------------------------------------------- 
        if(iSaveVorticity == 1) then
           call SaveFile('vorx_'//trim(adjustl(name))//'.mpiio',vort(:,:,:,1) )
           call SaveFile('vory_'//trim(adjustl(name))//'.mpiio',vort(:,:,:,2) )
           call SaveFile('vorz_'//trim(adjustl(name))//'.mpiio',vort(:,:,:,3) )
           work=sqrt(vort(:,:,:,1)**2 + vort(:,:,:,2)**2 +vort(:,:,:,3)**2 )
           call SaveFile('vorabs_'//trim(adjustl(name))//'.mpiio',work )
        endif

        if(iSavePress == 1) then  
           !-------------------------------------------------------------
           !-- Calculate omega x u(cross-product)
           !-- and transform the result into Fourier space 
           !-------------------------------------------------------------
           if((iPenalization == 1).and.(iMoving==0)) then
              work=u(:,:,:,2)*vort(:,:,:,3)&
                   -u(:,:,:,3)*vort(:,:,:,2)&
                   -u(:,:,:,1)*mask
              call coftxyz(work,nlk(:,:,:,1))
              work=u(:,:,:,3)*vort(:,:,:,1)&
                   -u(:,:,:,1)*vort(:,:,:,3)&
                   -u(:,:,:,2)*mask
              call coftxyz(work,nlk(:,:,:,2))
              work=u(:,:,:,1)*vort(:,:,:,2)&
                   -u(:,:,:,2)*vort(:,:,:,1)&
                   -u(:,:,:,3)*mask
              call coftxyz(work,nlk(:,:,:,3))
           elseif((iPenalization==1).and.(iMoving==1)) then
              work=u(:,:,:,2)*vort(:,:,:,3)&
                   -u(:,:,:,3)*vort(:,:,:,2)&
                   -(u(:,:,:,1)-us(:,:,:,1))*mask
              call coftxyz(work,nlk(:,:,:,1))
              work=u(:,:,:,3)*vort(:,:,:,1)&
                   -u(:,:,:,1)*vort(:,:,:,3)&
                   -(u(:,:,:,2)-us(:,:,:,2))*mask
              call coftxyz(work,nlk(:,:,:,2))
              work=u(:,:,:,1)*vort(:,:,:,2)&
                   -u(:,:,:,2)*vort(:,:,:,1)&
                   -(u(:,:,:,3)-us(:,:,:,3))*mask
              call coftxyz(work,nlk(:,:,:,3))
           else
              work=u(:,:,:,2)*vort(:,:,:,3) - u(:,:,:,3)*vort(:,:,:,2)
              call coftxyz(work,nlk(:,:,:,1))
              work=u(:,:,:,3)*vort(:,:,:,1) - u(:,:,:,1)*vort(:,:,:,3)
              call coftxyz(work,nlk(:,:,:,2))
              work=u(:,:,:,1)*vort(:,:,:,2) - u(:,:,:,2)*vort(:,:,:,1)
              call coftxyz(work,nlk(:,:,:,3))  
           endif
           !-------------------------------------------------------------
           !-- add pressure, new version
           !-- p=(i*kx*sxk + i*ky*syk + i*kz*szk) / k**2
           !-- note: we use rotational formulation: p is NOT the
           !physical pressure
           !-------------------------------------------------------------
           do iy=ca(3),cb(3)  ! ky : 0..ny/2-1 ,then, -ny/2..-1     
              ky=scaley*dble(modulo(iy+ny/2,ny)-ny/2)     
              ky2=ky*ky
              do ix=ca(2),cb(2)	! kx : 0..nx/2
                 kx=scalex*dble(ix)                
                 kx2=kx*kx
                 do iz=ca(1),cb(1) ! kz : 0..nz/2-1 ,then, -nz/2..-1           
                    kz     =scalez*dble(modulo(iz+nz/2,nz)-nz/2)
                    kz2    =kz*kz
                    k_abs_2=kx2+ky2+kz2
                    if(abs(k_abs_2) .ne. 0.0) then  
                       nlk(iz,ix,iy,1)=&
                            (kx*nlk(iz,ix,iy,1)&
                            +ky*nlk(iz,ix,iy,2)&
                            +kz*nlk(iz,ix,iy,3)&
                            )/k_abs_2
                    endif
                 enddo
              enddo
           enddo
           call cofitxyz(nlk(:,:,:,1),work)
           ! work contains total pressure, remove kinetic energy to
           ! get "physical" pressure
           work=work - 0.5d0*(&
                u(:,:,:,1)*u(:,:,:,1)&
                +u(:,:,:,2)*u(:,:,:,2)&
                +u(:,:,:,3)*u(:,:,:,3)&
                )
           call SaveFile('p_'//trim(adjustl(name))//'.mpiio',work(:,:,:) )

        endif
     endif
  endif

  !-----------------------------------------------
  !-- Save Mask
  !----------------------------------------------- 
  if((iSaveMask==1).and.(iPenalization==1)) then
     call SaveFile('mask_'//trim(adjustl(name))//'.mpiio',mask )
  endif
  if((iSaveSolidVelocity==1).and.(iPenalization==1).and.(iMoving==1)) then
     call SaveFile('usx_'//trim(adjustl(name))//'.mpiio',us(:,:,:,1) )
     call SaveFile('usy_'//trim(adjustl(name))//'.mpiio',us(:,:,:,2) )
     call SaveFile('usz_'//trim(adjustl(name))//'.mpiio',us(:,:,:,3) )
  endif






  !------------------------------------------------
  ! TEMP::: compute divergence
  !-----------------------------------------------
  ! compute max val of {|div(.)|/|.|} over entire domain
  !   do iz=ca(1),cb(1)
  !     kz=scalez*(modulo(iz+nz/2,nz) -nz/2)
  !     do iy=ca(3),cb(3)
  ! 	ky=scaley*(modulo(iy+ny/2,ny) -ny/2)
  ! 	do ix=ca(2),cb(2)
  ! 	  kx=scalex*ix
  ! 	  ! divergence of velocity field
  ! 	  nlk(iz,ix,iy,1)=dcmplx(0.d0,1.d0)*(kx*uk(iz,ix,iy,1)+ky*uk(iz,ix,iy,2)+kz*uk(iz,ix,iy,3))
  ! 	enddo
  !     enddo
  !   enddo
  !   ! now nlk(:,:,:,1) contains divergence field
  !   call cofitxyz(nlk(:,:,:,1),work)
  ! 
  !   write(name,'(i5.5)') floor(time*100.d0)
  !   call SaveFile ('divu_'//trim(adjustl(name))//'.mpiio' , work )


  time_save=time_save + MPI_wtime() - t1
end subroutine save_fields_new







subroutine SaveFile(filename,field_out)
  use mpi_header ! Module incapsulates mpif.
  use share_vars
  implicit none
  integer,parameter :: pr_out=8   ! double precision array for output
  integer,parameter :: mpireal_out=MPI_DOUBLE_PRECISION 
  ! double precision array for output
  character(len=*),intent(in) :: filename
  real(kind=pr_out),dimension(:,:,:),intent(in) :: field_out
  integer :: filedesc,mpicode
  integer,dimension(MPI_STATUS_SIZE) :: mpistatus

  ! modified: automatically stores in subfolder fields
  call MPI_FILE_DELETE('./fields/'//filename,MPI_INFO_NULL,mpicode)
  call MPI_FILE_OPEN(MPI_COMM_WORLD,'./fields/'//filename,&
       MPI_MODE_WRONLY+MPI_MODE_CREATE,MPI_INFO_NULL,filedesc,mpicode)
  call MPI_FILE_WRITE_ORDERED(filedesc,field_out,product(rs),mpireal_out,&
       mpistatus,mpicode)
  call MPI_FILE_CLOSE(filedesc,mpicode)    

end subroutine SaveFile
