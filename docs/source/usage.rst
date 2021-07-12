#############
Using PPMAP
#############

===============================
Setting up the data and scripts
===============================

* To run ``ppmap`` you need to create a base directory containing your data, the corresponding psf files, a file listing the input parameters, and a script to run everything.

  - Copy your data to the base directory, as fits files in a subdirectory ``dataset``

  - Copy fits files of the psf for each band to a subdirectory ``psfset``. Circular averaged Herschel psfs are available in the directory ``ppmap/Herschel_psfs/``

  - If you are going to use a colour correction table (eg ``colourcorr_beta2.txt``), the file needs to be copied into the base directory.
  - Copy the example file of input parameters, ``example_premap.inp`` from ``ppmap/etc`` directory, and edit the parameters as necessary. This file specifies the input data files and determines the range of temperatures, beta, field size, etc to be used in the fitting.
  
  - The script ``run_ppmap_all`` will do all the steps needed to run ``premap`` and ``ppmap``. You will need to take a copy of this script from ``ppmap/etc`` and edit it to use your path names and scheduler set-up.

	  
*  ``run_ppmap_all.sh`` will create a working directory in a place that you can choose. You can specify which scheduler to use, and how many cpus are available,  and also provide a name ``NAME`` to identify a particular run. The script will copy your data, psfs and colour files to the working directory, and then run ``premap``.  This will create resampled psf files and data in the working directory, and write a sequence of scripts ``NAME-nn.sh`` which are run by a script ``run_NAME.sh``, both adapted to your choice of scheduler.
  
* Several lines in ``run_ppmap_all.sh`` will need to be adapted to match your data, and choices of path names.

   - ``NAME`` is used to identify files for a particular run of ppmap. You must have a file ``NAME_premap.inp`` to specify the ``premap`` input parameters for the run. Note, the inp filename must match the identifier that you specify, so if ``NAME`` is set to ``test``, then it will use the parameter file ``test_premap.inp``.

   - ``SCHED`` is set to your choice of scheduler, ``PBS``, ``SLURM`` or ``NONE``. This selects which ``template_run_ppmap_*`` file is used to create the ``NAME-nn.sh`` scripts, and also changes the commands in ``run_NAME.sh``. You may need to edit the ``module load`` command in ``template_run_ppmap_PBS.sh`` or ``template_run_ppmap_SLURM.sh`` to reflect loading the compiler module on your cluster. If so copy the scripts ``template_run_ppmap_*.sh`` from ``ppmap/etc`` to your base directory, and edit as necessary. If you do not need to modify them, you do not need to copy the files.
       
   - ``NCPUS`` is set to the number of CPUS available

   - ``PP_PATH`` is the path to the ppmap install directory

   - ``WORK`` is the path to the working directory used for log files and results


* Your data directory ready to run a job with ``NAME=test`` should look something like this:

::
   
   test_premap.inp
   colourcorr_beta2.txt
   dataset/
   psfset/
   run_ppmap_all.sh
   template_run_ppmap_NONE.sh
   template_run_ppmap_PBS.sh
   template_run_ppmap_SLURM.sh

Where the directory dataset contains files

::
   
		NGC4321_PACS_100.fits   NGC4321_PACS_70.fits    NGC4321_SPIRE_350.fits
		NGC4321_PACS_160.fits   NGC4321_SPIRE_250.fits  NGC4321_SPIRE_500.fits

and the directory psfset contains files

::

   psf_0070.fits psf_0160.fits psf_0350.fits
   psf_0100.fits psf_0250.fits psf_0500.fits

=======================
PREMAP input parameters
=======================

The file ``NAME_premap.inp`` sets up various parameters, ending with a list of input fits files

::
   
 Parameter value            Name of variable          Description
 
 185.72875                        <gloncent>  ; RA at centre [deg]
 15.822389                        <glatcent>  ; Dec at centre [deg]
 0.2 0.2                          <fieldsize> ; field of view dimensions [deg]
 4.0                              <pixel>     ; output sampling interval [arcsec]
 0.3                              <dilution>  ; a priori dilution 
 10000                            <maxiterat> ; max no. of integration steps
 1e-6                             <rchisqconv>; min fractional change in chi2 for convergence 
 20.4e6                           <distance>  ; [pc]
 0.1                              <kappa300>  ; reference opacity [cm^2/g]
 5                                <nbeta>     ; number of opacity law index values
 1. 1.5 2. 2.5 3.                 <betagrid>  ; opacity law index values
 2.0 0.35                         <betaprior> ; a priori mean and sigma of beta
 40                               <ncells>    ; nominal size of subfield
 20                               <noverlap>  ; size of subfield overlap
 2                                <trimlev>   ; n-sigma for sigma-clipped mean in backgrounds for mosaicing 
 colourcorr_beta2.txt             <ccfile>    ; colour correction table
 N                                <highpass>  ; high-pass filter ground-based data (Y or N) 
 6                                <Nt>        ; number of temperatures
 8.0 50.0                         <temprange> ; range of temperatures [K]
 6                                <nbands>    ; number of bands
 70 100 160 250 350 500           <wavelen>   ; wavelengths [microns]
 5.84 3.91 1.31 0.73 0.49         <sigobs>    ; sky uncertainties - will be estimated if omitted  
                                  <obsimages> ; list of FITS files follows:
 NGC4321_PACS_70.fits 
 NGC4321_PACS_100.fits 
 NGC4321_PACS_160.fits 
 NGC4321_SPIRE_250.fits 
 NGC4321_SPIRE_350.fits 
 NGC4321_SPIRE_500.fits 

The parameters are fairly self explanatory but a few explanations will help for some of them.

The parameter names ``<gloncent>`` etc. are used are identifiers in ``premap``, and so must not be changed without changing the rlevant lines within ``premap.f90``.

If ``<gloncent>`` or ``<glatcent>`` is <-900, then premap will use the mean centroid of the images as the centre of the output field.

The code ``premap`` uses ``<fieldsize>`` and ``<pixel>`` values to set the size of the output maps of density as for all of the T and beta combinations. These parameters are passed to ``<ppmap>`` via the WCS of the coverage file that ``<premap>`` creates. 

The value of ``<dilution>`` sets the a-priori expectation number of points per cell in the (x,y,T,beta) space. So the initial effective number of sources is N0=eta*Nx*Ny*Nbeta*Nt.

``<maxiterations>`` sets the maximum number of iterations in the loop to find the best  density maps.

``<chisqconv>`` sets a value to decide convergence of the iterations. If the fractional change in reduced chi2 from one step to the next is less than this value the iterations are deemed to have converged. ``abs(rchisq - rchisqprev)/rchisq < rchisqconv``

``<distance>`` and ``<kappa300>`` are used to sets the conversion from column density to mass 

``<nbeta>`` and ``<betagrid>`` specify the number of values of beta, and provide the list of actual values to use. 

``<betaprior>`` specifies the mean and standard deviation for beta. This sets the starting density rho_0 to be a Gaussian as a function of beta, using the mean and standard deviation. Essentially this acts as a prior on beta, giving more density to the chosen value. 


``<ncells>`` sets the tile size in pixels and ``<noverlap>`` sets the number pixels overlap between each tile and it's neighbours. The output map is divided into a set of overlapping tiles, and ``ppmap`` is run in parallel to produce all the tiles. When the tiles are all completed, they are mosaiced together to produce the final output maps. ``premap`` calculates the number of tiles needed to cover the field with the requested tile size and overlap. It will check to see if better coverage of the output area can be achieved by changing the cell size between ``2<noverlap>`` and ``<ncells>``, and also use an odd number of tiles. You can ensure that it will not adjust the values by choosing the field size to be ``N(<ncells>-<noverlap>) + <noverlap>`` It then divides the tiles between up to 10 independent scripts which run ``ppmap`` for all of the tiles, and mosaics them when they are all finished.  If your machine has multiple nodes, the scripts can be run in parallel on separate nodes using PBS or SLURM queue scheduling. On each node, ``ppmap`` uses OMP to carry out the matrix mutiplications in parallel if multiple cores are available on each node. The number of tiles scales as ``<ncells>**-2``, and the time taken for each tile scales roughly as the square of the number of pixels in the tile, ``<ncells>**4``. So the total time scales roughly as ``<ncells>**2``, and the smaller you make ``<ncells>``, the quicker it will run. But, if you make ``<ncells>`` too small, it will not properly include all the local information when fitting the source densities at each output sky position. Each tile should extend over at least twice the size of the largest FWHM. If you are including SPIRE 500 data, this has FWHM~36", so the tiles need to be at least 80". So using 4" pixels, the minimum ``<ncells>`` is about 20. The changes in density maps between using 20 pixel tiles and 40 pixel tiles are small, of order 0.2%, but are systematic. In practice it is safer to make it bigger, if you have the cpu cycles available.


The parameter ``<trimlevel>`` sets the number of sigma used for the n-sigma-clipped mean when adjusting the tile backgrounds in the mosaicing step to join all the tiles into the final maps. If not set it will default to 2. 

The colour correction file ``<ccfile>`` needs to list the colour correction factors for each band as a table with columns T, cc1, cc2, cc3 etc,  all specified at integer values of T, with spacing of 1K.  Then ``premap`` will select the entries to match the temperature grid as specified by Nt and range. To disable any colour corrections, set this value to ``NOCOLCORR``, or remove the ``<ccfile>`` line from the input file. 

If ``<highpass>`` is set to y or Y, the data corresponding to ground-based data will be mean subtracted within ``ppmap``.  The bands affected are selected by the quoted band wavelengths, corresponding to: SABOCA 350 microns (designated as 351 to distinguish from SPIRE 350); SCUBA2 450 microns ; SCUBA2 850 microns ; LABOCA 870 microns ; Nika2 1150 microns ; ALMA 1300 microns ; Nika2 2000 microns ; PdBI 3000 microns.


``<Nt>`` and ``<temprange>`` set the number of temperatures and the min and max values to use. The grid values are logarithmically spaced between the limits. 

``<nbands>`` is the number of bands for which you have imaging data.

``<wavelen>`` specifies the central wavelength of each band in microns. This is used to decide which bands are 'ground based` and therefore will have the mean background subtracted if ``<highpass>`` is set to Y. In particular, note that SCUBA 350 must have wavelength 351 to distinguish it from SPIRE 350. 

``<sigobs>`` sets the sky uncertainties for each band. If they are not specified, either because there is no ``<sigobs>`` line, or the entries are 0, then ``premap`` will estimate the noise by subtracting a smoothed version of each image from itself, and calculating the standard deviation of the residual image.


If set ``<snrmax>`` is used to limit the ``SIGBACK`` keyword in the fits headers of the resampled data files. 

``<obsimages>`` flags the start of the list of files names for the data in all the bands. 

================
Running PPMAP
================

* Finally you can run the script ``run_ppmap_all.sh``

.. code-block:: console
		  
	$ sh run_ppmap_all.sh

This should create your working directory, and copy your data, psfs and colour corection files there. Then it runs ``premap`` to pre-process the data and psfs, and write the scripts needed to run ``ppmap``.  ``premap`` reads the psf for each band from the fits files supplied in the ``psfset`` directory, and estimates the full-width half max values. The psf's are resampled to the requested output pixel size. Then the data files are resampled onto new images centred on the requested field centre, with pixels equal to half the FWHM, so each one is Nyquist sampled. The images are set to the same size as the output image, even though the pixel sizes are different.
The data is also rescaled to units of MJy/str, assuming the original files are in units of Jy/pixel. 

It writes a script to run ``ppmap`` on each available node, and it runs the ``run_NAME.sh`` script to submit the jobs to all of the nodes and produce the final maps. in ``WORK/NAME_results``.  The log files and error files will also found in ``WORK``.

When started each instance of ``ppmap`` reads various input parameters from a file ``NAME_ppmap.inp``. This is written by the ``premap`` program and is the same for each process. It does not need to be edited manually.



If you specified ``WORK=/scratch/${NAME}_work`` in ``run_ppmap_all.sh`` with ``NAME=test`` then the scripts intermediate files, logs and main output files will be found in ``/scratch/test_work/``.

============
Output files
============

The output files are:

* ``M100_badpix.fits`` map of bad pixels: 1 if bad; 0 if good
* ``M100_beta.fits`` map of density weighted beta 
* ``M100_cdens.fits`` column density of dust
* ``M100_coverage.fits`` area covered by the data: 1 if covered; 0 if not
* ``M100_outfield_0250.fits`` map of 250micron data using the output pixel grid
* ``M100_psfset.fits`` cube of psf data. The axis order is band, x, y. (So you need to swap the axis order to see it nicely with ds9).
* ``M100_rchisq.fits`` reduced chi2 of the fit
* ``M100_sigtdenscube.fits`` multidimensional cube of uncertainty of source density. Each slice is the map for that particular T and beta. T is axis 3, and beta axis 4.
* ``M100_tdenscube.fits`` multidimensional cube of source density. Each slice is the density map for that particular T and beta. T is axis 3, and beta axis 4.
* ``M100_temp.fits`` map of density weighted T
* ``M100_tkurt.fits`` map of kurtosis of T density distribution 
* ``M100_tskew.fits`` map of skewness of T density distribution 
* ``M100_tvar.fits`` map of variance of T density distribution

The full maps are made up from a mosaic of the individual tiles as specified in the ``premap.inp`` file. individual tile output maps are in ``/scratch/test_work/test_results``. The tiles are combined by ``ppmap`` when the final tile has finished. Each tile has a background correction applied with the aim of minimizing the sigma-clipped mean differences between overlapping tiles.

