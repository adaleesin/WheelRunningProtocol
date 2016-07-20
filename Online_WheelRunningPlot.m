function figData=Online_WheelRunningPlot(action,figData,trialType,newxdata)


global BpodSystem

MS_actions=1;     %marker size for action
maxy=200;       %y axe for actions
ystep=25;       %y axe for actions
switch action
case 'ini'
    %% Create Figure
    figPlot=figure('Name','Online action Plot','Position', [1000 100 600 800], 'numbertitle','off');
    hold on;
    ProtoSummary=sprintf('%s : %s -- %s',...
        date, BpodSystem.GUIData.SubjectName, ...
        BpodSystem.GUIData.ProtocolName)
    MyBox = uicontrol('style','text')
    set(MyBox,'String',ProtoSummary, 'Position',[10,1,400,20])

    %% action plot
    %PlotParameters
    labely='Trials';
    miny=0;                             
    ytickvalues=miny:ystep:maxy;
    labelx='Time from reward (sec)';
    minx=-2;    
    maxx=6;     
    xstep=1;    
    xtickvalues=minx:xstep:maxx;
        subPlotTitles={'Tone1Reward', 'Tone2Avoidance', 'Tone1TimeOut', 'Tone2Punish'}; 
    % subplot
    for i=1:4
        actionsubplot(i)=subplot(2,2,i);
        hold on;
        rewplot(i)=plot([0 0],[-5,500],'-r');
        actionplot(i)=plot([0 0],[1,500],'sk','MarkerSize',MS_actions,'MarkerFaceColor','k');
        set(actionplot(i), 'XData',[],'YData',[]);
        xlabel(labelx); 
        ylabel(labely);
        title(subPlotTitles(i));
        set(actionsubplot(i),'XLim',[minx maxx],'XTick',xtickvalues,'YLim',[miny maxy],'YTick',ytickvalues,'YDir', 'reverse');
    end


    %Save the figure properties
    figData.fig=figPlot;
    figData.actionsubplot=actionsubplot;
    figData.actionplot=actionplot;



case 'update'
    %% actionPlot
    %Extract the previous data from the plot
    i=trialType;
    if i>0
    %initialize the first raster
    previous_xdata=get(figData.actionplot(i),'XData'); %action time
    previous_ydata=get(figData.actionplot(i),'YData'); %trial number

    if isempty(previous_ydata)==1
        trialTypeCount=1; 
    else
        trialTypeCount=max(previous_ydata)+1;
    end

    updated_xdata=[previous_xdata newxdata];
    newydata=linspace(trialTypeCount,trialTypeCount,size(newxdata,2));
    updated_ydata=[previous_ydata newydata];
    set(figData.actionplot(i),'XData',updated_xdata,'YData',updated_ydata);
    end
end
end