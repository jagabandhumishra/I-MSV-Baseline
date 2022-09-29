#!/usr/bin/env bash
###Speaker Verification Ivector training baseline code###

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
Train_UBM=1
Train_ivector_extractor=1
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

if [ $Train_UBM == 1 ]; then
  # Train the UBM.
  sid/train_diag_ubm.sh --cmd "$train_cmd --mem 20G" \
    --nj 40 --num-threads 8  --subsample 1 \
    data/dev 512 \
    exp/diag_ubm

  sid/train_full_ubm.sh --cmd "$train_cmd --mem 25G" \
    --nj 40 --remove-low-count-gaussians false --subsample 1 \
    data/dev \
    exp/diag_ubm exp/full_ubm
fi

if [ $Train_ivector_extractor == 1 ]; then
  # Train the i-vector extractor.
  
  sid/train_ivector_extractor.sh --cmd "$train_cmd --mem 35G" \
    --ivector-dim 400 --num-iters 5 \
    exp/full_ubm/final.ubm data/dev \
    exp/extractor
fi

if [ $Extract_ivectors == 1 ]; then
  # Extract i-vectors for dev and enroll data
  sid/extract_ivectors.sh --cmd "$train_cmd --mem 6G" --nj 40 \
    exp/extractor data/dev \
    exp/ivectors_dev

 
  # enroll data
  sid/extract_ivectors.sh --cmd "$train_cmd --mem 6G" --nj 40 \
    exp/extractor data/enroll \
    exp/ivectors_enroll
    
      # test data
  sid/extract_ivectors.sh --cmd "$train_cmd --mem 6G" --nj 40 \
    exp/extractor data/test \
    exp/ivectors_test
fi

if [ $Compute_mean_vector == 1 ]; then
  # Compute the mean vector for centering the evaluation i-vectors.
  $train_cmd exp/ivectors_dev/log/compute_mean.log \
    ivector-mean scp:exp/ivectors_dev/ivector.scp \
    exp/ivectors_dev/mean.vec || exit 1;

  # This script uses LDA to decrease the dimensionality prior to PLDA.
  lda_dim=200
  $train_cmd exp/ivectors_dev/log/lda.log \
    ivector-compute-lda --total-covariance-factor=0.0 --dim=$lda_dim \
    "ark:ivector-subtract-global-mean scp:exp/ivectors_dev/ivector.scp ark:- |" \
    ark:data/dev/utt2spk exp/ivectors_dev/transform.mat || exit 1;

  #  Train the PLDA model.
  $train_cmd exp/ivectors_dev/log/plda.log \
    ivector-compute-plda ark:data/dev/spk2utt \
    "ark:ivector-subtract-global-mean scp:exp/ivectors_dev/ivector.scp ark:- | transform-vec exp/ivectors_dev/transform.mat ark:- ark:- | ivector-normalize-length ark:-  ark:- |" \
    exp/ivectors_dev/plda || exit 1;

  
fi

if [ $Results_generation == 1 ]; then
  # Get results using the out-of-domain PLDA model
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


