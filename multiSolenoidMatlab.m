function totalDispensed = multiSolenoidMatlab()
portNums = [ 1 2 3 4 ];
touchPin = [  "ctr0", "ctr1", "ctr2", "ctr3" ];
waterPin = [ "Port0/Line19", "Port0/Line20", "Port0/Line21", "Port0/Line22" ]; %["Port0/Line19", "Port0/Line20", "Port0/Line21", "Port0/Line22"];
ledPin = [ "Port0/Line29", "Port0/Line30", "Port0/Line0", "Port0/Line1" ];%["Port0/Line29", "Port0/Line30", "Port0/Line0", "Port0/Line1"];
syncPulsePin = 'ao0';

close all;
% niDevs = daqlist("ni");

% the 6323 should be the first one in the list
% daqInfo = niDevs{1, "DeviceInfo"};

% instantiate object
daq6323 = daq('ni');

% add channels

for iPort = 1:length(portNums)
    % add touch channel
    ch_Touch(iPort) = addinput(daq6323,"Dev1",touchPin{iPort},"EdgeCount");
    
    % add water channel
    ch_Water(iPort) = addoutput(daq6323,"Dev1",waterPin{iPort},"Digital");
    
    % add led channel
    ch_LED(iPort) = addoutput(daq6323,"Dev1",ledPin{iPort},"Digital");
end

% add LED Sync pulse channel
% (will use channel 4 LED for this)
ch_LEDPulse = addoutput(daq6323,"Dev1",syncPulsePin,"Voltage");
syncPulseSignal = repmat([5*ones(1,700) zeros(1,300)],1,5);

% now loop until user preses exit key
% When activated, dispense water whenever the port is touched
exitKey = 'x';
pulseKey = 's';
% activateKey = 'a';
% deactivateKey = 'd';

dispenseTime = 0.066; %based on 5/26 calibration 70ms ~ 3uL of water
timeoutDuration = 0.2; %wait at least this amount of time before another dispense
activeLimit = 6; %the number of times water is dispensed before auto deactivating the port
totalLimit = 350; %total number of dispensions before ending session
minTouchSamples = 5; %just the dispensing of the water seems to increase the touch edge counter by 1 or 2 for some reason

% initiate values
portDispensed = zeros(1,length(portNums));
totalDispensed = 0;
activeDispensed = zeros(1,length(portNums));
prevTouchCounts = zeros(1,length(portNums));
active = zeros(1,length(portNums));
active(1) = 1;
setOutputs(daq6323, length(portNums), 1, 0, 0);

% make figure for displaying active vs not and counter
mainFig = uifigure('KeyPressFcn',@KeyPress);
setappdata(mainFig,'allKeysPressed',{});
keysLegnedDisp = uilabel(mainFig,'Text',...
    ['Exit loop: "' exitKey '"'],...
    'FontSize',20,'Position',[100 360 400 50]);
activeStatusDisp = uilabel(mainFig,'Text','Active Port: 1','FontColor','g',...
    'FontSize',20,'Position',[100 300 400 50]);
activeCountDisp = uilabel(mainFig,'Text','Current activation dispensed: 0',...
    'FontSize',20,'Position',[100 230 400 50]);
portCountDisp = uilabel(mainFig,'Text','Port total dispensed: 0',...
    'FontSize',20,'Position',[100 180 400 50]);
totalCountDisp = uilabel(mainFig,'Text','Total dispensed: 0',...
    'FontSize',20,'Position',[100 120 400 50]);

% start
disp('Starting water port control loop')

while true
    
    for iPort = 1:length(portNums)
        
        %only dispense if port is activated
        if active(iPort)
            
            %read touch
            touchCounts = read(daq6323,'OutputFormat','Matrix');
            
            %dispense water if any touch activation edges were detected
            if touchCounts(iPort) >= prevTouchCounts(iPort)+minTouchSamples
                setOutputs(daq6323, length(portNums), iPort, 1, 0);
                pause(dispenseTime)
                setOutputs(daq6323, length(portNums), iPort, 0, 0);
                
                %update counters
                xportDispensed(iPort) = portDispensed(iPort) + 1;
                totalDispensed = totalDispensed + 1;
                activeDispensed(iPort) = activeDispensed(iPort) + 1;
                
                %update display
                set(activeCountDisp,'Text',['Current activation dispensed: ' num2str(activeDispensed(iPort))]);
                set(portCountDisp,'Text',['Port total dispensed: ' num2str(portDispensed(iPort))]);
                set(totalCountDisp,'Text',['Total dispensed: ' num2str(totalDispensed)]);
                
            end
            
            prevTouchCounts(iPort) = touchCounts(iPort);
            
        end
        
        %check if active dispense limit is reached
        if activeDispensed(iPort) >= activeLimit
            %deactivate port
            active(iPort) = 0;
            setOutputs(daq6323, length(portNums), iPort, 0, 0);
            activeDispensed(iPort) = 0;
            
            %activate next port (random)
            posiblePorts = 1:length(portNums);
            posiblePorts(iPort) = [];
            nextPortInd = randi([1 length(portNums)-1],1);
            nextPort = posiblePorts(nextPortInd);
            active(nextPort) = 1;
            set(activeStatusDisp,'Text',['Active Port: ' num2str(portNums(nextPort))],'FontColor','g')
            setOutputs(daq6323, length(portNums), iPort, 0, 0);
        end
        
    end

    %check user inputs
    allKeysPressed = getappdata(mainFig,'allKeysPressed');
    if any(cellfun(@(x) strcmpi(x, exitKey), allKeysPressed))
        break;
        
    elseif any(cellfun(@(x) strcmpi(x, pulseKey), allKeysPressed))
        %do sync pulse
        startSyncPulse(daq6323, length(portNums), syncPulseSignal);
        
%     elseif any(cellfun(@(x) strcmpi(x, activateKey), allKeysPressed))...
%             && active == false
%         active = true;
%         write(daq6323,[1 1])
%         set(activeStatusDisp,'Text','Port active','FontColor','g')
%         
%     elseif any(cellfun(@(x) strcmpi(x, deactivateKey), allKeysPressed))...
%             && active == true
%         active = false;
%         write(daq6323,[1 0])
%         activeDispensed = 0;
%         set(activeStatusDisp,'Text','Port not active','FontColor','r')
        
    end
    
    %check if total number of dispensions has been reached 
    if totalDispensed >= totalLimit
        break;
    end
    
    allKeysPressed = {};
    setappdata(mainFig,'allKeysPressed',allKeysPressed);
    clear allKeysPressed
    
    pause(timeoutDuration)
    
end

setOutputs(daq6323, length(portNums), 1, 0, 0);
stop(daq6323);
close(mainFig)

end

function KeyPress(src,event)
allKeysPressed = getappdata(src,'allKeysPressed');
allKeysPressed{end+1} = event.Key;
setappdata(src,'allKeysPressed',allKeysPressed);
end


function setOutputs(daqID, nPorts, portNum, waterOn, ledOn)

writeVec = [];
for iPort=1:nPorts
    if iPort == portNum
        writeVec(end+1) = ~waterOn;
        writeVec(end+1) = ledOn;
    else
        writeVec(end+1) = 1;
        writeVec(end+1) = 0;
    end
end

writeVec = [writeVec 0];

write(daqID,writeVec);

end


function startSyncPulse(daqID, nPorts, pulseSig)

writeVec = [repmat([ones(length(pulseSig),1) zeros(length(pulseSig),1)],1,nPorts) pulseSig'];

readwrite(daqID,writeVec);

end


%
