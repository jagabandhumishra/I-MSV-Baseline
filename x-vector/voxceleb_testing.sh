#!/usr/bin/env bash
# Testing script to test with Voxceleb pretrained model

. ./cmd.sh
. ./path.sh
set -e
mfccdir=`pwd`/mfcc
vaddir=`pwd`/mfcc

dev=data/dev
enroll=data/enroll
test=data/test
trial_file='/home/iiitdwd/kaldiSpace1/kaldi/egs/I-MSV/trial_file'
nnet_dir=voxceleb_model/xvector_nnet_1a

stage=0
Mfcc_VAD=1
extract_xvectors=1
compute_mean=1
Results_generation=1




if [ $Mfcc_VAD == 1 ]; then
  # Make MFCCs and compute the energy-based VAD for each dataset
  steps/cleanup/split_long_utterance.sh --seg-length 50 data/dev_unsplit data/dev
  
  for name in dev dev_unsplit enroll test; do
    steps/make_mfcc.sh --write-utt2num-frames true --mfcc-config conf/mfcc_16k.conf --nj 40 --cmd "$train_cmd" \
      data/${name} exp/make_mfcc $mfccdir
    utils/fix_data_dir.sh data/${name}
    sid/compute_vad_decision.sh --nj 40 --cmd "$train_cmd" \
      data/${name} exp/make_vad $vaddir
    utils/fix_data_dir.sh data/${name}
  done

fi

if [ $extract_xvectors == 1 ]; then

  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd " --nj 40 \
    $nnet_dir data/dev \
    exp/xvectors_dev

  # Extract xvectors 
  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 12G" --nj 40 \
    $nnet_dir data/enroll \
    exp/xvectors_enroll

  # test data
  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd " --nj 40 \
    $nnet_dir data/test \
    exp/xvectors_test


fi

if [ $compute_mean == 1 ]; then
  # Compute the mean vector for centering the evaluation xvectors.
  $train_cmd exp/xvectors_dev/log/compute_mean.log \
    ivector-mean scp:exp/xvectors_dev/xvector.scp \
    exp/xvectors_dev/mean.vec || exit 1;

  # This script uses LDA to decrease the dimensionality prior to PLDA.
  lda_dim=150
  $train_cmd exp/xvectors_dev/log/lda.log \
    ivector-compute-lda --total-covariance-factor=0.0 --dim=$lda_dim \
    "ark:ivector-subtract-global-mean scp:exp/xvectors_dev/xvector.scp ark:- |" \
    ark:data/dev/utt2spk exp/xvectors_dev/transform.mat || exit 1;

  # Train a PLDA model.
  $train_cmd exp/xvectors_dev/log/plda.log \
    ivector-compute-plda ark:data/dev/spk2utt \
    "ark:ivector-subtract-global-mean scp:exp/xvectors_dev/xvector.scp ark:- | transform-vec exp/xvectors_dev/transform.mat ark:- ark:- | ivector-normalize-length ark:-  ark:- |" \
    exp/xvectors_dev/plda || exit 1;

 fi

if [ $Results_generation == 1 ]; then
  # Get results using the PLDA model.
  $train_cmd exp/scores/log/eval_scoring.log \
    ivector-plda-scoring --normalize-length=true \
    --num-utts=ark:exp/xvectors_enroll/num_utts.ark \
    "ivector-copy-plda --smoothing=0.0 exp/xvectors_dev/plda - |" \
    "ark:ivector-mean ark:data/enroll/spk2utt scp:exp/xvectors_enroll/xvector.scp ark:- | ivector-subtract-global-mean exp/xvectors_dev/mean.vec ark:- ark:- | transform-vec exp/xvectors_dev/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "ark:ivector-subtract-global-mean exp/xvectors_dev/mean.vec scp:exp/xvectors_test/xvector.scp ark:- | transform-vec exp/xvectors_dev/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "cat '$trial_file' | cut -d\  --fields=1,2 |" exp/scores/eval_scores || exit 1;



eer=$(paste $trial_file exp/scores/eval_scores | awk '{print $6, $3}' | compute-eer - 2>/dev/null)
echo "EER:"$eer
fi


