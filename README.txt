# usage
Syntax: dorado_basecall.sh [-m model] [-o OutDirectory] [-n BamFileName] [-d|-p|-f|-h] RunDirectory

options:
RunDirectory     the nanopore run directory containing pod5 folder
-m               basecall model to pass to dorado. {fast,hac,sup}[@v{version}] for automatic model selection, or path to existing model directory
                 Default: 'sup'
-o               optional output directory. Default: RunDirectory/basecall
-n               optional file name for output .bam file. Default: the name of RunDirectory
-d               duplex mode
-p               pre-download model without actually running dorado. need to specify full model name in -m
-f               force overwrite output
-h               show this message


# convert fast5 to pod5 (the new default format in MinKNOW)
module load python
pip install --user pod5 #install pod5 toolkit
cd testdata
pod5 convert fast5 ./fast5/*.fast5 --output pod5 --one-to-one ./fast5/
cd ../

# minimum dorado test run
sbatch -o simplex.log dorado_basecall.sh testdata #run in simplex mode
sbatch -o duplex.log dorado_basecall.sh -d -n testdata_duplex testdata #run in duplex mode
