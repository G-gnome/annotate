#!/usr/bin/bash -l
#SBATCH -p batch --time 2-0:00:00 --ntasks 8 --nodes 1 --mem 120G --out logs/sort_attempt.%a.log

module load funannotate
module load workspace/scratch
module load miniconda3

mkdir -p genomes

CPU=1
if [ $SLURM_CPUS_ON_NODE ]; then
    CPU=$SLURM_CPUS_ON_NODE
fi

SAMPFILE=metadata.tsv
INPUT=downloads
N=${SLURM_ARRAY_TASK_ID}

if [ ! $N ]; then
    N=$1
    if [ ! $N ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi
MAX=$(wc -l $SAMPFILE | awk '{print $1}')
if [ $N -gt $(expr $MAX) ]; then
    MAXSMALL=$(expr $MAX)
    echo "$N is too big, only $MAXSMALL lines in $SAMPFILE"
    exit
fi

IFS=$'\t'
tail -n +2 $SAMPFILE | sed -n ${N}p | while read ASSEMBLY ACCESSION ORGANISM_NAME _ STRAIN _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
do
  SANITIZED_ASSEMBLY=$(echo "$ASSEMBLY" | tr ' ' '_')
  SANITIZED_ORGANISM_NAME=$(echo "$ORGANISM_NAME" | tr ' ' '_')

  # Clean the input file
  funannotate clean -i "$INPUT/${SANITIZED_ORGANISM_NAME}_${SANITIZED_ASSEMBLY}.fna" -o "genomes/${SANITIZED_ORGANISM_NAME}_${SANITIZED_ASSEMBLY}.cleaned.fasta"

  # Optionally print intermediate files or debug information
  echo "Cleaned file: genomes/${SANITIZED_ORGANISM_NAME}_${SANITIZED_ASSEMBLY}.cleaned.fasta"

  # Sort the cleaned file
  funannotate sort -i "genomes/${SANITIZED_ORGANISM_NAME}_${SANITIZED_ASSEMBLY}.cleaned.fasta" -o "genomes/${SANITIZED_ORGANISM_NAME}_${SANITIZED_ASSEMBLY}.sorted.fasta" --minlen 500
  
  #cleanup
  rm genomes/${SANITIZED_ORGANISM_NAME}_${SANITIZED_ASSEMBLY}.cleaned.fasta
done
