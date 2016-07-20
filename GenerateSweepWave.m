function SweepWave = GenerateSweepWave(SamplingRate, Duration,f0,f1)
% Duration in seconds
dt = 1/SamplingRate;
ChirpDur = 0.2;
tChirp = 0:dt:ChirpDur;

chirp_tmp = chirp(tChirp,f0,ChirpDur,f1,'quadratic');

chirp_repeat = [];
for i=1:40
    chirp_repeat = [ chirp_repeat chirp_tmp]; % long enough sound; here 20sec
end

timevec = 0:dt:Duration;
SweepWave=chirp_repeat(1:length(timevec));

end

