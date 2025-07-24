# CytosimTable

a MATLAB utility for processing output files from [Cytosim](http://www.cytosim.org/) this tool reads .txt result files extracts structured data and outputs a Matlab table

##Features##

Automatic mode: Scans subfolders for result files and organizes them by subfolder
Manual Mode: process explicitly listed result files.
Flexible file filteringby result type(IE: solid_position, couple_state)
Outputs clean, structured MATLAB variables ready for analysis

A code used for matlab that will import data reported by cytosim into a readily usable table format

If you have not already downloaded Cytosim please do so [here](https://gitlab.com/f-nedelec/cytosiml)

The purpose of this document is to create an understanding of the MATLAB software presented.


**Bash Script**

To run batches of code simultaneously, you will want to download [Python](https://www.python.org/) and locate preconfig.py. It should be under python\run.

Place the preconfig.py file in any folder you wish to run batches of cytosim models out of. For a better understanding of the ways you can run multiple models, please read the preconfig.py document




**CytosimMasterTable**

to utilize any of the software 
