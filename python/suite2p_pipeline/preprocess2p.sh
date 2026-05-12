#!/bin/bash
# Job name:
#SBATCH --job-name=HS210617_59
#
# Partition:
#SBATCH --partition=savio2_bigmem
#SBATCH --nodes=1
#
#SBATCH --account=fc_adesnik
#SBATCH --qos=savio_normal
#
# Wall clock limit:
#SBATCH --time=24:00:00
#
# mail alert state
#SBATCH --mail-type=all
#
# send mail to this address
#SBATCH --mail-user=hyeyoung_shin@berkeley.edu
#
## Command(s) to run:

echo "conversion start"

## module load matlab # do this in command line before running sbatch
matlab -nosplash -nodesktop -r "mesoscope_json_from_scanimage_210617_59; exit"

echo "conversion complete"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python "$SCRIPT_DIR/suite2p_pipeline_210617_59.py"

echo "don't forget to move data!"
#ssh dtn
#rclone copy /global/scratch/hyeyoung_shin/200120/200120PM/PMT01 remote:DATA/ICexpts/HS_VIPtdTomSynGC7f_1/200120/200120PM/PMT01
