#!/usr/bin/bash -l
#SBATCH --nodes 1 --ntasks 8 --mem 16G --out logs/antismash.%a.log -J antismash

module load antismash
which antismash
hostname
CPU=1
if [ ! -z $SLURM_CPUS_ON_NODE ]; then
  CPU=$SLURM_CPUS_ON_NODE
fi
OUTDIR=antismash
SAMPFILE=metadata.tsv
INDIR=annotation
INPUTFOLDER=predict_results
N=${SLURM_ARRAY_TASK_ID}
if [ ! $N ]; then
  N=$1
  if [ ! $N ]; then
    echo "need to provide a number by --array or cmdline"
    exit
  fi
fi
MAX=`wc -l $SAMPFILE | awk '{print $1}'`

if [ $N -gt $MAX ]; then
  echo "$N is too big, only $MAX lines in $SAMPFILE"
  exit
fi

IFS=$'\t'
tail -n +2 $SAMPFILE | sed -n ${N}p | while read ASSEMBLY ACCESSION ORGANISM_NAME _ STRAIN _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
do
    # Replace spaces with underscores in variables
    SANITIZED_ORGANISM_NAME=$(echo "$ORGANISM_NAME" | tr ' ' '_')
    SANITIZED_ASSEMBLY=$(echo "$ASSEMBLY" | tr ' ' '_')
    name=$(echo -n ${SANITIZED_ORGANISM_NAME}_${SANITIZED_ASSEMBLY} | perl -p -e 's/\s+/_/g')
  if [ ! -d $INDIR/$name ]; then
    echo "No annotation dir for ${name}"
    exit
  fi
  echo "processing $INDIR/$name"
  if [[ ! -d $OUTDIR/$name/antismash_local && ! -s $OUTDIR/$name/antismash_local/index.html ]]; then
    #   antismash --taxon fungi --output-dir $OUTDIR/$name/antismash_local  --genefinding-tool none \
      #    --asf --fullhmmer --cassis --clusterhmmer --asf --cb-general --pfam2go --cb-subclusters --cb-knownclusters -c $CPU \
      #    $OUTDIR/$name/$INPUTFOLDER/*.gbk
    mkdir -p $OUTDIR/$name/antismash_local
    time antismash --taxon fungi --output-dir $OUTDIR/$name/antismash_local \
      --genefinding-tool none --fullhmmer --clusterhmmer --cb-general \
      --pfam2go -c $CPU $INDIR/$name/$INPUTFOLDER/*.gbk
  fi
done
