#!/bin/bash -l
#SBATCH --nodes=1
#SBATCH --ntasks=20 --mem=96G
#SBATCH --output=logs/annotfunc.%a.log
#SBATCH --time=2-0:00:00
#SBATCH -p intel -J annotfunc

# Load/unload modules
module unload miniconda2 miniconda3 perl python
module load funannotate
module load phobius

# Set environment variables
export FUNANNOTATE_DB=/bigdata/stajichlab/shared/lib/funannotate_db
CPUS=$SLURM_CPUS_ON_NODE
OUTDIR=annotation
INDIR=genomes_to_annotate
SAMPFILE=metadata.tsv
BUSCO=fungi_odb10

# Set default value for CPUS if not provided
if [ -z "$CPUS" ]; then
  CPUS=1
fi

# Get the task ID from SLURM_ARRAY_TASK_ID or command line
N=${SLURM_ARRAY_TASK_ID}
if [ -z "$N" ]; then
  N=$1
  if [ -z "$N" ]; then
    echo "ERROR: Need to provide a number using --array or cmdline"
    exit 1
  fi
fi

# Calculate the maximum number of lines in the file
MAX=$(wc -l < "$SAMPFILE")

# Check if N is within a valid range
if [ "$N" -gt "$MAX" ]; then
  echo "ERROR: $N is too big, only $MAX lines in $SAMPFILE"
  exit 1
fi

# Read the specified line from the SAMPFILE
IFS=$'\t'
tail -n +2 "$SAMPFILE" | sed -n "${N}p" | while read ASSEMBLY ACCESSION ORGANISM_NAME _ STRAIN _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
do
  # Replace spaces with underscores in variables
  SANITIZED_ORGANISM_NAME=$(echo "$ORGANISM_NAME" | tr ' ' '_')
  SANITIZED_ASSEMBLY=$(echo "$ASSEMBLY" | tr ' ' '_')
  name=$(echo -n "${SANITIZED_ORGANISM_NAME}_${SANITIZED_ASSEMBLY}" | perl -p -e 's/\s+/_/g')
  MASKED=$(realpath "$INDIR/$name.sorted.fasta.masked")

  # Check if MASKED file exists
  if [ ! -f "$MASKED" ]; then
    echo "ERROR: Cannot find $BASE.masked.fasta in $INDIR - may not have been run yet"
    exit 1
  fi

  # Run funannotate annotate
  funannotate annotate --busco_db "$BUSCO" -i "$OUTDIR/$name" --species "$SANITIZED_ORGANISM_NAME" --strain "$STRAIN" --cpus "$CPUS" 
done
