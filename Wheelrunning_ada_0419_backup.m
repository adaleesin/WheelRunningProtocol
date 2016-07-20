function Wheelrunning_ada
% AudGonogo_3
% Hyun-Jae Pi, May30 2016

global BpodSystem

%% Program PulsePal
%load(fullfile(BpodSystem.ProtocolPath, 'AudGonogo_PulsePalProgram.mat'));
%ProgramPulsePal(ParameterMatrix);

%% ******************************************
% Training Level
TrainingLevel =1; % option 1, 2 ,3, 4

switch TrainingLevel
    case 1 
        airpuff_dur = 0;
        TrialTypeProbs = [1 0];   % Go A only
    case 2 
        airpuff_dur = 0.1;
        TrialTypeProbs = [0 1];  % Go B only
    case 3 % task without air puff
        airpuff_dur = 0.1;
        TrialTypeProbs = [0.5 0.5];  % trial types --- Go A, Go B,
end

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings

    S.SoundDuration=1;          %sec
    S.SoundRamping=0.4;         %sec
    S.GUI.MeanSoundFrequencyA = 1000;   %Hz
    S.GUI.MeanSoundFrequencyB = 20000;  %Hz
    for i=1:29
    MeanSoundFrequency(i)=1000+(i-1)*(20000-1000)/29;  %Hz
    end
        
    WidthOfFrequencies=4;
    NumberOfFrequencies=5;
    S.GUI.RewardAmount = 12; % defalut 5, amount of reward delivered to the mouse in microliters
    S.TrialTypeProbs = TrialTypeProbs; %Probability of trial types 1(go) & 2(nogo) in the session
%     S.ITI = 1;
    S.WaitForRunDur =10;
    
end

%% Define trials
maxTrials = 5000;
S.TrialTypes = zeros(1,maxTrials);
for x = 1:maxTrials
    P = rand;
    Cutoffs = cumsum(S.TrialTypeProbs);
    Found = 0;
    for y = 1:length(S.TrialTypeProbs)
        if P<Cutoffs(y) && Found == 0
            Found = 1;
            S.TrialTypes(x) = y;
        end
    end
end


%% Initialize parameter GUI plugin
BpodParameterGUI('init', S);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.
%% Initialize plots
BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [400 600 1000 200],'Name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.075 .3 .89 .6]);
OutcomePlot_AudGonogo(BpodSystem.GUIHandles.OutcomePlot,'init',2-S.TrialTypes);
BpodNotebook('init');

%% Define stimuli and send to sound server
SF = 192000; % Sound card sampling rate
% noise=randn(1,SF);
% noise=noise/max(abs(noise));
Sound1=SoundGenerator(SF, S.GUI.MeanSoundFrequencyA, WidthOfFrequencies, NumberOfFrequencies, S.SoundDuration, S.SoundRamping);
Sound2=SoundGenerator(SF, S.GUI.MeanSoundFrequencyB, WidthOfFrequencies, NumberOfFrequencies, S.SoundDuration, S.SoundRamping);
for i=1:29
Sound_run(i,:)= GenerateSineWave(SF, MeanSoundFrequency(i), 0.2); % Sampling freq (hz), Sine frequency (hz), duration (s)
end


% Program sound server
PsychToolboxSoundServer('init');

for i=1:29
PsychToolboxSoundServer('Load', i, Sound_run(i,:)); %PsychToolboxSoundServer('load', SoundID, Waveform)
end
% PsychToolboxSoundServer('Load', 30, noise);
PsychToolboxSoundServer('Load', 31, Sound1); %PsychToolboxSoundServer('load', SoundID, Waveform)
PsychToolboxSoundServer('Load', 32, Sound2); %Sounds are triggered by sending a soft code back to the governing computer 
                                            %from a trial's state matrix, and calling PsychToolboxSoundServer from a predetermined 
                                            %soft code handler function.
% Set soft code handler to trigger sounds
BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler_PlaySound';


%% Main loop
for currentTrial = 1:maxTrials
    disp(['Trial # ' num2str(currentTrial) ': trial type ' num2str(S.TrialTypes(currentTrial))]);
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    
    switch S.TrialTypes(currentTrial)
        case 1  % Go A; 
            %ParameterMatrix{5,2} = 0.0001; % Set PulsePal to 100us pulse width on output channel 1
            %ParameterMatrix{8,2} = 0.0001; % Set PulsePal to 100us pulse interval on output channel 1
%             StateReinforcer = 'TriggerReward_A';
            OutputActionArgument = {'SoftCode', 31,'BNCState', 1};  % generate sound
        case 2  % Go B; 
            %ParameterMatrix{5,2} = 0.001; % Set PulsePal to 100us pulse width on output channel 1
            %ParameterMatrix{8,2} = 0.001; % Set PulsePal to 100us pulse interval on output channel 1
%             StateReinforcer = 'TriggerReward_B';
            OutputActionArgument = {'SoftCode', 32,'BNCState', 2};

    end
    %ProgramPulsePal(ParameterMatrix);
    WaterTime = GetValveTimes(S.GUI.RewardAmount,[1]); % This code gets the time valves 2 (valve code)must be open to deliver liquid being set. 

%     S.ReinforcementDelays(currentTrial) = random('Normal',1,1);
        S.ReinforcementDelays(currentTrial) = 1;
    %     Assemble state matrix
    sma = NewStateMatrix();
    sma = SetGlobalCounter(sma, 1, 'BNC1High', 1);
    sma = SetGlobalCounter(sma, 2, 'BNC1High', 29);
    sma = SetGlobalCounter(sma, 3, 'BNC1High', 5);
    sma = SetGlobalTimer(sma, 1, 10); 

    
    sma = AddState(sma, 'Name', 'DeliverStimulus',...
        'Timer',0.5,...
        'StateChangeConditions',{'Tup','ControlRunDelay'},...
        'OutputActions', OutputActionArgument);
    sma = AddState(sma, 'Name', 'ControlRunDelay', ...
        'Timer',S.ReinforcementDelays(currentTrial),...
        'StateChangeConditions', {'GlobalCounter3_End', 'Timeout','Tup','Counter1_Reset'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Counter1_Reset', ...
        'Timer',0,...
        'StateChangeConditions', {'Tup', 'Counter2_Reset'},...
        'OutputActions', {'GlobalCounterReset', 1});
    sma = AddState(sma, 'Name', 'Counter2_Reset', ...
        'Timer',0,...
        'StateChangeConditions', {'Tup', 'Counter3_Reset'},...
        'OutputActions', {'GlobalCounterReset', 2});
    sma = AddState(sma, 'Name', 'Counter3_Reset', ...
        'Timer',0,...
        'StateChangeConditions', {'Tup', 'WaitForRun'},...
        'OutputActions', {'GlobalCounterReset', 3});
                  
    if S.TrialTypes(currentTrial)==1
      sma = AddState(sma, 'Name', 'WaitForRun', ...
            'Timer',10,...
            'StateChangeConditions', {'Tup', 'Timeout', 'GlobalCounter1_End','Counter1_Reset1'},...
            'OutputActions', {'PWM3', 255}); 
            
             for j=1:29
               Counter1_Reset= sprintf('Counter1_Reset%.0f',j);
               Counter1_Reset_Next= sprintf('Counter1_Reset%.0f',j+1);
               Next_FeedbackTone=sprintf('FeedbackTone%.0f',j);          
               
               sma = AddState(sma, 'Name', Counter1_Reset, ...
                    'Timer',0,...
                    'StateChangeConditions', {'Tup', Next_FeedbackTone, 'GlobalCounter2_End','DeliverReward'},...
                    'OutputActions', {'GlobalCounterReset', 1});
                if j < 29
                   sma = AddState(sma, 'Name', Next_FeedbackTone, ...
                        'Timer',0,...
                        'StateChangeConditions', {'GlobalTimer1_End', 'Timeout', 'GlobalCounter1_End',Counter1_Reset_Next},...
                        'OutputActions', {'SoftCode', j}); 
                else
                   sma = AddState(sma, 'Name', Next_FeedbackTone, ...
                        'Timer',0,...
                        'StateChangeConditions', {'Tup', 'Timeout', 'GlobalCounter1_End','DeliverReward'},...
                        'OutputActions', {});
                end
                    
             end
 

       
   elseif S.TrialTypes(currentTrial)==2
           sma = AddState(sma, 'Name', 'WaitForRun', ...
            'Timer',5,...
            'StateChangeConditions', {'Tup', 'DeliverReward', 'GlobalCounter3_End', 'DeliverPunish'},...
            'OutputActions', {'PWM3', 255});
   end
       

    sma = AddState(sma,'Name', 'DeliverReward', ...
        'Timer',WaterTime, ...
        'StateChangeConditions', {'Tup', 'ITI'},...
        'OutputActions', {'ValveState', 1});
    sma = AddState(sma,'Name', 'DeliverPunish', ...
        'Timer',airpuff_dur, ...
        'StateChangeConditions', {'Tup', 'ITI'},...
        'OutputActions', {'ValveState', 2});
    sma = AddState(sma,'Name', 'Timeout', ...
        'Timer',0.5, ...
        'StateChangeConditions', {'Tup', 'ITI'},...
        'OutputActions', {'PWM2', 255});
    sma = AddState(sma, 'Name', 'ITI', ...
        'Timer',5,...
        'StateChangeConditions', {'Tup', 'exit'}, ...
        'OutputActions', {}); 
    
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
    BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents);
    BpodSystem.Data = BpodNotebook('sync',BpodSystem.Data);
    BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
    BpodSystem.Data.S.TrialTypes(currentTrial) = S.TrialTypes(currentTrial); % Adds the trial type of the current trial to data
    UpdateOutcomePlot(S.TrialTypes, BpodSystem.Data);
    SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
   if BpodSystem.BeingUsed == 0
    return
  end
end



%---------------------------------------- /MAIN LOOP

%% sub-functions
function UpdateOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.DeliverReward(1))
        Outcomes(x) = 1;
%     elseif ~isnan(Data.RawEvents.Trial{x}.States.DeliverPunish(1))
%         Outcomes(x) = 0;
    else
        Outcomes(x) = 3;
    end
end
OutcomePlot_AudGonogo(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,2-TrialTypes,Outcomes);
