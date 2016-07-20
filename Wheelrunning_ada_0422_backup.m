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

    %% Define stimuli and send to sound server
    SoundDuration=1;          %sec
    SoundRamping=0.4;         %sec
    MeanSoundFrequencyA = 1000;   %Hz
    MeanSoundFrequencyB = 20000;  %Hz
    for ii=1:20
    MeanSoundFrequency(ii)=1000+(ii-1)*(20000-1000)/20;  %Hz
    end
    WidthOfFrequencies=4;
    NumberOfFrequencies=5;

SF = 192000; % Sound card sampling rate
Noise=randn(1,SF);
Sound1=SoundGenerator(SF, MeanSoundFrequencyA, WidthOfFrequencies, NumberOfFrequencies, SoundDuration, SoundRamping);
Sound2=SoundGenerator(SF, MeanSoundFrequencyB, WidthOfFrequencies, NumberOfFrequencies, SoundDuration, SoundRamping);
for i=1:20
Sound_run(i,:)= GenerateSineWave(SF, MeanSoundFrequency(i), 0.5); % Sampling freq (hz), Sine frequency (hz), duration (s)
end
SoundID=1:20;

% Program sound server
PsychToolboxSoundServer('init');

for i=1:20
PsychToolboxSoundServer('Load', i, Sound_run(i,:)); %PsychToolboxSoundServer('load', SoundID, Waveform)
end
PsychToolboxSoundServer('Load', 21, Noise);
PsychToolboxSoundServer('Load', 22, Sound1); %PsychToolboxSoundServer('load', SoundID, Waveform)
PsychToolboxSoundServer('Load', 23, Sound2); %Sounds are triggered by sending a soft code back to the governing computer 
                                            %from a trial's state matrix, and calling PsychToolboxSoundServer from a predetermined 
                                            %soft code handler function.
% Set soft code handler to trigger sounds
BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler_PlaySound';

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount = 12; % defalut 5, amount of reward delivered to the mouse in microliters
    S.TrialTypeProbs = TrialTypeProbs; %Probability of trial types 1(go) & 2(nogo) in the session
%     S.ITI = 1;

    
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
BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [400 800 1000 200],'Name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');   %[400 800 1000 200]
BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.075 .3 .89 .6]); % [.075 .3 .89 .6]
OutcomePlot_AudGonogo(BpodSystem.GUIHandles.OutcomePlot,'init',2-S.TrialTypes);
BpodNotebook('init');




%% Main loop
for currentTrial = 1:maxTrials
    disp(['Trial # ' num2str(currentTrial) ': trial type ' num2str(S.TrialTypes(currentTrial))]);
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    
    switch S.TrialTypes(currentTrial)
        case 1  % Go A; 
            %ParameterMatrix{5,2} = 0.0001; % Set PulsePal to 100us pulse width on output channel 1
            %ParameterMatrix{8,2} = 0.0001; % Set PulsePal to 100us pulse interval on output channel 1
%             StateReinforcer = 'TriggerReward_A';
            OutputActionArgument = {'SoftCode', 22,'BNCState', 1};  % generate sound
        case 2  % Go B; 
            %ParameterMatrix{5,2} = 0.001; % Set PulsePal to 100us pulse width on output channel 1
            %ParameterMatrix{8,2} = 0.001; % Set PulsePal to 100us pulse interval on output channel 1
%             StateReinforcer = 'TriggerReward_B';
            OutputActionArgument = {'SoftCode', 23,'BNCState', 2};

    end
    %ProgramPulsePal(ParameterMatrix);
    WaterTime = GetValveTimes(S.GUI.RewardAmount,[1]); % This code gets the time valves 2 (valve code)must be open to deliver liquid being set. 

%     S.ReinforcementDelays(currentTrial) = random('Normal',1,1);
        S.ReinforcementDelays(currentTrial) = 1;
    %     Assemble state matrix
    sma = NewStateMatrix();
    sma = SetGlobalCounter(sma, 1, 'BNC1High', 3);
    sma = SetGlobalCounter(sma, 2, 'BNC1High', 10);
    sma = SetGlobalCounter(sma, 3, 'BNC1High', 5);
    sma = SetGlobalCounter(sma, 4, 'BNC1High', 5);
    sma = SetGlobalTimer(sma, 1, 10); 

    sma = AddState(sma, 'Name', 'ITI', ...
        'Timer',5,...
        'StateChangeConditions', {'Tup', 'DeliverStimulus'}, ...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'DeliverStimulus',...
        'Timer',0.5,...
        'StateChangeConditions',{'Tup','GlobalCounter3_Reset'},...
        'OutputActions', OutputActionArgument);      
    sma = AddState(sma, 'Name', 'GlobalCounter3_Reset',...
        'Timer',0,...
        'StateChangeConditions',{'Tup','ControlRunDelay'},...
        'OutputActions', {'GlobalCounterReset', 3});  
    sma = AddState(sma, 'Name', 'ControlRunDelay', ...
        'Timer',S.ReinforcementDelays(currentTrial),...
        'StateChangeConditions', {'GlobalCounter3_End', 'DeliverNoise','Tup','GlobalCounter4_Reset'},...%-- 4/19/2016 9:28 PM --%
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'GlobalCounter4_Reset', ...
        'Timer',0,...
        'StateChangeConditions', {'Tup', 'GlobalCounter2_Reset'},...
        'OutputActions', {'GlobalCounterReset', 4});
    sma = AddState(sma, 'Name', 'GlobalCounter2_Reset', ...
        'Timer',0,...
        'StateChangeConditions', {'Tup', 'WaitForRun'},...
        'OutputActions', {'GlobalCounterReset', 2});
                  
    if S.TrialTypes(currentTrial)==1     
         sma = AddState(sma, 'Name', 'WaitForRun', ...
                    'Timer',10,...
                    'StateChangeConditions', {'Tup','TimeOut','GlobalCounter4_End','TimeReset'},...
                    'OutputActions', {'PWM3', 255});  
         sma = AddState(sma, 'Name', 'TimeReset', ...
                    'Timer',0,...
                    'StateChangeConditions', {'Tup','Counter1_Reset1'},...
                    'OutputActions', {'GlobalTimerTrig', 1});    
             for j=1:20
               Counter1_Reset= sprintf('Counter1_Reset%.0f',j);
               Counter1_Reset_Next= sprintf('Counter1_Reset%.0f',j+1);
               Next_FeedbackTone=sprintf('FeedbackTone%.0f',j);      
%                Counter3_Reset= sprintf('Counter3_Reset%.0f',j);  
              
               sma = AddState(sma, 'Name', Counter1_Reset, ...
                    'Timer',0,...
                    'StateChangeConditions', {'Tup', Next_FeedbackTone},...
                    'OutputActions', {'GlobalCounterReset', 1});
                if j < 20
                   sma = AddState(sma, 'Name', Next_FeedbackTone, ...
                        'Timer',10, ...
                        'StateChangeConditions', {'GlobalCounter1_End',Counter1_Reset_Next,'GlobalTimer1_End','TimeOut','Tup','TimeOut'},...
                        'OutputActions', {'PWM3', 255,'SoftCode', SoundID(j)}); 
                else
                   sma = AddState(sma, 'Name', Next_FeedbackTone, ...
                        'Timer',10,...
                        'StateChangeConditions', {'GlobalCounter1_End','DeliverReward','GlobalTimer1_End','TimeOut','Tup','TimeOut'},...
                        'OutputActions', {});
                end
                    
             end
 

       
   elseif S.TrialTypes(currentTrial)==2
           sma = AddState(sma, 'Name', 'WaitForRun', ...
            'Timer',5,...
            'StateChangeConditions', {'Tup', 'DeliverReward', 'GlobalCounter2_End', 'DeliverPunish'},...
            'OutputActions', {'PWM3', 255});
   end
       

    sma = AddState(sma,'Name', 'DeliverReward', ...
        'Timer',WaterTime, ...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'ValveState', 1});
    sma = AddState(sma,'Name', 'DeliverPunish', ...
        'Timer',airpuff_dur, ...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'ValveState', 2});
    sma = AddState(sma,'Name', 'DeliverNoise', ...
        'Timer',0, ...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'SoftCode', 21});
    sma = AddState(sma,'Name', 'TimeOut', ...
        'Timer',0.5, ...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'PWM2', 255});
    
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
    elseif ~isnan(Data.RawEvents.Trial{x}.States.DeliverPunish(1))
        Outcomes(x) = 0;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.DeliverNoise(1))
        Outcomes(x) = 2;       
    else
        Outcomes(x) = 3;
    end
end
OutcomePlot_AudGonogo(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,2-TrialTypes,Outcomes);
