function Wheelrunning_ada


global BpodSystem
PulsePal;
load('D:\Bpod_r0_5-master\Protocols\Wheelrunning_ada\SoundPulse_1ms.mat');
ProgramPulsePal(ParameterMatrix);


% Training Level
TrainingLevel = 3; % option 1, 2 ,3, 4

switch TrainingLevel
    case 1 
        airpuff_dur = 0.1;
        TrialTypeProbs = [1 0];   % Go A only
    case 2 
        airpuff_dur = 0.1;
        TrialTypeProbs = [0 1];  % Go B only
    case 3 % task without air puff
        airpuff_dur = 0.1;
        TrialTypeProbs = [0.7 0.3];  % trial types --- Go A, Go B,
end

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
S.SoundRamping=0.4;         %sec
S.MeanSoundFrequencyA = 5000;   %Hz
S.MeanSoundFrequencyB = 500;  %Hz
S.WidthOfFrequencies=2;
S.NumberOfFrequencies=5;
S.SoundDuration=7;
end

BpodSystem.Data.Sequence = [];

%% Define stimuli and send to sound server
SF = 192000; % Sound card sampling rate
PsychToolboxSoundServer('init')
% Noise=randn(1,SF);
% PsychToolboxSoundServer('Load', 3, Noise);
BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler_PlaySound';

%%  Waterscaled
MinRew =GetValveTimes(1, [1]);
MaxRew =GetValveTimes(15, [1]);
reward_valve_times = linspace(MinRew,MaxRew,500);

%% Define trials
maxTrials = 5000;
S.TrialSequence = zeros(1,maxTrials);
for x = 1:maxTrials
    P = rand;
    Cutoffs = cumsum(TrialTypeProbs);
    Found = 0;
    for y = 1:length(TrialTypeProbs)
        if P<Cutoffs(y) && Found == 0
            Found = 1;
            S.TrialSequence(x) = y;
        end
    end
end
TrialSequence=S.TrialSequence;

%% Initialize plots
BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [50 800 900 200],'Name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');   %[400 800 1000 200]
BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.075 .3 .89 .6]); % [.075 .3 .89 .6]
OutcomePlot_WheelRunning(BpodSystem.GUIHandles.OutcomePlot,'init',2-S.TrialSequence);
FigAction=Online_WheelRunningPlot('ini'); 

%% Main loop
for currentTrial = 1:maxTrials
    disp(['Trial # ' num2str(currentTrial) ': trial type ' num2str(S.TrialSequence(currentTrial))]);
         %sec
    switch S.TrialSequence(currentTrial)
        case 1  % Go A; 
           Sound1=SoundGenerator_increaseramp(SF, S.MeanSoundFrequencyA, S.WidthOfFrequencies, S.NumberOfFrequencies, S.SoundDuration, S.SoundRamping);
           PsychToolboxSoundServer('Load', 1, Sound1); 
           OutputActionArgument = {'SoftCode', 1,'BNCState', 1};  % generate sound
        case 2  % Go B; 
           Sound2=SoundGenerator_decreaseramp(SF, S.MeanSoundFrequencyB, S.WidthOfFrequencies, S.NumberOfFrequencies, S.SoundDuration, S.SoundRamping);
           PsychToolboxSoundServer('Load', 2, Sound2); 
           OutputActionArgument = {'SoftCode', 2,'BNCState', 2};
    end

       
    sma = NewStateMatrix();
    %sma = SetGlobalTimer(sma, 1, 5);        
    sma = AddState(sma,'Name', 'Dummy1', ...
        'Timer',0, ...
        'StateChangeConditions', {'Tup', 'ITI'}, ...
        'OutputActions', {});
    sma = AddState(sma,'Name', 'ITI', ...
        'Timer',5, ...
        'StateChangeConditions', {'Tup', 'Resting'}, ...
        'OutputActions', {'PWM3', 255, 'WireState', 9});
    sma = AddState(sma,'Name', 'Resting', ...
        'Timer',2, ...
        'StateChangeConditions', {'Tup', 'DeliverStimulus'}, ...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'DeliverStimulus', ...
        'Timer',1,...
        'StateChangeConditions', {'Tup','WaitForRun'},... %'GlobalTimer1_End','TimeOut',
        'OutputActions',OutputActionArgument);  
if S.TrialSequence(currentTrial)==1  
    sma = AddState(sma, 'Name', 'WaitForRun', ...
        'Timer',S.SoundDuration,...
        'StateChangeConditions', {'Tup','TimeOut','BNC1High','DeliverReward'},... %'GlobalTimer1_End','TimeOut',
        'OutputActions',{});      
else
    sma = AddState(sma, 'Name', 'WaitForRun', ...
        'Timer',5,...
        'StateChangeConditions', {'Tup','DeliverPunish','BNC1High','DeliverPunish','BNC2High','SpeedCheck_1'},...
        'OutputActions',{});  
    sma = AddState(sma, 'Name', 'SpeedCheck_1', ...
        'Timer',1,...
        'StateChangeConditions', {'Tup','DeliverPunish','BNC1High','DeliverPunish','BNC2High','SpeedCheck_2'},...
        'OutputActions',{});  
    sma = AddState(sma, 'Name', 'SpeedCheck_2', ...
        'Timer',1,...
        'StateChangeConditions', {'Tup','DeliverPunish','BNC1High','DeliverPunish','BNC2High','AvoidSucc'},...
        'OutputActions',{});  
end   
 
    sma = AddState(sma,'Name', 'DeliverReward', ...
        'Timer',reward_valve_times(200), ...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'ValveState', 1,'SoftCode',255});
    sma = AddState(sma,'Name', 'DeliverPunish', ...
        'Timer',airpuff_dur, ...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'ValveState', 4,'SoftCode',255});
    sma = AddState(sma,'Name', 'TimeOut', ...
        'Timer',0.5, ...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'SoftCode',255});
    sma = AddState(sma,'Name', 'AvoidSucc', ...
        'Timer',0.5, ...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'SoftCode',255});

  
    SendStateMatrix(sma);  
    
    RawEvents = RunStateMatrix;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
    BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents);
    PA=BpodSystem.Data; 
    BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
    BpodSystem.Data.TrialSequence(currentTrial) = TrialSequence(currentTrial); % Adds the trial type of the current trial to data
    UpdateOutcomePlot(S.TrialSequence, BpodSystem.Data);
    SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
   [TrialType,Response_events]=UpdateOnlineEvent(S.TrialSequence,BpodSystem.Data,currentTrial);
    FigAction=Online_WheelRunningPlot('update',FigAction,TrialType,Response_events); 
  HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
   if BpodSystem.BeingUsed == 0
    return
   end
   
end



%---------------------------------------- /MAIN LOOP

%% sub-functions

function UpdateOutcomePlot(TrialSequence, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.DeliverPunish(1))
         Outcomes(x) = 0;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.TimeOut(1))
         Outcomes(x) = 2;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.AvoidSucc(1))
         Outcomes(x) = -1;
    elseif  ~isnan(Data.RawEvents.Trial{x}.States.DeliverReward(1))
        Outcomes(x) =  1;
    end
end
OutcomePlot_WheelRunning(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,2-TrialSequence,Outcomes);

function [TrialType,Response_events]=UpdateOnlineEvent(TrialSequence,Data,currentTrial)
switch TrialSequence(currentTrial)
        case 1
%         if ~isnan(Data.RawEvents.Trial{end}.States.PrePunish(1))
%             TrialType= 5;
%             Response_events=Data.RawEvents.Trial{end}.Events.Port2In-Data.RawEvents.Trial{end}.States.Pretraining(1,2);
        if ~isnan(Data.RawEvents.Trial{end}.States.TimeOut(1))
            TrialType= 3;
            try
                Response_events=Data.RawEvents.Trial{end}.Events.Port2In-Data.RawEvents.Trial{end}.States.DeliverStimulus(1,1);
            catch
            Response_events=[66];
            end
        elseif ~isnan(Data.RawEvents.Trial{end}.States.DeliverReward(1))
            TrialType= 1;
            Response_events=Data.RawEvents.Trial{end}.Events.Port2In-Data.RawEvents.Trial{end}.States.DeliverStimulus(1,1);
        end
    case 2
        if ~isnan(Data.RawEvents.Trial{end}.States.AvoidSucc(1))
            TrialType= 2;
            try
                Response_events=Data.RawEvents.Trial{end}.Events.Port2In-Data.RawEvents.Trial{end}.States.DeliverStimulus(1,1);
            catch
            Response_events=[66];
            end
        elseif ~isnan(Data.RawEvents.Trial{end}.States.DeliverPunish(1))
            TrialType= 4;
            Response_events=Data.RawEvents.Trial{end}.Events.Port2In-Data.RawEvents.Trial{end}.States.DeliverStimulus(1,1);
%         else
%             TrialType= 6;
%             Response_events=Data.RawEvents.Trial{end}.Events.Port2In-Data.RawEvents.Trial{end}.States.Pretraining(1,2);
        end
end
