!==============================================================================================================
! functions and subroutines used for bedfiles 
!==============================================================================================================
!
!	https://www.cog-genomics.org/plink2/formats
!	00 Homozygous for first allele in .bim file
!	01 Missing genotype
!	10 Heterozygous
!	11 Homozygous for second allele in .bim file
!
!==============================================================================================================
    

    module bedfuncs

    implicit none
    
    contains

    !============================================
    function raw2int(n,nbytes,raw) result(g)
    !============================================

    implicit none

    integer, intent(in) :: nbytes,n
    integer, parameter :: byte = selected_int_kind(1) 
    integer(byte), intent(in) :: raw(nbytes)
    integer*4 :: i,j,k,rawbits,g(n) 
    integer, dimension(4) :: rawcodes
 
    rawcodes = (/ 0, 3, 1, 2 /)
    ! 00 01 10 11

    g=0
    k=0
    do i=1,nbytes 
      do j=0,6,2
        k = k + 1
        rawbits = ibits(raw(i), j, 2)
        g(k) = rawcodes(rawbits+1)
        if (k==n) exit 
      enddo
      if (k==n) exit
    enddo

    end function raw2int


    !============================================
    function raw2real(n,nbytes,raw) result(w)
    !============================================

    implicit none

    integer, intent(in) :: nbytes,n
    integer, parameter :: byte = selected_int_kind(1) 
    integer(byte), intent(in) :: raw(nbytes)
    integer*4 :: i,j,k,rawbits
    real*8 :: w(n)
    real*8, dimension(4) :: rawcodes
 
    rawcodes = (/ 0.0D0, 3.0D0, 1.0D0, 2.0D0 /)
    ! 00 01 10 11
    
    w=0.0D0
    k=0
    do i=1,nbytes 
      do j=0,6,2
        k = k + 1
        rawbits = ibits(raw(i), j, 2)
        w(k) = rawcodes(rawbits+1)
        if (k==n) exit 
      enddo
      if (k==n) exit
    enddo

    end function raw2real


    !============================================
    function scalew(nr,g) result(w)
    !============================================

    implicit none

    integer, intent(in) :: nr
    real*8, intent(in) :: g(nr)
    real*8 :: mean,sd,tol,nsize,w(nr)

    tol=0.00001D0
    w=g
    nsize=dble(count(w<3.0D0))
    mean=sum(w, mask=w<3.0D0)/nsize
    where(w<3.0D0) 
      w=w-mean
    elsewhere
      w=0.0D0
    end where
    sd=sqrt(sum(w**2)/(nsize-1))
    if(sd>tol) w=w/sd
    if(sd<tol) w=0.0D0

    end function scalew

    end module bedfuncs


!==============================================================================================================
  subroutine bed2raw(m,cls,nbytes,append,fnBED,fnRAW)
!==============================================================================================================

  use bedfuncs 
  
  implicit none
  
  integer*4 :: m,cls(m),nbytes,append  
  character(len=1000) :: fnBED,fnRAW

  integer*4, parameter :: byte = selected_int_kind(1) 
  integer(byte) :: raw(nbytes), magic(3)
  integer*4 :: i,offset,nchar

  integer, parameter :: k14 = selected_int_kind(14) 
  integer (kind=k14) :: pos14, nbytes14, offset14,i14

 
  ! input file
  offset=3
  nchar=index(fnBED, '.bed')
  open(unit=13, file=fnBED(1:(nchar+3)), status='old', access='stream', form='unformatted', action='read')
  read(13) magic

  ! output bedfile
  nchar=index(fnRAW, '.bed')
  if (nchar>0) then
   if (append==0) open(unit=14, file=fnRAW(1:(nchar+3)), status='new', access='stream', action='write')
   if (append==0) write(14) magic
   if (append==1) open(unit=14, file=fnRAW(1:(nchar+3)), status='old', access='stream', action='write', position='append')
  endif

  ! output rawfile
  nchar=index(fnRAW, '.raw')
  if (nchar>0) then
    if (append==0) open(unit=14, file=fnRAW(1:(nchar+3)), status='new', access='stream', action='write')
    if (append==1) open(unit=14, file=fnRAW(1:(nchar+3)), status='old', access='stream', action='write', position='append')
  endif
  
  nbytes14 = nbytes
  offset14 = offset
  
  do i=1,m 
    if(cls(i)==1) then
    i14=i
    pos14 = 1 + offset14 + (i14-1)*nbytes14
    read(13, pos=pos14) raw
    write(14) raw
    !print*, 'writing record', i, 'to file' 
    endif
  enddo 

  close(unit=13)
  close(unit=14)

  end subroutine bed2raw
!==============================================================================================================


!==============================================================================================================
  subroutine readbed(n,nr,rws,nc,cls,impute,scale,direction,W,nbytes,fnRAW)
!==============================================================================================================

  use bedfuncs 
  
  implicit none
  
  integer*4 :: n,nr,nc,rws(nr),cls(nc),nbytes,impute,scale,direction(nc) 
  real*8 :: W(nr,nc),gsc(nr),gr(n),n0,n1,n2,nmiss,af,ntotal
  character(len=1000) :: fnRAW

  integer*4, parameter :: byte = selected_int_kind(1) 
  integer(byte) :: raw(nbytes,nc)
  integer*4 :: i,nchar,offset

  integer, parameter :: k14 = selected_int_kind(14) 
  integer (kind=k14) :: pos14, nbytes14, offset14, i14

  offset=0
  nchar=index(fnRAW, '.bed')
  if(nchar>0) offset=3
  if(nchar==0) nchar=index(fnRAW, '.raw')

  nbytes14 = nbytes
  offset14 = offset

  open(unit=13, file=fnRAW(1:(nchar+3)), status='old', access='stream', form='unformatted', action='read')
  do i=1,nc
    i14=cls(i)
    pos14 = 1 + offset14 + (i14-1)*nbytes14
    read(13, pos=pos14) raw(1:nbytes,i)
  enddo
  close(unit=13)

  ntotal=dble(nr)  

  W=0.0D0  
  do i=1,nc
    gr = raw2real(n,nbytes,raw(1:nbytes,i))
    if (impute==0) then
      if(direction(i)==0) gr=2.0D0-gr
      where(gr==3.0D0) gr=0.0D0
      where(gr==-1.0D0) gr=0.0D0
      W(1:nr,i) = gr(rws)
    endif
    if (impute==3) then
      if(direction(i)==0) gr=2.0D0-gr
      where(gr==-1.0D0) gr=3.0D0
      W(1:nr,i) = gr(rws)
    endif
    if (impute==1) then
      af=0.0D0
      gsc=gr(rws)
      nmiss=dble(count(gsc==3.0D0))
      n0=dble(count(gsc==0.0D0))
      n1=dble(count(gsc==1.0D0)) 
      n2=dble(count(gsc==2.0D0))
      if ( nmiss<ntotal ) af=(n1+2.0D0*n2)/(2.0D0*(ntotal-nmiss))
      W(1:nr,i) = gr(rws)
      where(W(1:nr,i)==3.0D0) W(1:nr,i)=2.0D0*af
      if(direction(i)==0) W(1:nr,i)=2.0D0-W(1:nr,i)
      if (scale==1) W(1:nr,i)=scalew(nr,W(1:nr,i))
      if ( nmiss==ntotal ) W(1:nr,i)=0.0D0
    endif
  enddo 


  end subroutine readbed
!==============================================================================================================


!==============================================================================================================
  subroutine mpgrs(n,nr,rws,nc,cls,nbytes,fnRAW,nprs,s,prs,af,impute,direction,ncores)
!==============================================================================================================

  use bedfuncs 
  
  implicit none
  
  integer*4 :: n,nr,nc,rws(nr),cls(nc),nbytes,nprs,ncores,thread,impute,direction(nc)
  real*8 :: gsc(nr),gr(n),n0,n1,n2,nmiss,af(nc),ntotal
  real*8 :: prs(nr,nprs),s(nc,nprs),prsmp(nr,nprs,ncores)
  character(len=1000) :: fnRAW
  integer, external :: omp_get_thread_num


  integer*4, parameter :: byte = selected_int_kind(1) 
  integer(byte) :: raw(nbytes,nc)
  integer*4 :: i,j,k,nchar,offset

  integer, parameter :: k14 = selected_int_kind(14) 
  integer (kind=k14) :: pos14, nbytes14, offset14, i14

  offset=0
  nchar=index(fnRAW, '.bed')
  if(nchar>0) offset=3
  if(nchar==0) nchar=index(fnRAW, '.raw')

  nbytes14 = nbytes
  offset14 = offset

  open(unit=13, file=fnRAW(1:(nchar+3)), status='old', access='stream', form='unformatted', action='read')
  do i=1,nc
    i14=cls(i)
    pos14 = 1 + offset14 + (i14-1)*nbytes14
    read(13, pos=pos14) raw(1:nbytes,i)
  enddo
  close(unit=13)

  ntotal=dble(nr)  

  call omp_set_num_threads(ncores)

  prs=0.0d0
  prsmp=0.0d0

  !$omp parallel do private(i,j,k,gr,gsc,nmiss,n0,n1,n2,thread)
  do i=1,nc
    thread=omp_get_thread_num()+1
    gr = raw2real(n,nbytes,raw(1:nbytes,i))
    gsc=gr(rws)
    nmiss=dble(count(gsc==3.0D0))  
    if (impute==0) then
      where(gsc==3.0D0) gsc=0.0D0
    endif
    if (impute==1) then
      if(af(i)==0.0D0) then 
        n0=dble(count(gsc==0.0D0))
        n1=dble(count(gsc==1.0D0)) 
        n2=dble(count(gsc==2.0D0))
        if ( nmiss<ntotal ) af(i)=(n1+2.0D0*n2)/(2.0D0*(ntotal-nmiss))
      endif
      where(gsc==3.0D0) gsc=2.0D0*af(i)
    endif
    if(direction(i)==0) gsc=2.0D0-gsc
    if ( nmiss==ntotal ) gsc=0.0D0
    do j=1,nprs
       if (s(i,j)/=0.0d0) prsmp(1:nr,j,thread) = prsmp(1:nr,j,thread) + gsc*s(i,j)
    enddo  
  enddo 
  !$omp end parallel do

  do i=1,nprs
    do j=1,ncores
      prs(1:nr,i) = prs(1:nr,i) + prsmp(1:nr,i,j)
    enddo
  enddo  
  
  end subroutine mpgrs
!==============================================================================================================

!==============================================================================================================
  subroutine gstat(n,nr,rws,nc,cls,nbytes,fnRAW,nt,s,yadj,setstat,af,impute,scale,direction,ncores)
!==============================================================================================================

  use bedfuncs 
  
  implicit none
  
  integer*4 :: n,nr,nc,rws(nr),cls(nc),nbytes,nt,ncores,thread,impute,scale,direction(nc)
  real*8 :: gsc(nr),gr(n),n0,n1,n2,nmiss,af(nc),ntotal
  real*8 :: yadj(nr,nt),s(nc,nt),setstat(nc,nt)
  character(len=1000) :: fnRAW
  integer, external :: omp_get_thread_num

  integer*4, parameter :: byte = selected_int_kind(1) 
  integer(byte) :: raw(nbytes)
  integer*4 :: i,j,nchar,offset

  integer, parameter :: k14 = selected_int_kind(14) 
  integer (kind=k14) :: pos14, nbytes14, offset14, i14

  offset=0
  nchar=index(fnRAW, '.bed')
  if(nchar>0) offset=3
  if(nchar==0) nchar=index(fnRAW, '.raw')

  nbytes14 = nbytes
  offset14 = offset

  open(unit=13, file=fnRAW(1:(nchar+3)), status='old', access='stream', form='unformatted', action='read')

  ntotal=dble(nr)  

  call omp_set_num_threads(ncores)

  setstat=0.0d0
  !$omp parallel do private(i,j,i14,pos14,raw,gr,gsc,nmiss,n0,n1,n2,thread)
  do i=1,nc
    i14=cls(i)
    pos14 = 1 + offset14 + (i14-1)*nbytes14
    read(13, pos=pos14) raw
    gr = raw2real(n,nbytes,raw(1:nbytes))
    gsc=gr(rws)
    nmiss=dble(count(gsc==3.0D0))  
    if (impute==0) then
      where(gsc==3.0D0) gsc=0.0D0
    endif
    if (impute==1) then
      if(af(i)==0.0D0) then 
        n0=dble(count(gsc==0.0D0))
        n1=dble(count(gsc==1.0D0)) 
        n2=dble(count(gsc==2.0D0))
        if ( nmiss<ntotal ) af(i)=(n1+2.0D0*n2)/(2.0D0*(ntotal-nmiss))
      endif
      where(gsc==3.0D0) gsc=2.0D0*af(i)
    endif
    if(direction(i)==0) gsc=2.0D0-gsc
    if(scale==1) gsc=scalew(nr,gsc)
    if ( nmiss==ntotal ) gsc=0.0D0
    do j=1,nt
       if (s(i,j)/=0.0d0) setstat(i,j) = sum(yadj(1:nr,j)*gsc*s(i,j))
    enddo  
  enddo 
  !$omp end parallel do
  close(unit=13)

  

  end subroutine gstat
!==============================================================================================================

  

!==============================================================================================================
  subroutine summarybed(n,nr,rws,nc,cls,af,nmiss,n0,n1,n2,nbytes,fnRAW,ncores)
!==============================================================================================================

  use bedfuncs 
  
  implicit none
  
  integer*4 :: n,nr,nc,rws(nr),cls(nc),nbytes,g(n),grws(nr),ncores,thread 
  real*8 :: n0(nc),n1(nc),n2(nc),ntotal,af(nc),nmiss(nc)
  character(len=1000) :: fnRAW

  integer, parameter :: byte = selected_int_kind(1) 
  integer(byte) :: raw(nbytes)
  integer*4 :: i,stat,nchar,offset

  integer, parameter :: k14 = selected_int_kind(14) 
  integer (kind=k14) :: pos14, nbytes14, offset14, i14

  integer, external :: omp_get_thread_num

  call omp_set_num_threads(ncores)

  offset = 0
  nchar=index(fnRAW, '.bed')
  if(nchar>0) offset = 3
  if(nchar==0) nchar=index(fnRAW, '.raw')

  offset14 = offset
  nbytes14 = nbytes

  af=0.0D0
  nmiss=0.0D0
  ntotal=dble(nr)  

  ! process serial
  if (ncores==1) then
    open(unit=13, file=fnRAW(1:(nchar+3)), status='old', access='direct', form='unformatted', recl=nbytes)
    do i=1,nc 
      read(13, iostat=stat, rec=cls(i)) raw
      g = raw2int(n,nbytes,raw)
      grws = g(rws)
      nmiss(i)=dble(count(grws==3))
      n0(i)=dble(count(grws==0))
      n1(i)=dble(count(grws==1)) 
      n2(i)=dble(count(grws==2))
      if ( nmiss(i)<ntotal ) af(i)=(n1(i)+2.0D0*n2(i))/(2.0D0*(ntotal-nmiss(i)))
    enddo 
    close(unit=13)
  endif

  ! process parallel
  if (ncores>1) then
    open(unit=13, file=fnRAW(1:(nchar+3)), status='old', access='stream', form='unformatted', action='read')
    !$omp parallel do private(i,i14,pos14,raw,g,grws,thread)
    do i=1,nc 
      thread=omp_get_thread_num()+1
      i14=cls(i)
      pos14 = 1 + offset14 + (i14-1)*nbytes14
      read(13, pos=pos14) raw
      g = raw2int(n,nbytes,raw)
      grws = g(rws)
      nmiss(i)=dble(count(grws==3))
      n0(i)=dble(count(grws==0))
      n1(i)=dble(count(grws==1)) 
      n2(i)=dble(count(grws==2))
      if ( nmiss(i)<ntotal ) af(i)=(n1(i)+2.0D0*n2(i))/(2.0D0*(ntotal-nmiss(i)))
    enddo 
    !$omp end parallel do
    close(unit=13)
  endif

  end subroutine summarybed
!==============================================================================================================

!==============================================================================================================
  subroutine grmbed(n,nr,rws,nc,cls1,cls2,scale,nbytes,fnRAW,msize,ncores,fnG,gmodel)
!==============================================================================================================

  use bedfuncs 
  
  implicit none
  
  integer*4 :: i,j,n,nr,nc,rws(nr),cls1(nc),cls2(nc),impute,scale,nbytes,ncores,msize,nchar,ncw,gmodel,direction(nc) 
  real*8 :: G(nr,nr), W1(nr,msize), traceG
  character(len=1000) :: fnRAW,fnG
  real*8, allocatable :: W2(:,:)

  call omp_set_num_threads(ncores)

  G = 0.0D0
  W1 = 0.0D0
  if(gmodel==3) then 
    allocate(W2(nr,msize))
    W2 = 0.0D0
  endif

  impute=1
  direction=1 

  do i=1,nc,msize

    if((i+msize-1)<nc) ncw = size(cls1(i:(i+msize-1)))
    if((i+msize-1)>=nc) ncw = size(cls1(i:nc))          
  
    select case (gmodel)

      case (1) ! additive 
      call readbed(n,nr,rws,ncw,cls1(i:(i+ncw-1)),impute,scale,direction,W1(:,1:ncw),nbytes,fnRAW)
      call dsyrk('u', 'n', nr, ncw, 1.0D0, W1(:,1:ncw), nr, 1.0D0, G, nr)

      case (2) ! dominance
      scale=2
      call readbed(n,nr,rws,ncw,cls1(i:(i+ncw-1)),impute,scale,direction,W1(:,1:ncw),nbytes,fnRAW)
      call dsyrk('u', 'n', nr, ncw, 1.0D0, W1(:,1:ncw), nr, 1.0D0, G, nr)

      case (3) ! epistasis
      call readbed(n,nr,rws,ncw,cls1(i:(i+ncw-1)),impute,scale,direction,W1(:,1:ncw),nbytes,fnRAW)
      call readbed(n,nr,rws,ncw,cls2(i:(i+ncw-1)),impute,scale,direction,W2(:,1:ncw),nbytes,fnRAW)
      do j=1,ncw
        W1(:,j) = W1(:,j)*W2(:,j)
      enddo
      call dsyrk('u', 'n', nr, ncw, 1.0D0, W1(:,1:ncw), nr, 1.0D0, G, nr)

      case (4) ! epistasis hadamard 
      call readbed(n,nr,rws,ncw,cls1(i:(i+ncw-1)),impute,scale,direction,W1(:,1:ncw),nbytes,fnRAW)
      call dsyrk('u', 'n', nr, ncw, 1.0D0, W1(:,1:ncw), nr, 1.0D0, G, nr)

    end select
  
    !print*,'Finished block',i

  enddo
 
  traceG = 0.0D0
  do i=1,size(G,1)
      traceG = traceG + G(i,i)
  enddo
  traceG = traceG/dble(nr) 
 
  do i=1,size(G,1)
    do j=i,size(G,1)
      G(i,j) = G(i,j)/traceG
      G(j,i) = G(i,j)
    enddo
  enddo

  nchar=index(fnG, '.grm')
  open(unit=10, file=fnG(1:(nchar+3)), status='unknown', access='stream', form='unformatted', action='write')
  do j=1,size(G,1)
    if (gmodel<4) write(unit=10) G(1:size(G,1),j)
    if (gmodel==4) write(unit=10) G(1:size(G,1),j)**2
  enddo
  close(10)

  end subroutine grmbed
!==============================================================================================================


!==============================================================================================================
  subroutine ldbed(n,nr,rws,nc,cls,msize,nbytes,fnRAW,ncores,fnLD)
!==============================================================================================================

  use bedfuncs 
  
  implicit none
  
  integer*4 :: n,nr,nc,rws(nr),cls(nc),msize,nbytes,ncores
  real*8 :: ld(nc,2*msize+1),w1(n,ncores),w2(n,ncores),ntotal
  character(len=1000) :: fnRAW,fnLD
  integer, external :: omp_get_thread_num

  integer, parameter :: byte = selected_int_kind(1) 
  integer(byte) :: raw(nbytes,nc) 
  integer*4 :: i,j,k,thread,nchar,offset

  integer, parameter :: k14 = selected_int_kind(14) 
  integer (kind=k14) :: pos14,nbytes14,offset14,i14

  call omp_set_num_threads(ncores)

  offset=0
  nchar=index(fnRAW, '.bed')
  if(nchar>0) offset=3
  if(nchar==0) nchar=index(fnRAW, '.raw')

  nbytes14 = nbytes
  offset14 = offset

  open(unit=13, file=fnRAW(1:(nchar+3)), status='old', access='stream', form='unformatted', action='read')
  do i=1,nc
    i14=cls(i)
    pos14 = 1 + offset14 + (i14-1)*nbytes14
    read(13, pos=pos14) raw(1:nbytes,i)
  enddo
  close(unit=13)

  ntotal=dble(nr)  

  ld=0.0D0
  ld(1:nc,msize+1) = 1.0D0

  !$omp parallel do private(i,j,k,thread,w1,w2)
  do i=1,nc
    w1=0.0D0 
    thread=omp_get_thread_num()+1
    w1(1:n,thread) = raw2real(n,nbytes,raw(1:nbytes,i))
    w1(rws,thread)=scalew(nr,w1(rws,thread))
    do j=1,msize
      k = i+j
      if(k<(nc+1)) then 
        w2=0.0D0
        w2(1:n,thread) = raw2real(n,nbytes,raw(1:nbytes,k))
        w2(rws,thread)=scalew(nr,w2(rws,thread))
        ld(i,msize+1+j)=dot_product(w1(rws,thread),w2(rws,thread))/dble(nr)
      endif
    enddo
    do j=1,msize
      k = i-j
      if(k>1) then 
        w2=0.0D0
        w2(1:n,thread) = raw2real(n,nbytes,raw(1:nbytes,k))
        w2(rws,thread)=scalew(nr,w2(rws,thread))
        ld(i,msize+1-j)=dot_product(w1(rws,thread),w2(rws,thread))/dble(nr)
      endif
    enddo
  enddo 
  !$omp end parallel do


  !!$omp parallel do private(i,j,k,thread,w1,w2)
  !do i=1,nc
  !  w1 = raw2real(n,nbytes,raw(1:nbytes,i))
  !  k=0
  !  do j=(i+1),(i+msize)
  !    w2 = raw2real(n,nbytes,raw(1:nbytes,j))
  !    k=k+1
  !    ld(i,msize+k)=dot_product(w1(rws),w2(rws))/dble(nr)
  !  enddo
  !enddo 
  !!$omp end parallel do




  nchar=index(fnLD, '.ld')
  open(unit=14, file=fnLD(1:(nchar+2)), status='unknown', access='stream', form='unformatted', action='write')
  do i=1,nc
    write(unit=14) ld(i,1:(2*msize+1))
  enddo
  close(14)

  end subroutine ldbed
!==============================================================================================================



!==============================================================================================================
  subroutine mmbed(n,nr,rws,nc,cls,impute,scale,nbytes,fnRAW,msize,ncores,nprs,s,prs)
!==============================================================================================================
! C = A*B (dimenions: mxn = mxk kxn) 
! call dgemm("n","n",m,n,k,1.0d0,a,m,b,k,0.0d0,c,m)
! C = A*B + C
! call dgemm("n","n",m,n,k,1.0d0,a,m,b,k,1.0d0,c,m)

  use bedfuncs 
  
  implicit none
  
  integer*4 :: i,n,nr,nc,rws(nr),cls(nc),impute,scale,nbytes,ncores,msize,nprs,ncw,direction(nc) 
  real*8 :: W(nr,msize)
  character(len=1000) :: fnRAW
  real*8 :: prs(nr,nprs),s(nc,nprs)

  call omp_set_num_threads(ncores)

  direction=1

  prs = 0.0D0
  W = 0.0D0 

  do i=1,nc,msize

    if((i+msize-1)<nc) ncw = size(cls(i:(i+msize-1)))
    if((i+msize-1)>=nc) ncw = size(cls(i:nc))          

    call readbed(n,nr,rws,ncw,cls(i:(i+ncw-1)),impute,scale,direction,W(:,1:ncw),nbytes,fnRAW)
    call dgemm("n","n",nr,nprs,ncw,1.0d0,W(:,1:ncw),nr,s(i:(i+ncw-1),:),ncw,1.0d0,prs,nr)
 
    !print*,'Finished block',i

  enddo

  end subroutine mmbed
!==============================================================================================================



!==============================================================================================================
  subroutine solvebed(n,nr,rws,nc,cls,scale,nbytes,fnRAW,ncores,nit,lambda,tol,y,g,e,s,mean,sd)
!==============================================================================================================

  use bedfuncs 

  !implicit none
  
  integer*4 :: i,n,nr,nc,rws(nr),cls(nc),scale,nbytes,nit,it,ncores,nchar,offset
  real*8 :: y(n),e(n),raww(n),w(n),g(n)
  real*8 :: dww(nc),s(nc),os(nc),lambda(nc),mean(nc),sd(nc)
  real*8 :: lhs,rhs,snew,tol
  character(len=1000) :: fnRAW
  real*8, external  :: ddot

  integer, parameter :: k14 = selected_int_kind(14) 
  !integer (kind=k14) :: pos14

  integer, parameter :: byte = selected_int_kind(1) 
  integer(byte) :: raw(nbytes)
  integer :: stat

  call omp_set_num_threads(ncores)

  offset=0
  nchar=index(fnRAW, '.bed')
  if(nchar>0) offset=3
  if(nchar==0) nchar=index(fnRAW, '.raw')
  open(unit=13, file=fnRAW(1:(nchar+3)), status='old', access='direct', form='unformatted', recl=nbytes)

  ! genotypes coded 0,1,2,3=missing => where 0,1,2 means 0,1,2 copies of alternative allele 
  do i=1,nc
    read(13, iostat=stat, rec=cls(i)) raw
    raww = raw2real(n,nbytes,raw)
    where (raww<3.0D0)
      w = (raww-mean(i))/sd(i)
    elsewhere
      w = 0.0D0
    end where
    dww(i)=dot_product(w(rws),w(rws))
    if(s(i).eq.0.0D0) then
      s(i)=(ddot(nr,w(rws),1,y(rws),1)/dww(i))/nc
    endif     
  enddo
  close (unit=13)
  os=s
  e=0.0D0
  e(rws)=y(rws)
  do it=1,nit
    g=0.0D0
    open(unit=13,file=fnRAW(1:(nchar+3)), status='old', form='unformatted', access='direct', recl=nbytes)
    do i=1,nc
      read(13, iostat=stat, rec=cls(i)) raw
      raww = raw2real(n,nbytes,raw)
        where (raww<3.0D0)
        w = (raww-mean(i))/sd(i)
      elsewhere
        w = 0.0D0
      end where
      lhs=dww(i)+lambda(i)
      rhs=dot_product(w(rws),e(rws)) 
      rhs=rhs + dww(i)*s(i)
      snew=rhs/lhs
      e(rws)=e(rws) - w(rws)*(snew-s(i))
      s(i)=snew
      g=g+w*s(i)
    enddo
    close (unit=13)
    !print*,(sum((s-os)**2)/sqrt(dble(nc)))
    if( (sum((s-os)**2)/sqrt(dble(nc)))<tol) exit  
    os=s  
  enddo
  
  nit=it
  tol=sum((s-os)**2)
  
  end subroutine solvebed
!==============================================================================================================

!==============================================================================================================
  subroutine bayesbed(n,nr,rws,nc,cls,impute,nbytes,fnRAW,ncores,nit,lambda,tol,y,g,e,s,mean,sd)
!==============================================================================================================

  use bedfuncs 

  !implicit none
  
  integer*4 :: i,n,nr,nc,rws(nr),cls(nc),impute,nbytes,nit,it,ncores,nchar,offset
  real*8 :: y(n),e(n),raww(n),w(n),g(n)
  real*8 :: dww(nc),s(nc),os(nc),lambda(nc),mean(nc),sd(nc)
  real*8 :: lhs,rhs,snew,tol
  character(len=1000) :: fnRAW
  real*8, external  :: ddot

  integer, parameter :: k14 = selected_int_kind(14) 
  !integer (kind=k14) :: pos14

  integer, parameter :: byte = selected_int_kind(1) 
  integer(byte) :: raw(nbytes)
  integer :: stat

  call omp_set_num_threads(ncores)

  offset=0
  nchar=index(fnRAW, '.bed')
  if(nchar>0) offset=3
  if(nchar==0) nchar=index(fnRAW, '.raw')
  open(unit=13, file=fnRAW(1:(nchar+3)), status='old', access='direct', form='unformatted', recl=nbytes)

  ! genotypes coded 0,1,2,3=missing => where 0,1,2 means 0,1,2 copies of alternative allele 
  do i=1,nc
    read(13, iostat=stat, rec=cls(i)) raw
    raww = raw2real(n,nbytes,raw)
    where (raww<3.0D0)
      w = (raww-mean(i))/sd(i)
    elsewhere
      w = 0.0D0
    end where
    dww(i)=dot_product(w(rws),w(rws))
    if(s(i).eq.0.0D0) then
      s(i)=(ddot(nr,w(rws),1,y(rws),1)/dww(i))/nc
    endif     
  enddo
  close (unit=13)
  os=s
  e=0.0D0
  e(rws)=y(rws)
  do it=1,nit
    g=0.0D0
    open(unit=13,file=fnRAW(1:(nchar+3)), status='old', form='unformatted', access='direct', recl=nbytes)
    do i=1,nc
      read(13, iostat=stat, rec=cls(i)) raw
      raww = raw2real(n,nbytes,raw)
        where (raww<3.0D0)
        w = (raww-mean(i))/sd(i)
      elsewhere
        w = 0.0D0
      end where
      lhs=dww(i)+lambda(i)
      rhs=dot_product(w(rws),e(rws)) 
      rhs=rhs + dww(i)*s(i)
      snew=rhs/lhs
      e(rws)=e(rws) - w(rws)*(snew-s(i))
      s(i)=snew
      g=g+w*s(i)
    enddo
    close (unit=13)
    !print*,(sum((s-os)**2)/sqrt(dble(nc)))
    if( (sum((s-os)**2)/sqrt(dble(nc)))<tol) exit  
    os=s  
  enddo
  
  nit=it
  tol=sum((s-os)**2)
  
  end subroutine bayesbed
!==============================================================================================================



!==============================================================================================================
  subroutine readbin(n,nr,rws,nc,cls,W,nbytes,fnBIN)
!==============================================================================================================

  implicit none
  
  integer*4 :: n,nr,rws(nr),nc,cls(nc),nbytes,nchar,i  
  real*8 :: W(nr,nc),raw(n)
  character(len=1000) :: fnBIN

  integer, parameter :: k14 = selected_int_kind(14) 
  integer (kind=k14) :: pos14(nc),nbytes14,offset14,i14

  nchar=index(fnBIN, '.bin')
  open(unit=13, file=fnBIN(1:(nchar+3)), status='old', access='stream', form='unformatted', action='read')
  nbytes14 = nbytes*n
  offset14 = 0
  do i=1,nc 
    i14=cls(i)
    pos14(i) = 1 + offset14 + (i14-1)*nbytes14
    read(13, pos=pos14(i)) raw(1:n)
    W(1:nr,i) = raw(rws)
  enddo

  close(unit=13)

  end subroutine readbin
!==============================================================================================================


!==============================================================================================================
  subroutine psets(m,stat,nsets,setstat,msets,p,np,ncores)
!==============================================================================================================

  implicit none
  
  integer*4 :: m,nsets,msets(nsets),p(nsets),np,ncores   
  integer*4 :: i,j,k1,k2,maxm,thread,multicore   
  real*8 :: stat(m),setstat(nsets),u,pstat
  integer, external :: omp_get_thread_num

  p=0

  multicore=0
  if (ncores>1) multicore=1
 
  maxm = m - maxval(msets) - 1

  select case (multicore)

  case (0) ! no multicore 

  do i=1,nsets
    do j=1,np
      call random_number(u)
      k1 = 1 + floor(maxm*u)  ! sample: k = n + floor((m+1-n)*u) n, n+1, ..., m-1, m
      k2 = k1+msets(i)-1
      pstat = sum(stat(k1:k2))
      if (pstat > setstat(i)) p(i) = p(i) + 1
    enddo
  enddo   

  case (1) ! multicore 

  call omp_set_num_threads(ncores)

  !$omp parallel do private(i,j,k1,k2,u,pstat)
  do i=1,nsets
    thread=omp_get_thread_num()+1 
    do j=1,np
      call random_number(u)
      k1 = 1 + floor(maxm*u)  ! sample: k = n + floor((m+1-n)*u) n, n+1, ..., m-1, m
      k2 = k1+msets(i)-1
      pstat = sum(stat(k1:k2))
      if (pstat > setstat(i)) p(i) = p(i) + 1
    enddo
  enddo   
  !$omp end parallel do

  end select

  end subroutine psets
!==============================================================================================================



!==============================================================================================================
!  subroutine eiggrm(n,nev,ev,U,fnG,fnU,ncores)	
  subroutine eiggrm(n,GRM,evals,ncores)
 
!==============================================================================================================
! calls the LAPACK diagonalization subroutine dsyev       !
!input:  G(n,n) = real symmetric matrix to be diagonalized!
!            n  = size of G                               !
!output: G(n,n) = orthonormal eigenvectors of G           !
!        eig(n) = eigenvalues of G in ascending order     !
!---------------------------------------------------------!
  implicit none

  external dsyev
  integer*4 :: n,l,info,ncores
  real*8 :: GRM(n,n),evals(n),work(n*(3+n/2))
  !character(len=1000) :: fnG,fnU

  call omp_set_num_threads(ncores)
  info=0
  l=0

  l=n*(3+n/2)
  !l=max(1,3*n-1)  
  call dsyev('V','U',n,GRM,n,evals,work,l,info)
  


  !U = 0.0D0
  !G = 0.0D0
  !nchar=index(fnG, '.grm')
  !open(unit=10, file=fnG(1:(nchar+3)), status='unknown', access='stream', form='unformatted', action='read')
  !do j=1,size(G,1)
  !  read(unit=10) G(1:size(G,1),j)
  !enddo
  !close(10)

  !call sspevd(jobz, uplo, n, ap, w, z, ldz, work, lwork, iwork, liwork, info)

  end subroutine eiggrm
!==============================================================================================================
