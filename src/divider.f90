    subroutine divider(nx,ny,ncells,ncellsbest,noverlap,nnodes, &
                nsubx,nsuby,nsubxmid,nsubymid,nxmid,nymid, &
                nsubxmidlo, nsubymidlo, ilostart, jlostart)

! Divide up nx by ny array into subfields for processing by PPMAP.

    implicit real (a-h,o-z)
    implicit integer (i,n)

    real(4) minrem
    logical nofit
    integer :: xstartprint, ystartprint, iend, jend

    nnodes = 10			! number of nodes available simultaneously
    !nnodes = 4			! number of nodes available simultaneously
    minrem = float(nx)*ny
    ncellsbest = ncells
    nofit = .true.
    
    xstartprint = 0
    ystartprint = 0
    
    do nc = 2*noverlap,ncells !  removed step of 2
	nsubxnom = (nx - noverlap)/(nc - noverlap)
	nsubynom = (ny - noverlap)/(nc - noverlap)
	!nremx = nc - (nsubxnom*(nc-noverlap) + noverlap) ! why nc? should be nx
	!nremy = nc - (nsubynom*(nc-noverlap) + noverlap)
	nremx = nx - (nsubxnom*(nc-noverlap) + noverlap) ! why nc? should be nx
	nremy = ny - (nsubynom*(nc-noverlap) + noverlap)
        rem = float(nremx)*nremy
	if (rem < minrem .and. mod(nsubxnom,2)/=0 .and. mod(nsubxnom,2)/=0) then 
	    ncellsbest = nc
	    nremxbest = nremx
	    nremybest = nremy
	    nsubx = nsubxnom
	    nsuby = nsubynom
	    minrem = rem
	    nofit = .false.
	endif
    enddo

    if (nofit) then 
	interval = ncells-noverlap
	nsubx = (nx-ncells)/interval + 1
	nsuby = (ny-ncells)/interval + 1
    endif

    if (mod(nsubx,2) == 0) then
    nsubx = nsubx + 1
    endif
    if (mod(nsuby,2) == 0) then
    nsuby = nsuby + 1
    endif
    
    nsubxmid = ceiling(float(nsubx) / 2)
    nsubymid = ceiling(float(nsuby) / 2)
    
    nxmid = ceiling(float(nx) / 2)
    nymid = ceiling(float(ny) / 2)
    
    nsubxmidlo = nxmid - floor(float(ncellsbest) / 2)
    nsubymidlo = nymid - floor(float(ncellsbest) / 2)
    
    ilostart = nsubxmidlo - (floor(float(nsubx)/2) &
    * (ncellsbest - noverlap)) 
    jlostart = nsubymidlo - (floor(float(nsuby)/2) &
    * (ncellsbest - noverlap)) 
    
    iend = ((nsubx - 1) * (ncellsbest - noverlap)) &
    + ncellsbest - 1 + ilostart
    jend = ((nsuby - 1) * (ncellsbest - noverlap)) &
    + ncellsbest - 1 + jlostart

    do while ((ilostart < 0) .OR. (iend > nx)) ! changed to nx from nx-1
        ilostart = ilostart + (ncellsbest - noverlap)
        nsubx = nsubx - 2
        iend = ((nsubx - 1) * (ncellsbest - noverlap)) &
        + ncellsbest - 1 + ilostart
    end do
    do while ((jlostart < 0) .OR. (jend > ny))  ! changed to ny from ny-1
        jlostart = jlostart + (ncellsbest - noverlap)
        nsuby = nsuby - 2
        jend = ((nsuby - 1) * (ncellsbest - noverlap)) &
        + ncellsbest - 1 + jlostart
    end do    

    print *,'Imaging array divided into',nsubx,' subfields in x, and', &
	nsuby,' in y,'
    print *,'with a subfield width of',ncellsbest,' pixels'
    print *,'Actual coverage:',ilostart,iend,jlostart,jend
    print *,'Overlap =',noverlap

    end subroutine divider
