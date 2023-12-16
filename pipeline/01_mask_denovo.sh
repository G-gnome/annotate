#!/bin/bash -l
#SBATCH -p batch -N 1 -c 16 --mem 24gb --out logs/annotate_mask.%a.log

module unload miniconda3

CPU=1
if [ $SLURM_CPUS_ON_NODE ]; then
    CPU=$SLURM_CPUS_ON_NODE
fi

INDIR=genomes
OUTDIR=genomes_to_annotate
MASKDIR=RepeatMasker_run
SAMPLES=metadata.tsv
RMLIBFOLDER=repeat_library
mkdir -p $RMLIBFOLDER $MASKDIR $OUTDIR
RMLIBFOLDER=$(realpath $RMLIBFOLDER)

N=${SLURM_ARRAY_TASK_ID}
if [ -z $N ]; then
    N=$1
    if [ -z $N ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi
MAX=$(wc -l $SAMPLES | awk '{print $1}')
if [ $N -gt $MAX ]; then
    echo "$N is too big, only $MAX lines in $SAMPLES"
    exit
fi

IFS=$'\t'
tail -n +2 $SAMPLES | sed -n ${N}p | while read ASSEMBLY ACCESSION ORGANISM_NAME _ STRAIN _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
do
    # Replace spaces with underscores in variables
    SANITIZED_ASSEMBLY=$(echo "$ASSEMBLY" | tr ' ' '_')
    SANITIZED_ORGANISM_NAME=$(echo "$ORGANISM_NAME" | tr ' ' '_')
    name=$(echo -n ${SANITIZED_ORGANISM_NAME}_${SANITIZED_ASSEMBLY} | perl -p -e 's/\s+/_/g')

    if [ ! -f $INDIR/${name}.sorted.fasta ]; then
        echo "Cannot find $name.fasta in $INDIR - may not have been run yet"
        exit
    fi

    OUTNAME=$OUTDIR/${name}.masked.fasta
    if [ ! -s $OUTDIR/${name}.masked.fasta ]; then
        mkdir -p $MASKDIR/${name}
        GENOME=$(realpath $INDIR/${name}.sorted.fasta)
        if [ ! -f $MASKDIR/${name}/${name}.fasta.masked ]; then
            LIBRARY=$RMLIBFOLDER/$name.repeatmodeler.lib
            if [ ! -f $LIBRARY ]; then
                module load RepeatModeler
                pushd $MASKDIR/${name}
                BuildDatabase -name $name $GENOME
                RepeatModeler -threads $CPU -database $name -LTRStruct
                cp */consensi.fa.classified $LIBRARY
                cp */families-classified.stk $RMLIBFOLDER/$name.repeatmodeler.stk
                popd
            fi

            if [ -f $LIBRARY ]; then
                module load RepeatMasker
                RepeatMasker -e ncbi -xsmall -s -pa $CPU -lib $LIBRARY -dir $MASKDIR/${name} -gff $INDIR/${name}.sorted.fasta
            fi
        fi

        cp $MASKDIR/${name}/${name}.sorted.fasta.masked $OUTNAME
    else
        echo "Skipping ${name} as masked file already exists"
    fi
done
