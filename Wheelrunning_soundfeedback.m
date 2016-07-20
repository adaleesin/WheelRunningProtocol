function Wheelrunning_soundfeedback


global BpodSystem
PulsePal;
load('D:\Bpod_r0_5-master\Protocols\Wheelrunning_ada\SoundPulse_1ms.mat');
ProgramPulsePal(ParameterMatrix);


%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
BpodSystem.Data.Sequence = [];

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
% BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [50 800 900 200],'Name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');   %[400 800 1000 200]
% BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.075 .3 .89 .6]); % [.075 .3 .89 .6]
% OutcomePlot_WheelRunning(BpodSystem.GUIHandles.OutcomePlot,'init',2-S.TrialSequence);
% FigAction=Online_WheelRunningPlot('ini'); 
     sma = NewStateMatrix();      
     sma = AddState(sma,'Name', 'Speedcheck', ...
            'Timer',10000, ...
            'StateChangeConditions', {'BNC1High','FeedBack'}, ...
            'OutputActions', {});
     sma = AddState(sma, 'Name', 'FeedBack', ...
            'Timer',0.01,...
            'StateChangeConditions', {'Tup','Speedcheck',},...
            'OutputActions', {'BNCState',1});       
    SendStateMatrix(sma);  
    
    RawEvents = RunStateMatrix;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
    BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents);
    PA=BpodSystem.Data; 
    BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
    BpodSystem.Data.TrialSequence(currentTrial) = TrialSequence(currentTrial); % Adds the trial type of the current trial to data
%     UpdateOutcomePlot(S.TrialSequence, BpodSystem.Data);
    SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
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
    elseif ~isnan(Data.RawEvents.Trial{x}.States.DeliverNoise(1))
         Outcomes(x) = 2;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.TimeOut(1))
         Outcomes(x) = 3;
    else
        Outcomes(x) =  1;
    end
end
OutcomePlot_WheelRunning(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,2-TrialSequence,Outcomes);

function [TrialType,Response_events]=UpdateOnlineEvent(TrialSequence,Data,currentTrial)
switch TrialSequence(currentTrial)
        case 1
        if ~isnan(Data.RawEvents.Trial{end}.States.DeliverNoise(1))
            TrialType= 5;
            Response_events=Data.RawEvents.Trial{end}.Events.BNC1High-Data.RawEvents.Trial{end}.States.SpeedCheck(1,2);
        elseif ~isnan(Data.RawEvents.Trial{end}.States.TimeOut(1))
            TrialType= 3;
            Response_events=[66];
        else
            TrialType= 1;
            Response_events=Data.RawEvents.Trial{end}.Events.BNC1High-Data.RawEvents.Trial{end}.States.DeliverStimulus(1,1);
        end
    case 2
        if ~isnan(Data.RawEvents.Trial{end}.States.DeliverReward(1))
            TrialType= 2;
            Response_events=[66];
        elseif ~isnan(Data.RawEvents.Trial{end}.States.DeliverPunish(1))
            TrialType= 4;
            Response_events=Data.RawEvents.Trial{end}.Events.BNC1High-Data.RawEvents.Trial{end}.States.DeliverStimulus(1,1);
        else
            TrialType= 6;
            Response_events=Data.RawEvents.Trial{end}.Events.BNC2High-Data.RawEvents.Trial{end}.States.SpeedCheck(1,2);
        end
end
