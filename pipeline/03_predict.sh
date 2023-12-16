#!/usr/bin/bash -l
#SBATCH -p batch --time 3-0:00:00 --ntasks 21 --nodes 1 --mem 48G --out logs/annotate_predict.%a.log

module load funannotate

# This will define $SCRATCH variable if you don't have this on your system you can basically do this depending on
# where you have temp storage space and fast disks
module load workspace/scratch

CPU=1
if [ $SLURM_CPUS_ON_NODE ]; then
    CPU=$SLURM_CPUS_ON_NODE
fi

BUSCO=basidiomycota_odb10 # This could be changed to the core BUSCO set you want to use
INDIR=genomes_to_annotate
OUTDIR=annotation
mkdir -p $OUTDIR
SAMPFILE=metadata.tsv

N=${SLURM_ARRAY_TASK_ID}

if [ -z $N ]; then
    N=$1
    if [ -z $N ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi
MAX=$(wc -l $SAMPFILE | awk '{print $1}')

if [ $N -gt $MAX ]; then
    echo "$N is too big, only $MAX lines in $SAMPFILE"
    exit
fi

#export AUGUSTUS_CONFIG_PATH=$(realpath lib/augustus/3.3/config)
export FUNANNOTATE_DB=/bigdata/stajichlab/shared/lib/funannotate_db

SEED_SPECIES=ustilago
SEQCENTER=UCR
IFS=$'\t'
tail -n +2 $SAMPFILE | sed -n ${N}p | while read ASSEMBLY ACCESSION ORGANISM_NAME _ STRAIN _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
do
    # Replace spaces with underscores in variables
    SANITIZED_ASSEMBLY=$(echo "$ASSEMBLY" | tr ' ' '_')
    SANITIZED_ORGANISM_NAME=$(echo "$ORGANISM_NAME" | tr ' ' '_')
    name=$(echo -n ${SANITIZED_ORGANISM_NAME}_${SANITIZED_ASSEMBLY} | perl -p -e 's/\s+/_/g')

    MASKED=$INDIR/${name}.sorted.fasta.masked
    echo "masked is $MASKED ($INDIR/${name}.sorted.fasta.masked)"
    if [ ! -f $MASKED ]; then
        echo "no masked file $MASKED"
        exit
    fi
    echo "MASKED is $MASKED"

    time funannotate predict --cpus $CPU --keep_no_stops --SeqCenter $SEQCENTER \
                --busco_db $BUSCO --header_length 18 \
                --strain $STRAIN --min_training_models 100 \
                --AUGUSTUS_CONFIG_PATH $AUGUSTUS_CONFIG_PATH \
                -i $MASKED --name $name \
                --protein_evidence $FUNANNOTATE_DB/uniprot_sprot.fasta \
                -s "$SANITIZED_ORGANISM_NAME" -o $OUTDIR/${name} --tmpdir $SCRATCH \
    --force
    #--busco_seed_species $SEED_SPECIES
done
