# Instructions to run baseline I-vector and X-vector systems.
## Pre-requisites:
1. Kaldi toolkit should be installed from https://github.com/kaldi-asr/kaldi
2. Musan noise corpus must be downloaded from https://www.openslr.org/17/
3. IITG MV development and enroll database should be downloaded from https://drive.google.com/drive/folders/1YcBY0SgO2ErnMcHrvTPnjFkENX0RUMyY
4. IITG MV public test data should be downloaded from https://drive.google.com/drive/folders/1n1zZYvx8rFw0vUy20vGFMLL-kQUbV3CB
5. I-vector trained model can be downloaded from https://drive.google.com/drive/folders/12d8hK6kyqhr4Thomod9MmpKwTSGZdyMA?usp=sharing

## Train and test an I-vector system
1. Git clone the repository
	git clone https://github.com/jagabandhumishra/I-MSV-Baseline.git
2. Path of the development database should be changed in  I-MSV-Baseline/I-vector/data/dev/wav.scp file.
3. Path of the enrollment database should be changed in  I-MSV-Baseline/I-vector/data/enroll/wav.scp file.
4. Path of the test database should be changed in  I-MSV-Baseline/I-vector/data/test/wav.scp file.
5. Create trial file using trial_file_creation.py script.
	Trial file should be of the format:
	spkid utterance target/nontarget
	2047 test_public_2293 nontarget
	2102 test_public_2293 target
6. Set the path of trial file in run.sh script under Change Input values section
7. set the switches in run.sh script
8. Run the run script. (./run.sh)
9. EER will be displayed on the terminal.

## Train and test an x-vector system
1. Git clone the repository
	git clone https://github.com/jagabandhumishra/I-MSV-Baseline.git
2. Path of the development database should be changed in  I-MSV-Baseline/x-vector/data/dev/wav.scp file.
3. Path of the enrollment database should be changed in  I-MSV-Baseline/x-vector/data/enroll/wav.scp file.
4. Path of the test database should be changed in  I-MSV-Baseline/x-vector/data/test/wav.scp file.
5. Create trial file using trial_file_creation.py script.
	Trial file should be of the format:
	spkid utterance target/nontarget
	2047 test_public_2293 nontarget
	2102 test_public_2293 target
6. Set the path of trial file in run.sh script under Change Input values section
7. Set the path of output directory. Eg: exp/xvector_nnet_1a
8. set the switches in run.sh script
9. Run the run script. (./run.sh)

## Test with pretrained Voxceleb model.
1. Set the trial file location in voxceleb_testing.sh script.
2. Execute the run script.(./run.sh)
9. EER will be displayed on the terminal.
