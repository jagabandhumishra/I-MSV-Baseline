#!/usr/bin/env bash
###Speaker Verification Ivector testing###

. ./cmd.sh
. ./path.sh
set -e
### Change Input values ###

mfccdir=`pwd`/mfcc
vaddir=`pwd`/mfcc
dev=data/dev
enroll=data/enroll
test=data/test
trial_file='/home/iiitdwd/kaldiSpace1/kaldi/egs/I-MSV/trial_file'



#set switches

Mfcc_VAD=1
Extract_ivectors=1
Compute_mean_vector=1
Results_generation=1

if [ $Mfcc_VAD == 1 ]; then
  # Make MFCCs and compute the energy-based VAD for each dataset
  for name in dev enroll test; do
    steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj 40 --cmd "$train_cmd" \
      data/${name} exp/make_mfcc $mfccdir
    utils/fix_data_dir.sh data/${name}
    sid/compute_vad_decision.sh --nj 40 --cmd "$train_cmd" \
      data/${name} exp/make_vad $vaddir
    utils/fix_data_dir.sh data/${name}
  done
fi


if [ $Extract_ivectors == 1 ]; then
    
      # test data
  sid/extract_ivectors.sh --cmd "$train_cmd --mem 6G" --nj 40 \
    exp/extractor data/test \
    exp/ivectors_test
fi



if [ $Results_generation == 1 ]; then
  # Get results using the PLDA model
  $train_cmd exp/scores/log/eval_scoring.log \
    ivector-plda-scoring --normalize-length=true \
    --num-utts=ark:exp/ivectors_enroll/num_utts.ark \
    "ivector-copy-plda --smoothing=0.0 exp/ivectors_dev/plda - |" \
    "ark:ivector-mean ark:data/enroll/spk2utt scp:exp/ivectors_enroll/ivector.scp ark:- | ivector-subtract-global-mean exp/ivectors_dev/mean.vec ark:- ark:- | transform-vec exp/ivectors_dev/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "ark:ivector-subtract-global-mean exp/ivectors_dev/mean.vec scp:exp/ivectors_test/ivector.scp ark:- | transform-vec exp/ivectors_dev/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "cat '$trial_file' | cut -d\  --fields=1,2 |" exp/scores/eval_scores || exit 1;



eer=$(paste $trial_file exp/scores/eval_scores | awk '{print $6, $3}' | compute-eer - 2>/dev/null)
echo "EER:"$eer
fi


