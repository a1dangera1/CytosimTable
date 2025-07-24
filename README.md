# CytosimTable

a MATLAB utility for processing output files from [Cytosim](http://www.cytosim.org/) this tool reads .txt result files extracts structured data and outputs a Matlab table

## Features

Automatic mode: Scans subfolders for result files and organizes them by subfolder
Manual Mode: process explicitly listed result files.
Flexible file filteringby result type(IE: solid_position, couple_state)
Outputs clean, structured MATLAB variables ready for analysis


## Getting started
A code used for MATLAB that will import data reported by Cytosim into a readily usable table format

If you have not already downloaded Cytosim, please do so [here](https://gitlab.com/f-nedelec/cytosiml)

The purpose of this document is to create an understanding of the MATLAB software presented.

## example usage

### automatic mode

userInput.automode = 'on';
userInput.workDir = 'C:/simulations';
userInput.resultTypes = {'solid_position', 'couple_state'}; % Optional
userInput.tableName = 'MyStructOutput'; % Optional
CytosimTable(userInput);

### manual mode

userInput.automode = 'off';
userInput.cytosimFilePaths = {
    'C:/simA/solid_position0000.txt';
    'C:/simA/couple_state0000.txt'
};
userInput.tableName = 'MyTableOutput'; % Optional
CytosimTable(userInput);

## Bash Script

To run batches of code simultaneously, you will want to download [Python](https://www.python.org/) and locate preconfig.py. It should be under python\run.

Place the preconfig.py file in any folder you wish to run batches of Cytosim models from. For a better understanding of the ways you can run multiple models, please read the preconfig.py document.

the file you will be running will be config.cym.tpl the file makeup of a config.cym.tpl file is exactly the same as a config.cym except multiple parameters can be run at once.

**IE:** fibers = [[ [ 10, 50, 100, 500, etc] ]]. 

running preconfig.py with config.cym.tpl will


