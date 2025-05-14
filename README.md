# N2HE iOS PPNN Demo1
This demo demonstrates the use of N2HE with Facial Verification and Speaker Verification. 
For Facial Verification, a facial image of the user is taken, features of the facial image is extracted and encrypted. User will then enter their username, and click on the VERIFY button. The encrypted features are sent to the server, where a pre-trained neural network classifier is used to output the encrypted result. The encrypted result will be sent back to the mobile device for decryption. An alert window will pop up to display the decrypted result, stating whether the facial image is a match with the username or not. Click on the STEP BY STEP button for a demonstration of data flow. 
For Speaker Verification, a 5-second audio is recorded from the user and features are extracted, the flow afterwards is similar to the flow of Facial Verification. 

## Prerequisites  
- Xcode >= 15.3 
- iOS >= 17.5
- COCOAPODS (https://cocoapods.org). It can be installed via homebrew:
```
brew install cocoapods
```

## Installation 
1. Download the demo zip from GitHub, or use command 
```
git clone https://github.com/HintSight-Technology/N2HE_iOS_PPNN_Demo1.git
```
2. Download the models to extract features of facial image and audio recording from [inceptionResnetV1](https://hintsightfhe-my.sharepoint.com/:u:/g/personal/kaiwen_hintsight_com/Ee1qnQIW6HFGkPSJu80gmw8BRzD1Du87ZZPFaSrsh_5UwA?e=s7rzgN) and [wav2vec2_forxvector](https://hintsightfhe-my.sharepoint.com/:u:/g/personal/kaiwen_hintsight_com/EfYZLh4WIClGm-7Oxd9trJkB6pbyMnsZgw9bpwutE4sThw?e=OVEEIg), downloaded models should be placed in directory File Resources.
3. The PyTorch C++ library (LibTorch) is installed with [CocoaPods](https://cocoapods.org), run 
```
pod install
```
4. Open ```HintsightFHE.xcworkspace``` in XCode for the demo:
```
open HintsightFHE.xcworkspace
```
