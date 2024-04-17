#!/usr/bin/bash

#SBATCH --job-name=dorado
#SBATCH --time=24:00:00
#SBATCH --partition=gpu
#SBATCH --gpus=1
#SBATCH --mem-per-gpu=8g

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
   echo "RunDirectory     the nanopore run directory containing pod5 or fast5 folder. Note automatic model selection is not available for fast5 files"
   echo "-m               basecall model to pass to dorado. {fast,hac,sup}[@v{version}] for automatic model selection, or path to existing model directory"
   echo "                 Default: '$DEFAULT_MODEL'"
   echo "-o               optional output directory. Default: RunDirectory/basecall/"
   echo "-n               optional file name for output .bam file. Default: basecall.bam"
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
      m) # model name
         MODEL=$OPTARG;;
      o) # output dir name
         OUT_DIR=$OPTARG;;
      n) # output bam name
         BAMNAME=${OPTARG%.bam};;
      d) # duplex mode
         duplex_mode=true;;
      p) # download only
         predownload_only=true;;
      f) # force overwrite output
         overwrite=true;;
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
echo "use model '${MODEL}'"

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

## read input dir
POD5_DIR=${NANOPORE_DIR}/pod5/
FAST5_DIR=${NANOPORE_DIR}/fast5/

if [ -d ${POD5_DIR} ]; then
    INPUT_DIR=${POD5_DIR}
    echo "reading reads from ${INPUT_DIR}"; else
    echo "${POD5_DIR} does not exit. try to use ${FAST5_DIR}"
    if [ -d ${FAST5_DIR} ]; then
        INPUT_DIR=${FAST5_DIR}
        echo "reading reads from ${INPUT_DIR}"; else
	echo "Make sure pod5/ or fast5/ folder exists in RunDirectory"
	exit 1; fi
    fi

## set output dir
if [ -z ${OUT_DIR+x} ]; then OUT_DIR=${NANOPORE_DIR}/basecall; fi
echo "use ${OUT_DIR} as output directory"

## make output dir if not exist
if [ ! -d $OUT_DIR ]; then mkdir $OUT_DIR; fi

## set output .bam file name
if [ -z ${BAMNAME+x} ]; then BAMNAME='basecall'; fi
BAMPATH=${OUT_DIR}/${BAMNAME}.bam

if [ -f ${BAMPATH} ]; then
    if [ ${overwrite} = false ]; then
    echo "Error: output ${BAMPATH} exists. use -f to force overwrite ${BAMPATH}"
    exit 1; fi; fi
echo "output file: $BAMPATH"

# run dorado
if [ ${duplex_mode} = false ]; then
    echo "run in simplex mode"
    dorado basecaller ${MODEL} ${INPUT_DIR} > ${BAMPATH}; else
    echo "run in duplex mode"
    dorado duplex ${MODEL} ${INPUT_DIR} > ${BAMPATH}; fi

exit 0

