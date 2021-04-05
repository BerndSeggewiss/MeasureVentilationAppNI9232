% Realtime application to measure and plot pressure, flow, current (rms)
% and speed of radial fans. This application ist tested with NI9232 and NI9234.
% For operation, the toolboxes for signal processing and data aquisition are 
% necessary. Of some measured values, the value is displayed numerically as 
% moving average.The appl. can be started and stopped with the corresponding
% buttons.

% This application is adapted from this example: 
% https://de.mathworks.com/help/daq/software-analog-triggered-data-capture.html;
% jsessionid=262901a9f90365b34cf879d93c32

% Recording of measuring data is also possible, but not implemented in this
% application. Note: Simultaneous saving and displaying of measurement data
% (with the plot method)is only possible with the method 'startBackground' 
% of the DAQ Toolbox.

% Created with Matlab R2019b.

function MeasureVentilationAppNI9232
    s = daq.createSession('ni');
    addAnalogInputChannel(s, 'cDAQ1Mod1', 0, 'Voltage');
    addAnalogInputChannel(s, 'cDAQ1Mod1', 1, 'Voltage');
    addAnalogInputChannel(s, 'cDAQ1Mod1', 2, 'Voltage');
    addAnalogInputChannel(s, 'cDAQ1Mod2', 0, 'Voltage');
    s.Rate = 10000;
    capture.TimeSpan = 0.45*10;
    capture.plotTimeSpan = 0.5*10;
    callbackTimeSpan = double(s.NotifyWhenDataAvailableExceeds)/s.Rate;
    capture.bufferTimeSpan = max([capture.plotTimeSpan, capture.TimeSpan*3, callbackTimeSpan*3]);
    capture.bufferSize = round(capture.bufferTimeSpan*s.Rate);
    hGUI = createDataCaptureUI(s);
    addlistener(s, 'DataAvailable',...
    @(src, event) dataCapture(src, event, capture, hGUI));
    s.IsContinuous = true;
    s.startBackground;
    while s.IsRunning
        pause(0.5)
    end
    while ~s.IsRunning
        pause(0.5)
    end
    delete(dataListener);
    delete(s);
end

% Buildung of the GUI
function hGUI = createDataCaptureUI(s)
    hGUI.Fig = figure('Name', 'Measurement data PSA-BSRF', 'NumberTitle',...
        'off', 'Resize', 'off', 'Position', [100 100 900 650]);
    set(hGUI.Fig, 'DeleteFcn', {@stopMeas, s});
    hGUI.Axes1 = axes;
    hGUI.LivePlot1 = plot(0, zeros(1, numel(s.Channels)));
    grid on;
    xlabel('t/s');
    ylabel('p/Pa');
    set(hGUI.Axes1, 'Units', 'Pixels', 'Position',  [170 510 400 100]);
    hGUI.Axes2 = axes('Units', 'Pixels', 'Position', [170 375 400 100]);
    hGUI.LivePlot2 = plot(0, zeros(1, numel(s.Channels)));
    grid on;
    xlabel('t/s');
    ylabel('Flow in m^3/h');
    hGUI.Axes3 = axes('Units', 'Pixels', 'Position', [170 210 400 130]);
    hGUI.LivePlot3 = plot(0, zeros(1, numel(s.Channels)));
    grid on;
    xlabel('t/s');
    ylabel('Per. Duration Speed T/s');
    hGUI.Axes4 = axes('Units', 'Pixels', 'Position', [170 70 400 100]);
    hGUI.LivePlot4 = plot(0, zeros(1, numel(s.Channels)));
    xlabel('t/s');
    ylabel('Speed in rpm');
    hGUI.StopButton = uicontrol('Style', 'Pushbutton', 'String',...
        'Stopp', 'Units', 'Pixels', 'Position', [35 394 70 30]);
    set(hGUI.StopButton, 'callback', {@stopMeas, s});
    hGUI.StartButton = uicontrol('Style', 'Pushbutton', 'String',...
        'Start', 'Units', 'Pixels', 'Position', [35 450 70 30]);
    set(hGUI.StartButton, 'callback', {@startMeas, s});
    hGUI.YAxesLimits = uicontrol('Style', 'text', 'String',...
        'Y-Axes-Limits', 'Position', [590 620 70 18]);
    hGUI.yAxUpperPressLimit = uicontrol('Style','edit', 'string', '10',...
        'Position', [590 590 55 20]);
    hGUI.yAxLowerPressLimit = uicontrol('Style','edit', 'string', '-1',...
        'Position', [590 510 55 20]);
    hGUI.yAxUpperFlowLimit = uicontrol('Style','edit', 'string', '7',...
        'Position', [590 450 55 20]);
    hGUI.yAxLowerFlowLimit = uicontrol('Style','edit', 'string', '-0.5',...
        'Position', [590 380 55 20]);  
    hGUI.yAxUpperSpeedSigLimit = uicontrol('Style','edit', 'string', '20',...
        'Position', [590 320 55 20]);
    hGUI.yAxLowerSpeedSigLimit = uicontrol('Style','edit', 'string', '-20',...
        'Position', [590 220 55 20]); 
    hGUI.yAxLowerSpeedLimit = uicontrol('Style','edit', 'string', '0',...
        'Position', [590 70 55 20]);
    hGUI.yAxUpperSpeedLimit = uicontrol('Style','edit', 'string', '6000',...
        'Position', [590 150 55 20]);
    hGUI.Panel = uipanel(hGUI.Fig, 'Title', 'Measurment Data',...
        'Units', 'Pixels', 'Position', [680 350 200 300]);
    hGUI.txtFlow1 = uicontrol(hGUI.Panel, 'Style', 'Text', 'String',...
        'Flow:', 'Position', [8 200 50 20]);
    hGUI.ValMovAvFlow = uicontrol(hGUI.Panel, 'Style', 'Text', ...
        'Position', [55 200 50 20]);
    hGUI.txtFlow2 = uicontrol(hGUI.Panel, 'Style', 'Text', 'String',...
        'm^3/h', 'Position', [100 200 40 20]);
    hGUI.txtPress1 = uicontrol(hGUI.Panel, 'Style', 'Text', 'String', ...
        'Press.:', 'Position', [8 220 50 22]);
    hGUI.txtPress2 = uicontrol(hGUI.Panel, 'Style', 'Text', 'String', ...
        'Pa', 'Position', [100 220 40 20]);
    hGUI.ValMovAvPress = uicontrol(hGUI.Panel, 'Style', 'Text', ...
        'Position', [55 220 50 20]);
    hGUI.txtSpeed1 = uicontrol(hGUI.Panel, 'Style', 'Text', 'String',...
        'Speed: ', 'Position', [8 150 50 22]);
    hGUI.ValMovAvSpeed = uicontrol(hGUI.Panel, 'Style', 'Text', ...
        'Position', [55 150 50 20]);
    hGUI.txtSpeed2 = uicontrol(hGUI.Panel, 'Style', 'Text', 'String', ...
        '1/min', 'Position', [100 150 40 20]);
    hGUI.txtCurr1 = uicontrol(hGUI.Panel, 'Style', 'Text', ...
        'String', 'Curr.:', 'Position', [8 180 50 20]);
    hGUI.ValMovAveCurrRMS = uicontrol(hGUI.Panel, 'Style', 'Text', ...
        'Position', [55 180 50 20]); 
    hGUI.txtCurr2 = uicontrol(hGUI.Panel, 'Style', 'Text', 'String', ...
        'mA (RMS)', 'Position', [100 180 70 20]);
    hGUI.Panel1 = uipanel(hGUI.Fig, 'Title', 'Plot Data', ...
        'Units', 'Pixel', 'Position', [680 200 200 120]);
    hGUI.selectChan = uicontrol(hGUI.Panel1,'Style','popupmenu');
    hGUI.selectChan.Position = [10 80 80 20];
    hGUI.selectChan.String = {'Chanel 0', 'Chanel 1', 'Chanel 2'};
    hGUI.PlotButton = uicontrol(hGUI.Panel1, 'Style', 'Pushbutton', ...
        'String', 'Plot', 'Position', [130 80 30 20]);
    hGUI.Panel2 = uipanel(hGUI.Fig, 'Title', 'Setting Volt. EA-PSI', ...
        'Units', 'Pixel', 'Position', [680 80 200 100]);
    hGUI.setVoltage = uicontrol(hGUI.Panel2, 'Style', 'Edit', ...
        'String', '0', 'Position', [10 50 50 20]);
end

function dataCapture(src, event, c, hGUI)
    persistent dataBuffer;
    if ~event.TimeStamps(1)
        dataBuffer = [];
    end
    latestData = [event.TimeStamps, event.Data];
    dataBuffer = [dataBuffer; latestData];
    numSamplesToDiscard = size(dataBuffer, 1) - c.bufferSize;
    if numSamplesToDiscard > 0
        dataBuffer(1:numSamplesToDiscard, :) = [];
    end
    samplesToPlot = min([round(c.plotTimeSpan*src.Rate), size(dataBuffer, 1)]);
    firstPoint = size(dataBuffer, 1) - samplesToPlot + 1;
    PressVoltage = dataBuffer(firstPoint:end, 2);
    FlowVoltage = dataBuffer(firstPoint:end, 3);
    tachoVoltage = dataBuffer(firstPoint:end, 4);
    [speed, tP]= calcSpeed(tachoVoltage);
    xlim(hGUI.Axes1, [dataBuffer(firstPoint, 1), dataBuffer(end, 1)]);
    xlim(hGUI.Axes2, [dataBuffer(firstPoint, 1), dataBuffer(end, 1)]);
    xlim(hGUI.Axes3, [dataBuffer(firstPoint, 1), dataBuffer(end, 1)]);
    axesConfig.uppPress = sscanf(get(hGUI.yAxUpperPressLimit, 'string'), '%u');
    axesConfig.lowPress = sscanf(get(hGUI.yAxLowerPressLimit, 'string'), '%d');
    axesConfig.uppFlow = sscanf(get(hGUI.yAxUpperFlowLimit, 'string'), '%f');
    axesConfig.lowFlow = sscanf(get(hGUI.yAxLowerFlowLimit, 'string'), '%f');
    axesConfig.uppSpeedSig = sscanf(get(hGUI.yAxUpperSpeedSigLimit, 'string'), '%u');
    axesConfig.lowSpeedSig = sscanf(get(hGUI.yAxLowerSpeedSigLimit, 'string'), '%d');
    axesConfig.uppSpeed = sscanf(get(hGUI.yAxUpperSpeedLimit, 'string'), '%u');
    axesConfig.lowSpeed = sscanf(get(hGUI.yAxLowerSpeedLimit, 'string'), '%u');
    ylim(hGUI.Axes1, [axesConfig.lowPress axesConfig.uppPress]);
    ylim(hGUI.Axes2, [axesConfig.lowFlow axesConfig.uppFlow]);
    ylim(hGUI.Axes3, [axesConfig.lowSpeedSig axesConfig.uppSpeedSig]);
    ylim(hGUI.Axes4, [axesConfig.lowSpeed axesConfig.uppSpeed]);
    set(hGUI.LivePlot1, 'XData', dataBuffer(firstPoint:end, 1),...
                        'YData', calcPressure(PressVoltage));
    set(hGUI.LivePlot2, 'XData', dataBuffer(firstPoint:end, 1),...
                        'YData', calcFlow(FlowVoltage));
    set(hGUI.LivePlot3, 'XData', dataBuffer(firstPoint:end, 1),...
                        'YData', dataBuffer(firstPoint:end, 4));      
    set(hGUI.LivePlot4, 'XData', tP, 'YData', speed);
    FlowValNum = calcFlow(FlowVoltage);
    movAveFlow = sum(FlowValNum(1:1024)/1024);
    movAveFlow = round(movAveFlow*100)/100;
    strMovAveFlow = num2str(movAveFlow);
    set(hGUI.ValMovAvFlow, 'String', strMovAveFlow);
    PressValNum = calcPressure(PressVoltage);
    movAvePress = sum(PressValNum(1:1000)/1000);
    movAvePress = round(movAvePress*100)/100;
    strMovAvePress = num2str(movAvePress);
    set(hGUI.ValMovAvPress, 'String', strMovAvePress);
    movAveSpeed = sum(speed(1:10))/10;
    movAveSpeed = round(movAveSpeed*1)/1;
    set(hGUI.ValMovAvSpeed, 'String', movAveSpeed);
    currentRMS = calcCurrent(latestData);
    sizeCurrRMS = numel(currentRMS);
    movAveCurrRMS = (sum(currentRMS(1:sizeCurrRMS))/sizeCurrRMS)*1000;
    movAveCurrRMS = round(movAveCurrRMS*10)/10;
    set(hGUI.ValMovAveCurrRMS, 'String', movAveCurrRMS);
end

% Stop application
function stopMeas(~, ~, s)
    if isvalid(s)
        if s.IsRunning
           disp('Measurement stopped');
           s.stop();
        end
    end
end

% Start application
function startMeas(~, ~, s)
    if isvalid(s)
        s.startBackground();
    end
end

% Calculation of the flow from the output of the flow sensor. The head of 
% the sensor is mounted in the centre of a pipe through which the fan's
% intake air flows.
function Flow = calcFlow(FlowVoltage)
    FlowSens = 2.5/10;
    vm = FlowVoltage.*FlowSens;
    faktUnit = 0.36;
    faktArea = 0.8;
    Area = 19.6;
    Flow = vm*faktUnit*faktArea*Area;
end

% Calculation of the rms-value of the current signal of the fan. This is 
% an (approximately) sinusoidal mixed voltage.
function currentRMS = calcCurrent(latestData)
    currSens = 300/75;
    current = latestData(:, 5).*currSens;
    Max = max(current);
    [peaks, ~] = findpeaks(current, 'MinPeakHeight', Max - 0.005);
    currentRMS = peaks/sqrt(2);
end

% Calculation of the pressure built by the fan in the system.
function Pressure = calcPressure(PressVoltage)
    PressSens = 250/5;
    Pressure = PressVoltage.*PressSens;
end

% Calculation of the speed from the tacho signal of the fan.
function [speed, tP] = calcSpeed(tachoVoltage)
    Levels = statelevels(tachoVoltage);
    Levels = Levels(:);
    fs = 10240;
    [~, tRise] = risetime(tachoVoltage, fs, 'StateLevels', Levels', 'Tolerance', 19,...
         'PercentReferenceLevels', [20 80]);
    T = diff(tRise);
    speed = 1./T*60/2;   
    tP = interp1(1:length(tRise), tRise, 1:length(tRise) - 1);
end

