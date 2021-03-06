        program premap

! Preprocess a set of Hi-GAL tiles in preparation for running PPMAP.
!
! Specifically: 
!	1. Regrid the Hi-GAL maps to produce Nyquist-sampled images at 5 bands.
!	2. Estimate background noise, assumed constant for each tile.
!	3. Generate a set of 16 scripts for parallel processing.
! Output images are in Jy/pixel, where the pixel size is recorded in FITS
! keyword. 
! The imaging array is nx by ny, with specified pixel size. The output
! Nyquist-sampled observed images are also presented on a set of arrays with
! the same dimensions.
!
! Command line parameters:
!	fieldname	=	field name, e.g. l224
!	scheduler	=	PBS, SLURM or NONE
!       ncpus    	=	number of cores per node, eg 40 
!       
! An input parameters file whose name is of the form <fieldname>_premap.inp
! must be present.

        implicit real (a-h, o-z)
        implicit integer (i-n)

        real,   parameter   :: pi      = 3.141593 
        real,   parameter   :: dtor    = 0.017453   ! degrees to radians

        character(len=80), allocatable :: obsimages(:)
        character(len=75), allocatable :: scriptlines(:,:)
        character(len=4), allocatable :: bands(:)
        real(4),   allocatable :: wavelengths(:), betagrid(:), pixset(:)
        real(4),   allocatable :: sigobs(:), Tgrid(:)
        real(4),   allocatable :: beamsizes(:),psfset(:,:,:)
        real(4),   allocatable :: buffer(:), a(:,:), ar(:,:), abig(:,:)
        real(4),   allocatable :: amask(:,:), armask(:,:), abigmask(:,:)
        real(4),   allocatable :: psf(:,:), cover(:,:), cmask(:,:), afield(:,:)
        real(4),   allocatable :: corrc(:,:),x(:),corrset(:)
        integer(4),allocatable :: counter(:,:), psfsizes(:)
        integer(4),allocatable :: ilo(:), ihi(:), jlo(:), jhi(:)
        integer(4),allocatable :: seq(:,:),set(:), used(:)
        integer                :: nsubxmid, nsubymid, nxmid, nymid
        integer                :: nsubxmidlo, nsubymidlo, ilostart, jlostart

        character(len=80)      :: imagefile,outfile,outscript
        character(len=80)      :: line,removeblanks,tform,string
        character(len=80)      :: sched, run_ppmap_script, ncpus
        character(len=40)      :: option, colourcorr, highpass
        character(len=80)      :: infile
        character(len=8)       :: units, inputunits
        character(len=40)      :: fieldname
        character(len=8)       :: date, ctype1, ctype2
        character(len=10)      :: time
        character(len=5)       :: zone
        real(8) ri,rj,x0d,y0d,dglon0,dglat0, dra, ddec
        real(4) tempc(10000)
        real(4) nyqpix, mag, m2j, kappa300
        integer getbands, getbeta, ixref, iyref,  status
        real(8) xref, yref
        integer, dimension (8) :: values
        logical notfinished, makemosaic, node_used

        call date_and_time(date,time,zone,values)
        write(*,'("Begin PREMAP on ",a8," at ",a10)') date,time

! Read command line.
        m = iargc()
        if (m==0) then
            print *, &
              'Syntax: premap <fieldname> <sched> <ncpus>'
            stop
         endif

        call getarg(1,fieldname)
        call getarg(2,sched)
        call getarg(3,ncpus)

! Find out how many lines in Raven script.
        run_ppmap_script = removeblanks('template_run_ppmap_'//sched//'.sh')
        open (unit=1, form='formatted', file=run_ppmap_script,status='old', &
            action='read',IOSTAT=iostatus)
        if (iostatus /= 0) then
            print *,'I need a Raven script template (run_ppmap.sh)'
            stop
        endif
        notfinished = .true.
        nlines = 0
	do while (notfinished)
            read(1,'(a)',IOSTAT=iostatus) line
            if (iostatus /= 0) then 
                notfinished = .false.
            else
                nlines = nlines + 1
            endif
        enddo
        close(1)

        print '(a)',' '
        print '(a)','-----------------------------'
        print '(a)','Field: '//fieldname

! Get input parameters.
        infile = removeblanks(fieldname//'_premap.inp')
        open (unit=2, form='formatted', file=infile,status='old', &
            action='read',IOSTAT=iostatus)
        if (iostatus /= 0) then
           print*, infile//' missing?'
            print *,'I need a PREMAP input parameters file for '//fieldname
            stop
        endif
        getbands = 0
        nbands = 0
        getbeta = 0
        Nt = 0
        nbeta = 0
        rchisqconv = 0.
        snrmax = 1.e35
        betamean = 2.
        sigbeta = 1.e6
        trimlev = 2.
        colourcorr = 'NOCOLCORR'
        highpass = 'NOHIGHPASS'
        notfinished = .true.

        do while (notfinished)
            read(2,'(a)',IOSTAT=iostatus) line
            if (iostatus /= 0) then 
                notfinished = .false.
            else
	        k = index(line,'<gloncent>')
	        if (k /= 0) read(line(1:k-1),*) glon0
	        k = index(line,'<glatcent>')
	        if (k /= 0) read(line(1:k-1),*) glat0
	        k = index(line,'<fieldsize>')
	        if (k /= 0) read(line(1:k-1),*) fieldwid,fieldhgt
	        k = index(line,'<pixel>')
	        if (k /= 0) read(line(1:k-1),*) pixel
	        k = index(line,'<dilution>')
	        if (k /= 0) read(line(1:k-1),*) eta
	        k = index(line,'<maxiterat>')
	        if (k /= 0) read(line(1:k-1),*) maxiterations
	        k = index(line,'<rchisqconv>')
	        if (k /= 0) read(line(1:k-1),*) rchisqconv
	        k = index(line,'<snrmax>')
	        if (k /= 0) read(line(1:k-1),*) snrmax
	        k = index(line,'<distance>')
                if (k /= 0) read(line(1:k-1),*) distance
	        k = index(line,'<kappa300>')
	        if (k /= 0) read(line(1:k-1),*) kappa300
	        k = index(line,'<ncells>')
	        if (k /= 0) read(line(1:k-1),*) ncells
	        k = index(line,'<noverlap>')
	        if (k /= 0) read(line(1:k-1),*) noverlap
	        k = index(line,'<Nt>')
	        if (k /= 0) read(line(1:k-1),*) Nt
	        k = index(line,'<temprange>')
	        if (k /= 0) read(line(1:k-1),*) Tmin,Tmax
                k = index(line,'<ccfile>')
                if (k /= 0) colourcorr = line(1:k-1)
                k = index(line,'<highpass>')
                if (k /= 0) highpass = line(1:k-1)
	        k = index(line,'<nbeta>')
	        if (k /= 0) read(line(1:k-1),*) nbeta
	        if (nbeta /= 0) getbeta = getbeta + 1
	        if (getbeta==1) then 
	            allocate (betagrid(nbeta))
                endif
	        k = index(line,'<betagrid>')
	        if (k /= 0 .and. nbeta /= 0) read(line(1:k-1),*) betagrid
	        k = index(line,'<betaprior>')
	        if (k /= 0) read(line(1:k-1),*) betamean,sigbeta
	        k = index(line,'<trimlev>')
	        if (k /= 0) read(line(1:k-1),*) trimlev
	        k = index(line,'<nbands>')
	        if (k /= 0) read(line(1:k-1),*) nbands
	        if (nbands /= 0) getbands = getbands + 1
	        if (getbands==1) then 
	            allocate (wavelengths(nbands))
	            allocate (obsimages(nbands))
	            allocate (sigobs(nbands))
                    sigobs = 0.
                endif
	        k = index(line,'<wavelen>')
	        if (k /= 0 .and. nbands /= 0) read(line(1:k-1),*) wavelengths
	        k = index(line,'<sigobs>')
	        if (k /= 0 .and.  nbands /= 0) read(line(1:k-1),*) sigobs
	        k = index(line,'<units>')
	        if (k /= 0 ) inputunits = removeblanks(line(1:8)) 

                if (index(line,'<obsimages>') /= 0) then 
	            allocate (bands(nbands))
	            do i = 1,nbands
		        read(2,'(a)') line
                        !obsimages(i) = removeblanks(fieldname//'/'//line)
                        obsimages(i) = removeblanks('dataset/'//line)
		        write(string,'(i4.4)') nint(wavelengths(i))
		        bands(i) = removeblanks(string)
                    enddo
	        endif
            endif
        enddo
        close(2)

! Set up temperature grid.
	allocate (Tgrid(Nt))
        alpha = (Tmax/Tmin)**(1./(Nt-1))
        do i = 1,Nt
            Tgrid(i) = Tmin * alpha**(i-1)
        enddo
        print '(a,10(f10.4))',' Tgrid [K]:',Tgrid
        print '(a,10(f10.4))',' Beta grid:',betagrid
        if (nbeta > 1) print '(a)',' Parameters of beta prior:',betamean,sigbeta

! Read in the PSFs.
        allocate (beamsizes(nbands))
        allocate (psfsizes(nbands))
        do i = 1,nbands
            imagefile = removeblanks('psfset/psf_'//bands(i)//'.fits')
            call readheader(imagefile,mxp,myp,crpix1,crpix2,cdelt2,status)
            if (status > 0) then
                print *,'Could not read header of '//imagefile
                stop
            endif
	    if (mxp /= myp) then 
	        print *,'PSF images must be square'
	        stop
	    endif
            if (i==1) then
                nbuffer = mxp*myp
                allocate (buffer(nbuffer))
                allocate (a(mxp,myp))
                allocate (counter(mxp,myp))
	        ncellsp = mxp
	        icentp = nint(crpix2 - 1.)
                pixp = cdelt2*3600.
	        allocate (psfset(nbands,ncellsp,ncellsp))
                psfset = 0.
            endif
	    if (mxp /= ncellsp) then 
	        print *,'PSF images must all be the same size'
	        stop
            endif 
            call readimage_wcs(imagefile,a,mxp,myp,buffer,ctype1,ctype2, &
                cp1,cp2,cv1,cv2,cd1,cd2,cr2,pix,wlen,sigm,units,status)
            counter = 0
            acut = (maxval(a)-minval(a))/2.
            where(a-minval(a) >= acut) counter = 1
            nhi = sum(counter)
	    beamsizes(i) = 2.*sqrt(float(nhi)/pi)*pixp
            print '(a,f10.4,a)',' FWHM of PSF at '//bands(i)//&
                 ' microns = ',beamsizes(i),' arcsec'
           ! write(*,'(a,a,a,f10.4,a)') 'FWHM of PSF at ',bands(i),&
           !      ' microns =',beamsizes(i),' arcsec'
	    icp = max(nint(2.*beamsizes(i)/pixel), 8)
	    ncp = 2*icp
            allocate (psf(ncp,ncp))
            psf = 0.
	    pmag = pixp/pixel

! Resample to requested output pixel size.
            call resample(a,mxp,myp,psf,ncp,ncp,pmag)
            psf = psf/pmag**2
            do jj = 1,ncp
            do ii = 1,ncp
                psfset(i,ii,jj) = psf(ii,jj)
            enddo
            enddo
            deallocate(psf)
	    psfsizes(i) = ncp
        enddo
        deallocate(a)
        deallocate(buffer)
        deallocate(counter)

! Write out the resampled PSF set.
        line = removeblanks(fieldname // '_psfset.fits')
        print *,'Writing out '//line(1:40)
        call writeimage3d(line,psfset,nbands,ncellsp,ncellsp,status)

! Set gridding parameters.
        !ix = nint(0.5*fieldwid*3600./pixel) old version ensures nx,ny are even
        !iy = nint(0.5*fieldhgt*3600./pixel)
        !nx = 2*ix
        !ny = 2*iy
        nx = nint(fieldwid*3600./pixel)
        ny = nint(fieldhgt*3600./pixel)
        ix = nx/2+1
        iy = ny/2+1 
        irefband = nbands/2 + 1
        
! If map centre coordinates have been entered as large negative numbers, then 
! take map centre as the mean of the centroids of all of the images.
        if (glon0 <= -900. .or. glat0 <= -900.) then
            glonsum = 0.
            glatsum = 0.
            do ii = 1,nbands
                call readheader(obsimages(ii),nxo,nyo,crpix1,crpix2, &
                    cdelt2,status)
                if (status /= 0) then
                    print *,'Could not find '//obsimages(irefband)
                    stop
                endif
                nbuffer = nxo*nyo
                allocate (buffer(nbuffer))
                allocate (a(nxo,nyo))
                call readimage_wcs(obsimages(ii),a,nxo,nyo,buffer,ctype1, &
                    ctype2,crpix1,crpix2,crval1,crval2,cdelt1,cdelt2,crota2, &
                    pixel,wl,sig,units,status)
                xsum = 0.
                ysum = 0.
                tsum = 0.
                do j = 1,nyo
                do i = 1,nxo
                    if (a(i,j) > -900.) then
                        xsum = xsum + i
                        ysum = ysum + j
                        tsum = tsum + 1.
                    endif
                enddo
                enddo
                ri = xsum/tsum - 1.
                rj = ysum/tsum - 1.
                deallocate(a)
                deallocate(buffer)
                
                if (index(ctype1,'TAN') /= 0) then
                    call pixcrot(ri,rj,dble(crpix1),dble(crpix2), &
                        dble(crota2),x0d,y0d)
                    call radec2pix(dglon0,dglat0,x0d,y0d,dble(crval1), &
                        dble(crval2),dble(crpix1),dble(crpix2), &
                        dble(cdelt2),.true.)              ! tangent projection
                    glon0 = dglon0
                    glat0 = dglat0
                else
                    cd = cos(crval2*dtor)
                    glon0 = crval1 + (ri-crpix1+1)*cdelt1/cd
                    glat0 = crval2 + (rj-crpix2+1)*cdelt2 ! plat carre (default)
                endif
                glonsum = glonsum + glon0
                glatsum = glatsum + glat0
            enddo
            glon0 = glonsum/nbands
            glat0 = glatsum/nbands
        else
            if (glon0 > 180.) glon0 = glon0 - 360.
        endif

! Regrid observed images to Nyquist sampling interval.
        glon0p = glon0
        if (glon0 < 0.) glon0p = glon0 + 360.
        print *,'Centre position:',glon0p,glat0,' deg'
        allocate (cover(nx,ny))
        allocate (cmask(nx,ny))
        cover = 1.
        cmask = 0.

! Read in the observational images.
        allocate (pixset(nbands))
        allocate (afield(nx,ny))
        crv1min = 1.e35
        crv1max = -1.e35
        crv2min = 1.e35
        crv2max = -1.e35

        do i = 1,nbands
           print*, obsimages(i)
            call readheader(obsimages(i),nxo,nyo,crpix1,crpix2,cdelt2,status)
            if (status > 0) then
                print *,'Could not read header of '//obsimages(i)
                print *,'Error code =',status
                stop
            endif
            nbuffer = nxo*nyo
            allocate (buffer(nbuffer))
            allocate (a(nxo,nyo))
            allocate (amask(nxo,nyo))
            amask = 0.
            call readimage_wcs(obsimages(i),a,nxo,nyo,buffer,ctype1,ctype2, &
                crpix1,crpix2,crval1,crval2,cdelt1,cdelt2,crota2,pixel,wl,sig,units, &
                status)
            deallocate(buffer)
 	    if (crpix1==0. .and. crpix2==0.) then 
                print *,'FITS header does not contain reference pixel'
                stop
	    endif
            if (crval1 < crv1min) crv1min = crval1
            if (crval1 > crv1max) crv1max = crval1
            if (crval2 < crv2min) crv2min = crval2
            if (crval2 > crv2max) crv2max = crval2
            where (a == -999.) amask = 1.
            where (a == -999.) a = 0.
            if (index(ctype1,'TAN') /= 0) then
                call radec2pix(dble(glon0),dble(glat0),ri,rj,dble(crval1), &
                dble(crval2),dble(crpix1),dble(crpix2),dble(cdelt2), &
                .false.)                                ! tangent projection
             else
                delg = glon0 - crval1
                if (delg < -180.) delg = delg + 360.
                if (delg > 180.) delg = delg - 360.
                cd = cos(crval2*dtor)
                ri = crpix1 + delg*cd/cdelt1
                rj = crpix2 + (glat0 - crval2)/cdelt2 ! default (plat carre)
            endif
            call pixcrot(ri,rj,dble(crpix1),dble(crpix2),dble(-crota2), &
                x0d,y0d)
	    x0 = x0d                     ! pixel coordinates corresponding to
	    y0 = y0d                     ! glon0, glat0 in current image
            write(*,'("    ",i4," microns:")') nint(wavelengths(i))
            write(*,'("     pixel corr. to centre position:  '// &
                '(",f7.1,",",f7.1,")")') x0,y0

            xc = nxo/2  !removed the -1 SJM
            yc = nyo/2 
	    ixref = nint(xc)	 ! integral pixel to serve as 
	    iyref = nint(yc)     ! reference pixel in this image
	    xref = xc
	    yref = yc
! We wish to map x0,y0 onto xref,yref.
	    asecpix = cdelt2*3600.
	    nyqpix = max((beamsizes(i)/2.), pixel)
            mag = asecpix/nyqpix
            allocate (ar(nxo,nyo))
            allocate (armask(nxo,nyo))
            call regrid(a,ar,nxo,nyo,ixref,iyref,x0,y0,mag)  
            call regrid(amask,armask,nxo,nyo,ixref,iyref,x0,y0,mag)

! Estimate standard deviation of sky background if necessary.
            if (sigobs(i) /= 0.) then
                sigsky = sigobs(i)
            else
                fwhmback = min(max(5./(cdelt2*60.), 10.),nxo/2.)
                sigsky = getnoise(a,nxo,nyo,fwhmback)
            endif
            deallocate(a)
            deallocate(amask)

! Set up image and mask arrays. PPMAP will interpret where(amask >= 0.5) as 
! blank pixels.
            allocate (a(nx,ny))
            allocate (amask(nx,ny))
	    a = ar(ixref-ix+1:ixref-ix+nx, iyref-iy+1:iyref-iy+ny) 
	    amask = ar(ixref-ix+1:ixref-ix+nx, iyref-iy+1:iyref-iy+ny)
            deallocate(ar)
            deallocate(armask)

            ! Units conversion.
            ! if the header has no units, use those give in the parameter file 
            if(units .eq. 'NONE') then
               if( inputunits .eq. ' ') then
                  print*, 'No units have been given'
                  stop
               else
                  units = inputunits
               endif
            endif
            if(units .ne. inputunits) then
               print*, 'Units in header not the same as in the parameter file'
               print*, '.',units,'.',inputunits,'.'
               !stop
            end if
            k = index(units,'Jy/pix')
            if(k/=0) then
               print*, '    Units in Jy/pix'
               ! units are per pix 
               m2j = 1/mag**2  ! units conversion
               a = a*m2j				       ! Jy per new pixel
               asig = sigsky*m2j
            else 
               k = index(units,'MJy/str')
               if(k/=0) then 
                  print*, '    Units in MJy/str'
                  ! units are per str  
                  m2j = 1.e6*abs((cdelt1*cdelt2)/mag**2)*dtor**2  ! units conversion
                  a = a*m2j				       ! Jy per new pixel
                  asig = sigsky*m2j
               else
                  print* , 'unrecognised units ' , units
                  stop
               endif
            end if
 	    print *,'    sigma =',asig,' Jy/pixel;  peak SNR =',maxval(a)/asig
            imagefile = removeblanks(fieldname//'_'//bands(i)//'.fits')
            wl = wavelengths(i)

! Update the CRPIXn values. Find pixel in regridded image with RA,Dec of
! the
! tangent point.
            crpix1new = ix + mag*(crpix1-x0) ! removed +1 and -1 
            crpix2new = iy + mag*(crpix2-y0)
            print *,'    writing out '//imagefile(1:40)
            call writeimage_wcs(imagefile,a,nx,ny,ctype1,ctype2, &
                crpix1new,crpix2new,crval1,crval2,cdelt1/mag,cdelt2/mag, &
                crota2,pixel,wl,max(asig,maxval(a)/snrmax),status)
	    print *,'    writing out mask_'//imagefile(1:40)
            call writeimage_wcs('mask_'//imagefile,amask,nx,ny,ctype1,ctype2, &
                crpix1new,crpix2new,crval1,crval2,cdelt1/mag,cdelt2/mag, &
                crota2,pixel,wl,max(asig,maxval(a)/snrmax),status)

! Generate a set of images on the same grid as ppmap output image.
            allocate (ar(nx,ny))
            allocate (armask(nx,ny))
            call resample(a,nx,ny,ar,nx,ny,nyqpix/pixel)
            call resample(amask,nx,ny,armask,nx,ny,nyqpix/pixel)
            where(ar==0.) cover = 0.
            where(armask >= 0.5) cmask = 1.
            if (i==irefband) then
                afield = ar
                crp1 = ix + (crpix1new - ix )*nyqpix/pixel ! rmeoved +1 and -1 
                crp2 = iy + (crpix2new - iy )*nyqpix/pixel
                crval1ref = crval1
                crval2ref = crval2
                print*, 'ref image' 
                print*, crpix1new, crpix2new, ix, iy, crval1, crval2
                print*, crp1, crp2
                xxold = (ix-crpix1new)*(-nyqpix)/3600. + crval1
                yyold = (iy-crpix2new)*nyqpix/3600. + crval2
                call radec2pix(dble(glon0),dble(glat0),ri,rj,dble(crval1), &
                     dble(crval2),dble(crpix1new),dble(crpix2new),dble(nyqpix/3600.), &
                     .false.)
                call radec2pix(dra,ddec,dble(ix),dble(iy),dble(crval1), &
                     dble(crval2),dble(crpix1new),dble(crpix2new),dble(nyqpix/3600.), &
                     .true.)
                print*, dra,ddec,xxold, yyold, ri, rj
                xxnew = (ix-crp1)*(-pixel)/3600. + crval1
                yynew = (iy-crp2)*pixel/3600. + crval2
                call radec2pix(dble(glon0),dble(glat0),ri,rj,dble(crval1), &
                     dble(crval2),dble(crp1),dble(crp2),dble(pixel/3600.), &
                     .false.)
                 call radec2pix(dra,ddec,dble(ix),dble(iy),dble(crval1), &
                     dble(crval2),dble(crp1),dble(crp2),dble(pixel/3600.), &
                     .true.)
               print*, dra,ddec,xxnew, yynew, ri, rj

                write(outfile,'(a,i4.4,a)') 'tempa_',nint(wavelengths(i)),'.fits'
                call writeimage2d(outfile,a,nx,ny,' ', &
                     ctype1,ctype2,crpix1new,crpix2new,crval1,crval2,-nyqpix/3600., &
                     nyqpix/3600.,crota2,status)
                print*, 'pixel sizes ', cdelt2/mag, nyqpix/3600.
                write(outfile,'(a,i4.4,a)') 'tempar_',nint(wavelengths(i)),'.fits'
                call writeimage2d(outfile,ar,nx,nx,' ', &
                     ctype1,ctype2,crp1,crp2,crval1,crval2,-pixel/3600., &
                     pixel/3600.,crota2,status)
             endif
            deallocate(ar)
            deallocate(armask)
            deallocate(a)
            deallocate(amask)
        enddo

! Remove any isolated zeros in coverage map.
        do j = 2,ny-1
        do i = 2,nx-1
          if (cover(i,j)==0.) then
            if ((cover(i-1,j) /= 0. .and. cover(i+1,j) /= 0.) .or. & 
                (cover(i,j-1) /= 0. .and. cover(i,j+1) /= 0.)) cover(i,j) = 1.
          endif
        enddo
        enddo

! Output a coverage map.
        outfile = removeblanks(fieldname//'_coverage.fits')
        call writeimage_wcs(outfile,cover,nx,ny,ctype1,ctype2,crp1,crp2, &
            crval1ref,crval2ref,-pixel/3600.,pixel/3600.,crota2,pixel,0.,0.,&
            status)
        print *,'Writing out '//outfile(1:40)

! Output a bad pixel mask.
        outfile = removeblanks(fieldname//'_badpix.fits')
        call writeimage_wcs(outfile,cmask,nx,ny,ctype1,ctype2,crp1,crp2, &
            crval1ref,crval2ref,-pixel/3600.,pixel/3600.,crota2,pixel,0.,0.,&
            status)
        print *,'Writing out '//outfile(1:40)
        deallocate(cmask)

! Write out reference image on the same grid as ppmap output image, with
! zero coverage portion masked out.
        afield = afield*cover
	outfile=removeblanks(fieldname//'_outfield_'//bands(irefband)//'.fits')
	print *,'Writing out '//outfile(1:40)
        wl = wavelengths(irefband)
        call writeimage_wcs(outfile,afield,nx,ny,ctype1,ctype2,crp1,crp2, &
            crval1ref,crval2ref,-pixel/3600.,pixel/3600.,crota2,pixel,wl,0.,&
            status)
        deallocate(afield)
        deallocate(cover)

        if (noverlap /= 0) then 
	    call divider(nx,ny,ncells,ncellsbest,noverlap,nnodes, &
                nsubx,nsuby,nsubxmid,nsubymid,nxmid,nymid, &
                nsubxmidlo, nsubymidlo, ilostart, jlostart)
            
            nfields = nsubx*nsuby
            allocate (ilo(nfields))
            allocate (ihi(nfields))
            allocate (jlo(nfields))
            allocate (jhi(nfields))
            ii = -1
            do n = 0,nsuby-1
            do m = 0,nsubx-1
                ii = ii+1
                ilo(ii+1) = m*(ncellsbest - noverlap)
                ihi(ii+1) = ilo(ii+1) + ncellsbest - 1
                jlo(ii+1) = n*(ncellsbest - noverlap)
                jhi(ii+1) = jlo(ii+1) + ncellsbest - 1
            enddo
            enddo

            ilo = ilo + ilostart
            ihi = ihi + ilostart
            jlo = jlo + jlostart
            jhi = jhi + jlostart

            nperlist = (nsubx*nsuby)/nnodes
            if (mod((nsubx*nsuby),nnodes) /= 0) nperlist = nperlist + 1
! Determine the sequential numbers for each of the NNODES lists.
! The array element seq(n,i) contains the ith sequence number for the nth list.
            allocate (seq(nnodes,nperlist))
            seq = - 1
            nexcess = 0
            nfields = 0
            do n = 1,nnodes
               node_used = .false. 
               do i = 1,nperlist
                  seq(n,i) = (n-1)*nperlist + i-1 ! count of which field 
                  if (seq(n,i) >= nsubx*nsuby) seq(n,i) = -1
                  if (seq(n,i) /= -1) then
                     nfields = nfields + 1
                     node_used = .true.
                  end if
               enddo
               if(node_used) nlists = nlists+1
            enddo
	    !nlists = nnodes
	    maxperlist = nperlist
        else
	    nfields = 1
            allocate (ilo(nfields))
            allocate (ihi(nfields))
            allocate (jlo(nfields))
            allocate (jhi(nfields))
	    nlists = 1
	    maxperlist = 1
	    seq = 0
	    ilo(1) = 0
	    ihi(1) = ncells-1
	    jlo(1) = 0
	    jhi(1) = ncells-1
        endif

! Read colour corrections.
        if (index(colourcorr,'NOCOLCORR')==0) then
          open (unit=2, form='formatted', file=colourcorr,status='old', &
            action='read')
	  allocate (corrc(10000,nbands))
	  allocate (x(nbands+1))
	  i = 0
          notfinished = .true.

          do while (notfinished)
	    read(2,*,IOSTAT=iostatus) x
            if (iostatus /= 0) then 
                notfinished = .false.
            else
	        i = i+1
	        tempc(i) = x(1)
                do j = 1,nbands
 	            corrc(i,j) = x(j+1)
                enddo
            endif
	  enddo
	  close(2)
          deallocate(x)
          ntc = i
        else
          ntc = 0
        endif

        outfile = removeblanks(fieldname//'_ppmap.inp')
        print *,'Writing out '//outfile(1:40)
        ihp = 0
        if (index(highpass,'y') /= 0 .or. index(highpass,'Y') /= 0) ihp = 1
        open (unit=1, form='formatted',file=outfile,status='unknown')
        write(1,'(6i8,e15.4,4f15.6,e15.6,f5.1,i5)') nbands,nfields,Nt,nbeta, &
            min(ntc,1),maxiterations,distance,kappa300,eta,betamean,sigbeta, &
            rchisqconv,trimlev,ihp
        write(1,*) betagrid
        write(1,*) psfsizes
        write(tform,'("(",i10,"f9.4)")') Nt
        tform = removeblanks(tform)
        write(1,tform) Tgrid
        if (ntc /= 0) then
	  do i = 1,nbands
	    allocate (corrset(Nt))
	    do it = 1,Nt
		itc = min(max(nint(Tgrid(it) - tempc(1))+1, 1), ntc)
		corrset(it) = corrc(itc,i)
	    enddo
	    write(1,tform) corrset
            deallocate(corrset)
	  enddo
          deallocate(corrc)
        endif
        do i = 1,nbands
            imagefile = removeblanks(fieldname//'_'//bands(i)//'.fits')
            write(1,'(a)') imagefile
        enddo
        i = 0
        allocate(used(nlists)) 
        used = 0 
        do n = 1,nlists
        do k = 1,maxperlist
           if (seq(n,k) /= -1) then 
              i = i+1
              write(1,*) i,ilo(i),ihi(i),jlo(i),jhi(i)
              used(n) = 1 
	    endif
        enddo
        enddo
        close(1)
        deallocate(ilo)
        deallocate(ihi)
        deallocate(jlo)
        deallocate(jhi)

        print*, 'n tiles per list ', nperlist
        print*, 'nlists ', nlists

        ! Generate set of scripts.
        allocate (scriptlines(nlines,nlists))
        outfile = removeblanks('run_'//fieldname//'.sh')
        open (unit=3, form='formatted',file=outfile,status='unknown')
        write(3,'(a)') 'chmod u=rwx *.sh'

        allocate (set(nperlist))

        do n = 1,nlists
	  set = seq(n,1:nperlist)
          where(set==-1) set = 100000
          isf1 = minval(set)
          set = seq(n,1:nperlist)
          isf2 = maxval(set)
	  if (isf1 /= 100000 .and. isf2 /= -1) then 
            !open (unit=1, form='formatted', file='run_ppmap.sh',status='old', &
            open (unit=1, form='formatted', file=run_ppmap_script,status='old', &
                action='read')
            write(outscript,'(a,"-",i2.2,".sh")') fieldname,n
            outscript = removeblanks(outscript)
            notfinished = .true.
            isl = 0
	    do while (notfinished)
                read(1,'(a)',IOSTAT=iostatus) line
                if (iostatus /= 0) then 
                    notfinished = .false.
                else
	            if (index(line,'#SBATCH -n') /= 0) then
                        string = '#SBATCH -n '//ncpus
                        isl = isl + 1
                        scriptlines(isl,n) =  string
                    else if(index(line,'#PBS -l select=1:ncpu') /= 0) then
                        string='select=1:ncpus='//ncpus(1:3)//':mpiprocs='//ncpus(1:3)
                        string = removeblanks(string) 
                        isl = isl + 1
                        scriptlines(isl,n) = '#PBS -l '//string
	            else if (index(line,'run_ppmap.log') /= 0) then
		        write(string,'(a,"-",i2.2,".log")') fieldname,n
                        string = removeblanks(string)
                        isl = isl + 1
                        i0 = index(line,'run_ppmap.log')
                        scriptlines(isl,n) =  line(1:i0-1)//string(1:40)
	            else if (index(line,'run_ppmap.err') /= 0) then 
		        write(string,'(a,"-",i2.2,".err")') fieldname,n
                        string = removeblanks(string)
                        isl = isl + 1
                        i0 = index(line,'run_ppmap.err')
                        scriptlines(isl,n) =  line(1:i0-1)//string(1:40)
	            else if (index(line,'run_ppmap.name') /= 0) then 
		        write(string,'(a,"-",i2.2)') fieldname,n
                        string = removeblanks(string)
                        isl = isl + 1
                        i0 = index(line,'run_ppmap.name')
                        scriptlines(isl,n) =  line(1:i0-1)//string(1:40)
	            else if (index(line,'${code}') /= 0) then 
		        if (isf2+1==nfields) then 
		            write(line,'(6x,"${code} ",a,2i6,"   mosaic")') &
			        fieldname,isf1+1,isf2+1
                            isl = isl + 1
                            scriptlines(isl,n) = line
		        else
		            write(line,'("${code} ",a,2i6)') &
                                fieldname,isf1+1,isf2+1
                            isl = isl + 1
                            scriptlines(isl,n) = line
		        endif
                    else
                        isl = isl + 1
                        scriptlines(isl,n) = line
                    endif
                endif
             enddo
             if(index(sched,'PBS') /= 0 ) then 
                write(3,'(a)') 'qsub '//outscript(1:40) ! for pbs
             else if (index(sched,'SLURM') /= 0 ) then 
                write(3,'(a)') 'sbatch '//outscript(1:40) ! for SLURM
             else
                write(string,'(a,"-",i2.2,".log")') fieldname,n
                string = removeblanks(string)
                string = ' 2>&1 | tee '//string
                write(3,'(a)') 'sh '//outscript(1:40)//string  ! standalone
             end if
             close(1)
	  endif
        enddo
        close(3)
	deallocate (wavelengths)
        deallocate (obsimages)
	deallocate (sigobs)
        deallocate (bands)
        deallocate (Tgrid)
        deallocate (beamsizes)
        deallocate (psfsizes)
        deallocate (psfset)
        deallocate (pixset)
        deallocate (seq)
        deallocate (set)

! Write out the complete set of scripts.

        do n = 1,nlists
	  if (used(n) == 1) then 
            write(outscript,'(a,"-",i2.2,".sh")') fieldname,n
            outscript = removeblanks(outscript)
	    print *,'Writing out '//outscript(1:40)
            open (unit=2,file=outscript,status='UNKNOWN')
            icode = 0
            do isl = 1,nlines
                write(2,'(a)') scriptlines(isl,n)
            enddo
            close(2)
         endif
        enddo

        print *,'Top level script is: '//outfile
        
        if (index(ctype1,'TAN') /= 0 .and.                       &
            (crv1max-crv1min > 0.1 .or. crv2max-crv2min > 0.1))  &
            print *,'WARNING: Tangent points differ in RA & Dec by', &
            crv1max-crv1min,',',crv2max-crv2min,'deg)'
        stop

        end program premap
