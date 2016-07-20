function BeatWave = GenerateBeatWave(SamplingRate, Frequency, Duration)
% Duration in seconds
dt = 1/SamplingRate;
t = 0:dt:Duration;
FreqDiff = 5;
BeatWave=sin(2*pi*Frequency*t) + sin(2*pi*(Frequency-FreqDiff)*t);
