#!/usr/bin/bash

#SBATCH --job-name=dorado
#SBATCH --time=24:00:00
#SBATCH --account=tyjames1
#SBATCH --partition=gpu
#SBATCH --gpus=1
#SBATCH --mem-per-gpu=8g

# Modify and un-comment these SBATCH parameters for recieving email notification
##SBATCH --mail-user=[id]@umich.edu
##SBATCH --mail-type=BEGIN,END,FAIL
##SBATCH --output=[output_directory]/%x-%j.log
##SBATCH --error=[output_directory]/%x-%j-E.log

DEFAULT_MODEL='sup'

duplex_mode=false
overwrite=false
predownload_only=false

Help()
{
   echo
   echo "Syntax: dorado_basecall.sh [-m model] [-o OutDirectory] [-n BamFileName] [-d|-p|-f|-h] RunDirectory"
   echo
   echo "options:"
   echo "RunDirectory     the nanopore run directory containing pod5 folder"
   echo "-m               basecall model to pass to dorado. {fast,hac,sup}[@v{version}] for automatic model selection, or path to existing model directory"
   echo "                 Default: '$DEFAULT_MODEL'"
   echo "-o               optional output directory. Default: RunDirectory/basecall"
   echo "-n               optional file name for output .bam file. Default: the name of RunDirectory"
   echo "-d               duplex mode"
   echo "-p               pre-download model without actually running dorado. need to specify full model name in -m"
   echo "-f               force overwrite output"
   echo "-h               show this message"
   echo
   echo
}

# Get the options
if [ "$#" == 0 ]; then
  Help
  exit 1
fi

while getopts "m:o:n:dpfh" option; do
   case $option in
      h) # display Help
         Help
         exit 1;;
      m) # Enter a name
         MODEL=$OPTARG;;
      o) # Enter a name
         OUT_DIR=$OPTARG;;
      n) # Enter a name
         BAMNAME=${OPTARG%.bam};;
      d) duplex_mode=true;;
      p) predownload_only=true;;
      f) overwrite=true;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit 1;;
   esac
done

shift $((OPTIND - 1))

# LOAD MODULES
module purge
module load Bioinformatics
module load dorado/0.5.3 

# DEFINE VARIABLES AND MAKE DIRECTORIES
## nanopore dir
NANOPORE_DIR=$1

## set dorado model
if [ -z ${MODEL+x} ]; then 
    MODEL=${DEFAULT_MODEL}; fi
echo "use model ${MODEL}"

# pre-download dorado model if not exist
if [ ${predownload_only} = true ]; then
    if [ -d ${MODEL} ]; then
        if [ "$(ls -A ${MODEL})" ]; then
        echo "${MODEL} exist" ; else
        echo "remove empty folder then redownload" && rm -d "${MODEL}" && dorado download --model "${MODEL}"; fi; else
        echo "download model"; dorado download --model "${MODEL}"
        fi
    exit 0
fi

## set output dir
if [ -z ${OUT_DIR+x} ]; then OUT_DIR=${NANOPORE_DIR}/basecall; fi
echo "use ${OUT_DIR} as output directory"

## make output dir if not exist
if [ ! -d $OUT_DIR ]; then mkdir $OUT_DIR; fi

## set output .bam file name
if [ -z ${BAMNAME+x} ]; then BAMNAME=${NANOPORE_DIR%/}; fi
BAMPATH=${OUT_DIR}/${BAMNAME}.bam

if [ -f ${BAMPATH} ]; then
    if [ ${overwrite} = false ]; then
    echo "Error: output ${BAMPATH} exists. use -f to force overwrite ${BAMPATH}"
    exit 1; fi; fi
echo "output file: $BAMPATH"

## report run mode
if [ ${duplex_mode} = false ]; then
    echo "run in simplex mode"; else
    echo "run in duplex mode"; fi

# run dorado
if [ ${duplex_mode} = false ]; then
    dorado basecaller ${MODEL} ${NANOPORE_DIR}/pod5/ > ${BAMPATH}; else
    dorado duplex ${MODEL} ${NANOPORE_DIR}/pod5/ > ${BAMPATH}; fi

exit 0
