!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! module global
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


    module global

    implicit none
    public
    real*8, allocatable :: V(:,:),P(:,:),G(:,:)
    integer, allocatable :: indxg(:)
    integer :: ng
    
    end module global

    
    !module mymkl 
    !include 'mkl.fi' 
    !end module mymkl 

    
    
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! module funcs
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    module bigfuncs

    use global
    !use mymkl
    
    implicit none
    
    !include 'mkl.fi'
    
    contains

    function crossprod(a,b) result(c)
    implicit none
    external dgemm
    real*8, dimension(:,:), intent(in)  :: a,b
    real*8, allocatable :: c(:,:)
    !real*8 :: c(size(a,1),size(b,2))
    allocate(c(size(a,1),size(b,2)))
    call dgemm('n', 'n', size(a,1), size(b,2), size(a,2), 1.0D0, a, size(a,1), b, size(a,2), 0.0D0, c, size(a,1))
    end function crossprod

    function matvec(a,b) result(c)
    implicit none
    external dgemm
    real*8, dimension(:,:), intent(in)  :: a
    real*8, dimension(:), intent(in)  :: b
    real*8 :: c(size(a,1))
    call dgemm('n', 'n', size(a,1), 1, size(a,2), 1.0D0, a, size(a,1), b, size(a,2), 0.0D0, c, size(a,1))
    end function matvec

    function diag(a) result(b)
    implicit none
    real*8, dimension(:,:), intent(in)  :: a
    real*8 :: b(size(a,1))
    integer :: i
    do i=1,size(a,1)
      b(i) = a(i,i)
    enddo
    end function diag

    function inverse(a) result(b)
    implicit none
    external dpotrf, dpotri
    real*8, dimension(:,:), intent(in)  :: a
    real*8 :: b(size(a,1),size(a,2))
    integer :: info,i,j
    info=0
    call dpotrf('U',size(a,1),a,size(a,1),info)             ! cholesky decompostion of a
    call dpotri('U',size(a,1),a,size(a,1),info)             ! inverse of a
    ! copy to lower
    b=a
    do i=1,size(a,1)
      do j=i,size(a,1)
        b(j,i) = b(i,j)
      enddo
    enddo
    end function inverse

    function readG(row,fname) result(gr)
    implicit none
    character(len=*), intent(in) :: fname
    integer, intent(in) :: row
    integer :: i
    real*8 :: gr(size(V,1)),grw(ng)
    open (unit=12,file=trim(adjustl(fname)) , status='old', form='unformatted', access='direct', recl=8*ng)
    !open (unit=12,file=fname , status='old', form='unformatted', access='direct', recl=8*size(V,1))
    !read (unit=12, rec=row) gr
    read (unit=12, rec=indxg(row)) grw
    close (unit=12)
    do i=1,size(V,1)
      gr(i) = grw(indxg(i))
    enddo

    end function readG


  
    
    end module bigfuncs
    

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! module subs
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    
    module bigsubs

    use global
    !use mymkl
    
    implicit none
    
    contains
 
    subroutine chol(a)
    implicit none
    external dpotrf
    real*8, dimension(:,:), intent(inout)  :: a
    integer :: info,i,j
    info=0
    call dpotrf('U',size(a,1),a,size(a,1),info)             ! cholesky decompostion of a
    ! copy to lower
    do i=1,size(a,1)
      do j=i,size(a,1)
        a(j,i) = a(i,j)
      enddo
    enddo
    end subroutine chol

    subroutine chol2inv(a)
    implicit none
    external dpotri
    real*8, dimension(:,:), intent(inout)  :: a
    integer :: info,i,j
    info=0
    call dpotri('U',size(a,1),a,size(a,1),info)             ! inverse of a
    ! copy to lower
    do i=1,size(a,1)
      do j=i,size(a,1)
        a(j,i) = a(i,j)
      enddo
    enddo
    end subroutine chol2inv

    subroutine loadG(fname)
    implicit none
    integer :: i,j,k
    real*8 :: grw(ng)
    character(len=*), intent(in) :: fname
    logical :: exst

    inquire(file=trim(adjustl(fname)), exist=exst)
    if(.not.(exst)) then
       print *, 'Trying to open file:'
       print*, fname
       print *, 'file does not exist'
       stop
    endif
    
    open (unit=12,file=trim(adjustl(fname)), status='old', form='unformatted', access='direct', recl=8*ng)
    do i=1,size(G,1)
      read (unit=12, rec=indxg(i)) grw
      do j=1,size(G,1)
        G(i,j) = grw(indxg(j))
      enddo
    enddo
    close (unit=12)
    end subroutine loadG

 
    subroutine computeV(weights,fnames)
    implicit none
    integer :: i,j,k,r
    real*8, dimension(:),intent(in) :: weights
    real*8 :: grw(ng)
    character(len=*), dimension(:),intent(in) :: fnames
    logical :: exst

    do r=1,size(weights)
    if (r<size(weights)) then
    inquire(file=trim(adjustl(fnames(r))), exist=exst)
    if(.not.(exst)) then
       print *, 'Trying to open file:'
       print*, fnames(r)
       print *, 'file does not exist'
       stop
    endif

    open (unit=12,file=trim(adjustl(fnames(r))), status='old', form='unformatted', access='direct', recl=8*ng)
    do i=1,size(V,1)
      read (unit=12,rec=indxg(i)) grw
      do j=1,size(V,1)
        V(i,j)=V(i,j)+grw(indxg(j))*weights(r)
      enddo
    enddo
    close (unit=12)

    else
    
    do j=1,size(V,1)
        V(j,j)=V(j,j)+weights(r)  ! residual
    enddo
    
    endif
    enddo
  
    end subroutine computeV

    
    end module bigsubs


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    subroutine reml
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 
  
    use global
    !use mymkl
    use bigsubs
    use bigfuncs

    implicit none

    ! input and output variables
    integer :: n, nf,nr,maxit
    real*8 :: tol
    real*8, allocatable  :: y(:),X(:,:)
    real*8,allocatable  :: b(:),u(:,:),theta(:),asd(:,:)
    character(len=1000), allocatable :: rfnames(:)
    
    ! local variables
    integer :: i,j,k,it,row
    real*8, allocatable :: theta0(:),ai(:,:),s(:),trPG(:),trVG(:),delta(:)
    !real*8 :: theta0(nr),ai(nr,nr),s(nr),trPG(nr),delta(nr)
    real*8, allocatable :: VX(:,:),XVX(:,:),VXXVX(:,:),Vy(:),Py(:),Pu(:,:),gr(:,:)  
    !real*8 :: VX(n,nf),XVX(nf,nf),VXXVX(n,nf),Vy(n),Py(n),Pu(n,nr) 
    real*8 :: llik, ldV, ldXVX, yPy, ymean
    
    logical :: exst
    
    ! timing variables
    real*8 :: time0,time1,time2
    real*8 :: dsecnd
    
    ! threads
    integer :: mkl_get_max_threads, nthreads
    
    open (unit=10, file='param.txt', status='old')
    ! read dimensions
    read(unit=10,fmt=*) n,nf,nr,maxit,nthreads
    
    ! allocate variables
    allocate(y(n),X(n,nf),indxg(n))
    allocate(b(nf),u(n,nr),theta(nr),asd(nr,nr))
    allocate(theta0(nr),ai(nr,nr),s(nr),trPG(nr),trVG(nr),delta(nr))
    allocate(VX(n,nf),XVX(nf,nf),VXXVX(n,nf),Vy(n),Py(n),Pu(n,nr),gr(n,nr-1)) 
    allocate(rfnames(nr))
    
    ! read theta
    read(unit=10,fmt=*) theta
    theta0=0.0D0

    ! read tolerance
    read(unit=10,fmt=*) tol

    !read(unit=10,fmt=*) rfnames(1)
   
    !rfnames = "/data/scratch/project/lmm/work/study12/Gstudy12" 
    !print*, trim(adjustl(rfnames(1)))

    !read G filenames and check they exist
    do i=1,nr-1
    read(unit=10,fmt=*) rfnames(i)
    inquire(file=trim(adjustl(rfnames(i))), exist=exst)
    if(.not.(exst)) then
       print *, 'Trying to open file:'
       print*, rfnames(i)
       print *, 'file does not exist'
       stop
    endif
    enddo
    close(unit=10)

    
    time0 = dsecnd()

    if (nthreads.eq.0) then 
      nthreads = mkl_get_max_threads()  
    endif
    
    print *, "Setting max number of threads Intel(R) MKL can use for"
    print *, "parallel runs"
    print *, ""
    print *, nthreads 
    print *, ""
    
    call mkl_set_num_threads(nthreads)
    
    
    ! read y and X data  (use this if running program)
    open (unit=10,file='y' , status='old', form='unformatted', access='direct', recl=8*n)
    read (unit=10,rec=1) y
    close (unit=10)

    open (unit=11,file='X' , status='old', form='unformatted', access='direct', recl=8*nf)
    do i=1,n
      read (unit=11,rec=i) X(i,1:nf)
      enddo
    close (unit=11)
    ! end read in y and X data

    ! read ids to be used in analyses
    open (unit=12,file='indxg.txt', status='old', access='sequential', form='formatted', action='read' )
    read (unit=12,fmt=*) ng,indxg
    close (unit=12)
    
    time0 = dsecnd()

    do it = 1, maxit
    
    ! compute V and save to file
    allocate(V(n,n))
    V=0.0D0
    call computeV(theta,rfnames)

    ! compute inverse of V (store in V) and log determinant of V
    ldV=0.0D0
    call chol(V)                ! cholesky decomposition of V
    ldV = sum(log(diag(V)**2))  ! log determinant of V
    call chol2inv(V)            ! inverse V using cholesky

    ! compute P and save to file
    VX = crossprod(V,X)                   ! n*nf = n*n n*nf 
    XVX = crossprod(transpose(X),VX)
    call chol(XVX)                        ! cholesky decomposition of XVX
    ldXVX = sum(log(diag(XVX)**2))        ! log determinant of XVX
    call chol2inv(XVX)                    ! inverse XVX using cholesky
    VXXVX = crossprod(VX,XVX)             ! n*nf = n*nf nf*nf
    
    b=matmul(transpose(VXXVX),y)
    
    Vy = matvec(V,y)

    ! compute P (stored in V), trVG and trPG
    trVG = 0.0D0
    trPG = 0.0D0
    trVG(nr) = sum(diag(V))  ! residual effects 
    do j=1,n
      do i=1,nr-1            ! random effects excluding residual
        gr(1:n,i) = readG(j,rfnames(i))
        trVG(i) = trVG(i) + sum(gr(1:n,i)*V(1:n,j)) 
      enddo 
      V(1:n,j) = V(1:n,j) - matvec(VXXVX(:,1:nf),VX(j,1:nf))  ! update the j'th column of V to be the j'th column of P 
      do i=1,nr-1
        trPG(i) = trPG(i) + sum(gr(1:n,i)*V(1:n,j))
      enddo 
    enddo
    trPG(nr) = sum(diag(V))   ! residual effects
 
    ! compute Py and yPy (P stored in V)
    Py = matvec(V,y)
    yPy = sum(y*Py)
    
    ! compute u (unscaled)
    do i=1,n
      do j=1,nr-1           ! random effects excluding residual
        gr(1:n,j) = readG(i,rfnames(j))
        u(i,j) = sum(gr(1:n,j)*Py)
      enddo 
      !u(i,1:(nr-1)) = matvec(transpose(gr),Py)
    enddo
    u(:,nr) = Py            ! random residual effects

    ! compute Pu  (P stored in V)
    do i=1,nr                     ! random effects including residual
      Pu(:,i) = matvec(V,u(:,i))
    enddo

    deallocate(V) 
    
    ! compute average information and first derivatives
    ai=0.0D0
    s=0.0D0
    do i=1,nr
      do j=i,nr
         ai(i,j) = 0.5D0*sum(u(:,i)*Pu(:,j))
         ai(j,i) = ai(i,j)
      enddo
      if (i<nr) then 
        s(i) = -0.5*( trPG(i) - sum(u(:,i)*Py) )
      else
        s(i) = -0.5*( trPG(i) - sum(Py*Py) )
      endif
    enddo

    ! compute u (scaled)
    do i=1,nr-1             ! random effects excluding residual
      u(:,i) = u(:,i)*theta(i)
    enddo
    
    ! compute theta and asd
    ai = inverse(ai)
    theta0 = theta + matmul(ai,s)
    where (theta0<tol) theta0 = tol
    delta = theta - theta0
    theta = theta0

    ! compute restricted log likelihood
    llik = -0.5D0*( ldV + ldXVX + yPy )
    
    print *, theta

    if (it.eq.maxit) exit
    if ( maxval(abs(delta))<tol ) exit
    
    enddo

    ! write results to files
    open (unit=11,file='llik.qgg' )
    write (unit=11,fmt='(E16.8)') llik
    close(unit=11)
    
    open (unit=11,file='theta.qgg' )
    write (unit=11,fmt='(E16.8)') theta
    close(unit=11)
    
    open (unit=11,file='thetaASD.qgg' )
    do i=1,nr
      write (unit=11,fmt='(999E16.8)') ai(i,1:nr)
    enddo
    close(unit=11)

    open (unit=11,file='beta.qgg' )
    write (unit=11,fmt='(E16.8)') b
    close(unit=11)
    
    open (unit=11,file='betaASD.qgg' )
    do i=1,nf
      write (unit=11,fmt='(999E16.8)') XVX(i,1:nf)
    enddo
    close(unit=11)
        
    open (unit=11,file='uhat.qgg' )
    do i=1,n
      write (unit=11,fmt='(999E16.8)') u(i,1:(nr-1))
    enddo
    close(unit=11)

    open (unit=11,file='Vy.qgg' )
    write (unit=11,fmt='(E16.8)') Vy
    close(unit=11)

    open (unit=11,file='Py.qgg' )
    write (unit=11,fmt='(E16.8)') Py
    close(unit=11)

    open (unit=11,file='trPG.qgg' )
    write (unit=11,fmt='(E16.8)') trPG
    close(unit=11)

    open (unit=11,file='trVG.qgg' )
    write (unit=11,fmt='(E16.8)') trVG
    close(unit=11)

    open (unit=11,file='residuals.qgg' )
    write (unit=11,fmt='(E16.8)') u(1:n,nr)*theta(nr)
    close(unit=11)

  

    print *, (dsecnd() - time0)

    end subroutine reml
    
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
