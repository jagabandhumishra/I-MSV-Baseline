#!/usr/bin/env bash
###Speaker Verification X-vector training baseline code###

. ./cmd.sh
. ./path.sh
set -e
mfccdir=`pwd`/mfcc
vaddir=`pwd`/mfcc

dev=data/dev
enroll=data/enroll
test=data/test
trial_file='/home/iiitdwd/kaldiSpace1/kaldi/egs/I-MSV/trial_file'
nnet_dir=exp/xvector_nnet_1a

#Set switches

stage=0
Mfcc_VAD=1
Augmentation=1
prepare_feats_for_egs=1
extract_xvectors=1
compute_mean=1
Results_generation=1


if [ $Mfcc_VAD == 1 ]; then
  # Make MFCCs and compute the energy-based VAD for each dataset.Development data will be split for a length of 50 seconds. 
  steps/cleanup/split_long_utterance.sh --seg-length 50 data/dev_unsplit data/dev
  
  for name in dev dev_unsplit enroll test; do
    steps/make_mfcc.sh --write-utt2num-frames true --mfcc-config conf/mfcc.conf --nj 40 --cmd "$train_cmd" \
      data/${name} exp/make_mfcc $mfccdir
    utils/fix_data_dir.sh data/${name}
    sid/compute_vad_decision.sh --nj 40 --cmd "$train_cmd" \
      data/${name} exp/make_vad $vaddir
    utils/fix_data_dir.sh data/${name}
  done

fi

# In this section, we augment the data with reverberation,
# noise, music, and babble, and combined it with the clean data.
# The combined list will be used to train the xvector 

if [ $Augmentation == 1 ]; then
  frame_shift=0.01
  awk -v frame_shift=$frame_shift '{print $1, $2*frame_shift;}' data/dev_unsplit/utt2num_frames > data/dev_unsplit/reco2dur

  if [ ! -d "RIRS_NOISES" ]; then
    # Download the package that includes the real RIRs, simulated RIRs, isotropic noises and point-source noises
    wget --no-check-certificate http://www.openslr.org/resources/28/rirs_noises.zip
    unzip rirs_noises.zip
  fi
  

  # Make a version with reverberated speech
  rvb_opts=()
  rvb_opts+=(--rir-set-parameters "0.5, /home/iiitdwd/kaldiSpace1/kaldi/egs/sre16/v2/RIRS_NOISES/simulated_rirs/smallroom/rir_list")
  rvb_opts+=(--rir-set-parameters "0.5, /home/iiitdwd/kaldiSpace1/kaldi/egs/sre16/v2/RIRS_NOISES/simulated_rirs/mediumroom/rir_list")

  # Make a reverberated version of the training data
  
  steps/data/reverberate_data_dir.py \
    "${rvb_opts[@]}" \
    --speech-rvb-probability 1 \
    --pointsource-noise-addition-probability 0 \
    --isotropic-noise-addition-probability 0 \
    --num-replications 1 \
    --source-sampling-rate 8000 \
    data/dev_unsplit data/dev_reverb
  cp data/dev_unsplit/vad.scp data/dev_reverb/
  utils/copy_data_dir.sh --utt-suffix "-reverb" data/dev_reverb data/dev_reverb.new
  rm -rf data/dev_reverb
  mv data/dev_reverb.new data/dev_reverb

 #Download musan corpus from https://www.openslr.org/17/ and untar it.
  # Prepare the MUSAN corpus, which consists of music, speech, and noise
  # suitable for augmentation
  steps/data/make_musan.sh --sampling-rate 8000 /home/iiitdwd/kaldiSpace/database/musan data

  # Get the duration of the MUSAN recordings.  This will be used by the
  # script augment_data_dir.py.
  for name in speech noise music; do
    utils/data/get_utt2dur.sh data/musan_${name}
    mv data/musan_${name}/utt2dur data/musan_${name}/reco2dur
  done

  # Augment with musan_noise
  steps/data/augment_data_dir.py --utt-suffix "noise" --fg-interval 1 --fg-snrs "15:10:5:0" --fg-noise-dir "data/musan_noise" data/dev_unsplit data/dev_noise
  # Augment with musan_music
  steps/data/augment_data_dir.py --utt-suffix "music" --bg-snrs "15:10:8:5" --num-bg-noises "1" --bg-noise-dir "data/musan_music" data/dev_unsplit data/dev_music
  # Augment with musan_speech
  steps/data/augment_data_dir.py --utt-suffix "babble" --bg-snrs "20:17:15:13" --num-bg-noises "3:4:5:6:7" --bg-noise-dir "data/musan_speech" data/dev_unsplit data/dev_babble


  utils/combine_data.sh data/dev_aug data/dev_reverb data/dev_noise data/dev_music data/dev_babble 


  # Make MFCCs for the augmented data.  Note that we do not compute a new
  # vad.scp file here.  Instead, we use the vad.scp from the clean version of
  # the list.
  steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj 40 --cmd "$train_cmd" \
    data/dev_aug exp/make_mfcc $mfccdir
fi

# Now we prepare the features to generate examples for xvector training.
if [ $prepare_feats_for_egs == 1 ]; then
  # This script applies CMVN and removes nonspeech frames.  Note that this is somewhat
  # wasteful, as it roughly doubles the amount of training data on disk.  After
  # creating training examples, this can be removed.
  local/nnet3/xvector/prepare_feats_for_egs.sh --nj 40 --cmd "$train_cmd" \
    data/dev_aug data/dev_no_sil exp/dev_no_sil
  utils/fix_data_dir.sh data/dev_no_sil

  # Now, we need to remove features that are too short after removing silence
  # frames.  We want atleast 5s (500 frames) per utterance.
  min_len=500
  mv data/dev_no_sil/utt2num_frames data/dev_no_sil/utt2num_frames.bak
  awk -v min_len=${min_len} '$2 > min_len {print $1, $2}' data/dev_no_sil/utt2num_frames.bak > data/dev_no_sil/utt2num_frames
  utils/filter_scp.pl data/dev_no_sil/utt2num_frames data/dev_no_sil/utt2spk > data/dev_no_sil/utt2spk.new
  mv data/dev_no_sil/utt2spk.new data/dev_no_sil/utt2spk
  utils/fix_data_dir.sh data/dev_no_sil

  # We also want several utterances per speaker. Now we'll throw out speakers
  # with fewer than 8 utterances.
  min_num_utts=8
  awk '{print $1, NF-1}' data/dev_no_sil/spk2utt > data/dev_no_sil/spk2num
  awk -v min_num_utts=${min_num_utts} '$2 >= min_num_utts {print $1, $2}' data/dev_no_sil/spk2num | utils/filter_scp.pl - data/dev_no_sil/spk2utt > data/dev_no_sil/spk2utt.new
  mv data/dev_no_sil/spk2utt.new data/dev_no_sil/spk2utt
  utils/spk2utt_to_utt2spk.pl data/dev_no_sil/spk2utt > data/dev_no_sil/utt2spk

  utils/filter_scp.pl data/dev_no_sil/utt2spk data/dev_no_sil/utt2num_frames > data/dev_no_sil/utt2num_frames.new
  mv data/dev_no_sil/utt2num_frames.new data/dev_no_sil/utt2num_frames

  # Now we're ready to create training examples.
  utils/fix_data_dir.sh data/dev_no_sil


local/nnet3/xvector/run_xvector.sh --stage $stage --train-stage -1 \
  --data data/dev_no_sil --nnet-dir $nnet_dir \
  --egs-dir $nnet_dir/egs
fi
if [ $extract_xvectors == 1 ]; then

  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd " --nj 40 \
    $nnet_dir data/dev \
    exp/xvectors_dev


  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 12G" --nj 40 \
    $nnet_dir data/enroll \
    exp/xvectors_enroll

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

  # Train an PLDA model.
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


