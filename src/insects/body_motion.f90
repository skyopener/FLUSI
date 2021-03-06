!-------------------------------------------------------------------------------
! Body motion protocoll, different choices.
! Input:
!      time (self explanatory)
! Output:
!      Insect% psi:     roll angle
!      Insect%beta:     pitch angle
!      Insect%gamma:    yaw angle
!      Insect%psi_dt:   roll angular velocity
!      Insect%beta_dt:  pitch angular velocity
!      Insect%gamma_dt: yaw angular velocity
!      Insect%xc:       center of gravity coordinate
!      Insect%vc:       translational velocity of the body
! The actual motion depends on the choices in the parameter file, namely
! Insect%BodyMotion, and sub-parameters that may further precise a given motion
! protocoll
! Note that in new versions, all the angles and positions are stored in one
! datastructure, which is then the only output variable of this routine.
!-------------------------------------------------------------------------------
subroutine BodyMotion(time, Insect)
  use vars
  use kine
  implicit none

  real(kind=pr), intent(in) :: time
  type(diptera), intent(inout) :: Insect
  real(kind=pr) :: psi, beta, gamma, psi_dt, beta_dt, gamma_dt
  real(kind=pr) :: xc(1:3), vc(1:3)
  real(kind=pr) :: T,R

  ! the tag body_moves is used to draw the insect's body only once, if the body
  ! does not move (body_moves=="no"). For safety, we initialize the body as moving
  ! so if you forget to specify (body_moves=="no"), the body is drawn every time
  body_moves = "yes"


  select case (Insect%BodyMotion)
  case ("forward")
    psi = 0.d0
    !    beta = deg2rad(-15.0d0)
    beta = -deg2rad(Insect%body_pitch_const)
    gamma = deg2rad(180.d0)
    psi_dt = 0.d0
    beta_dt = 0.d0
    gamma_dt = 0.d0
    xc = (/x0, y0, z0/)
    vc = (/0.0, 0.0, 0.0/)
    body_moves = "no"

  case ("fixed")
    psi      = 0.d0
    beta     = 0.d0
    gamma    = 0.d0
    psi_dt   = 0.d0
    beta_dt  = 0.d0
    gamma_dt = 0.d0
    xc = (/0.5*xl, 0.5*yl,0.5*zl/)
    vc = (/0.0, 0.0, 0.0/)
    body_moves = "no"

  case ("fixed45")
    psi      = 0.d0
    beta     = deg2rad(-45.d0)
    gamma    = deg2rad(45.d0)
    psi_dt   = 0.d0
    beta_dt  = 0.d0
    gamma_dt = 0.d0

    xc = (/x0, y0, z0/)
    vc = (/0.0, 0.0, 0.0/)
    body_moves = "no"

  case ("x0y0z0")
    psi      = 0.0
    beta     = deg2rad(-45.d0)  ! Comparison with Maeda (Dmitry, 7 Nov 2013)
    gamma    = 0.0
    psi_dt   = 0.0
    beta_dt  = 0.0
    gamma_dt = 0.0

    xc = (/x0, y0, z0/)
    vc = (/0.0d0, 0.0d0, 0.0d0/)
    body_moves = "no"

  case ("wheeling")
    T = 20.0 ! time to do one turn
    R = 1.5  ! circle radius

    psi      = deg2rad(-30.d0)
    beta     = 0.0
    gamma    = (2.d0*pi/T )*time
    psi_dt   = 0.0
    beta_dt  = 0.0
    gamma_dt = 2.d0*pi/T

    xc = (/R*dcos(1.5d0*pi+gamma)+0.5d0*xl, R*dsin(1.5d0*pi+gamma)+0.5d0*yl, 0.5d0*zl/)
    vc = (/-R*dsin(1.5d0*pi+gamma)*gamma_dt, R*dcos(1.5d0*pi+gamma)*gamma_dt,0.d0/)

    body_moves = "yes"

  case ("hovering")
    psi      = 0.0
    !    beta     = deg2rad(-55.d0)
    beta = -deg2rad(Insect%body_pitch_const)
    !    beta     = deg2rad(-45.d0)  ! Comparison with Maeda (Dmitry, 7 Nov 2013)
    gamma    = deg2rad(45.d0)
    psi_dt   = 0.0
    beta_dt  = 0.0
    gamma_dt = 0.0

    xc = (/0.5*xl, 0.5*yl, zl-1.3d0/)  ! Dmitry, 26 Oct 2013
    !    xc = (/0.5*xl, 0.5*yl, zl-1.0d0/)  ! Dmitry, 30 Oct 2013 -one wing length from top
    !     xc = (/0.5*xl, 0.5*yl, zl-1.3d0/)  ! Dmitry, 30 Oct 2013 -1.3 wing length from top
    !    xc = (/0.5d0*xl, 0.5d0*yl, 0.8d0/)  ! Dmitry, 28 Oct 2013  - ground dist+0.3
    vc = (/0.0d0, 0.0d0, 0.0d0/)
    body_moves = "no"

  case ("flapper")  ! Comparison with Dickinson et al. (Dmitry, 19 Nov 2013)
    psi      = 0.0
    beta     = deg2rad(-90.d0)
    gamma    = deg2rad(45.d0)
    psi_dt   = 0.0
    beta_dt  = 0.0
    gamma_dt = 0.0

    xc = (/0.5*xl, 0.5*yl, zl-1.0d0/)
    vc = (/0.0d0, 0.0d0, 0.0d0/)
    body_moves = "no"

  case ("takeoff")  ! Takeoff kinematics read from file (Dmitry, 14 Nov 2013)
    body_moves = "yes"
    if (Insect%KineFromFile=="yes") then
      ! interpolate.
      call body_kine_interp(time,beta,xc(3),xc(1),beta_dt,vc(3),vc(1))
      ! x coordinate
      xc(1) = xc(1) + Insect%x_takeoff
      ! y coordinate
      xc(2) = 0.5d0*yl
      vc(2) = 0.0d0
      ! vertical position corrected
      xc(3) = xc(3) + Insect%z_takeoff
      ! convert pitch angle to flusi conventions
      beta = deg2rad(-beta)
      beta_dt = deg2rad(-beta_dt)
      ! zero heading and yaw
      psi = 0.0d0
      psi_dt = 0.0d0
      gamma = 0.0d0
      gamma_dt = 0.0d0

    elseif (Insect%KineFromFile=="simplified_dynamic") then
      ! interpolate. xc(3),xc(1),vc(3),vc(1) are unused!
      call body_kine_interp(time,beta,xc(3),xc(1),beta_dt,vc(3),vc(1))
      ! y coordinate
      xc(2) = 0.5d0*yl
      vc(2) = 0.0d0
      ! convert pitch angle to flusi conventions
      beta = deg2rad(-beta)
      beta_dt = deg2rad(-beta_dt)
      ! zero heading and yaw
      psi = 0.0d0
      psi_dt = 0.0d0
      gamma = 0.0d0
      gamma_dt = 0.0d0
      ! Use data from flight dynamics solver
      xc(1) = SolidDyn%var_new(1) + Insect%x_takeoff
      xc(3) = SolidDyn%var_new(2) + Insect%z_takeoff
      vc(1) = SolidDyn%var_new(3)
      vc(3) = SolidDyn%var_new(4)
    endif

  case ("free_flight")
    ! in this case, the position is dynamically computed, and quaternions are used
    body_moves = "yes"

  case default
    if (mpirank==0) then
      write(*,*) Insect%BodyMotion
      write(*,*) "body_motion.f90::BodyMotion: motion case (Insect%BodyMotion) undefined"
      call abort()
    endif
  end select

  if ((mpirank==0).and.(maxval(vc)>0.0d0).and.(body_moves=="no")) then
    write(*,*) "error in body_motion.f90: I found maxval(vc)>0 but the body_moves"
    write(*,*) "flag is set to no, which means we will draw the body only once"
    write(*,*) "This is probably not intented - you should look into it."
    call abort()
  endif


  ! save above values in the insect
  Insect%psi      = psi
  Insect%beta     = beta
  Insect%gamma    = gamma
  Insect%psi_dt   = psi_dt
  Insect%beta_dt  = beta_dt
  Insect%gamma_dt = gamma_dt
  Insect%xc_body  = xc
  Insect%vc_body  = vc


  ! for compability, we update the x0,y0,z0 also
  ! this is used e.g. for torque computation
  x0 = xc(1)
  y0 = xc(2)
  z0 = xc(3)

end subroutine BodyMotion
