
#####################
Installation
#####################

PPMAP is currently configured to run on the `Super Computing Wales Hawk Supercomputer <https://portal.supercomputing.wales/index.php/about-hawk/>`_ cluster. For details on the scheduler and compiler, see :ref:`Requirements`. The algorithm is hosted on GitHub:

 `https://github.com/ahoward-cf/ppmap <https://github.com/ahoward-cf/ppmap>`_

 This version has been changed to make the installation a little less
 convoluted. The basics of ``premap`` and ``ppmap`` are unchanged. 
 
=============
Requirements
=============

The current implementation of PPMAP can work wit the SLURM or PBS schedulers, and can also run with no scheduler (NONE). PPMAP takes advantage of the current Hawk ``HTC`` nodes, which each contain 40
Intel Xeon Skylake Gold 6148 2.4GHz cores and 4.8GB memory per core (for a total of 192GB per node). When PPMAP is run, it breaks down the required task into up to 10 separate jobs, scheduling each on
an independent node to run simultaniously. Individual jobs are independent of one another, and thus do not require Open MPI. The algorithm uses all 40 cores on a given node, utilising OpenMP to
decrease the operation time of individual submitted jobs. Therefore PPMAP requires OpenMP to function.

PPMAP is currently compiled with the gfortran compiler, and utilises
``-O3`` optimisation. PPMAP can also use the ifort compile, and is
known to perform well with ``ifort Version 10.0.2.199 Build
20180210``.

PPMAP also needs to link to the ``cfitsio`` library to read fits data files. This can be downloaded from `https://heasarc.gsfc.nasa.gov/fitsio/ <https://heasarc.gsfc.nasa.gov/fitsio/>`_

============================
Installing PPMAP 
============================

To install:

* Clone the repository to the desired directory ``PATH``. After cloning, you should have a ``ppmap/`` directory with the path ``PATH/ppmap/``, which contains sub-directories ``src/`` and ``etc/``.

* Move into the ``ppmap/`` direcory. Open the makefile in a text editor and make sure that the path to bash is correct and edit the ``F90COMP`` variable to point to the compiler that you are using
  
* Put a copy of ``libcfitsio.a`` in the directory ``src/``, or refer to your installed version in the ``makefile``  

* Run the makefile:

.. code-block:: console

		$ make
    
This should compile the ``premap`` and ``ppmap`` executables and place
them in the ``ppmap/bin/`` directory.

``premap`` and ``ppmap`` are now  ready to run.

