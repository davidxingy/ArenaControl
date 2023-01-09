function totalDispensed = singleSolenoidMatlab()
touchPin = "ctr0";
waterPin = "Port0/Line19";
ledPin = "Port0/Line1";

% syncLEDPin = "Port0/Line1";
syncPulsePin = 'ao0';

close all;
% niDevs = daqlist("ni");

% the 6323 should be the first one in the list
% daqInfo = niDevs{1, "DeviceInfo"};

% instantiate object
daq6323 = daq('ni');

% add channels
% add touch channel
ch_Touch = addinput(daq6323,"Dev1",touchPin,"EdgeCount");

% add water channel
ch_Water = addoutput(daq6323,"Dev1",waterPin,"Digital");

% add led channel
ch_LED = addoutput(daq6323,"Dev1",ledPin,"Digital");

% add sync led channel
% ch_SyncLED = addoutput(daq6323,"Dev1", "ctr2", "PulseGeneration");
ch_LEDPulse = addoutput(daq6323,"Dev1",syncPulsePin,"Voltage");
syncPulseSignal = repmat([5*ones(1,700) zeros(1,300)],1,5);

ch_SyncLED.Frequency = 1;
ch_SyncLED.InitialDelay = 0;
ch_SyncLED.DutyCycle = 0.7;

% now loop until user preses exit key
% When activated, dispense water whenever the port is touched

exitKey = 'x';
pulseKey = 's';
activateKey = 'a';
deactivateKey = 'd';

dispenseTime = 0.066; %based on 5/26 calibration 70ms ~ 3uL of water
timeoutDuration = 0.2; %wait at least this amount of time before another dispense
activeLimit = 6; %the number of times water is dispensed before auto deactivating the port
minTouchSamples = 5; %just the dispensing of the water seems to increase the touch edge counter by 1 or 2 for some reason

% initiate values
totalDispensed = 0;
activeDispensed = 0;
prevTouchCounts = 0;
active = false;
write(daq6323,[1 0 0])

% make figure for displaying active vs not and counter
mainFig = uifigure('KeyPressFcn',@KeyPress);
setappdata(mainFig,'allKeysPressed',{});
keysLegnedDisp = uilabel(mainFig,'Text',...
    ['Exit loop: "' exitKey '", Activate: "' activateKey '", Deactivate: "' deactivateKey '"'],...
    'FontSize',20,'Position',[100 360 400 50]);
activeStatusDisp = uilabel(mainFig,'Text','Port not active','FontColor','r',...
    'FontSize',20,'Position',[100 300 400 50]);
activeCountDisp = uilabel(mainFig,'Text','Current activation dispensed: 0',...
    'FontSize',20,'Position',[100 230 400 50]);
totalCountDisp = uilabel(mainFig,'Text','Total dispensed: 0',...
    'FontSize',20,'Position',[100 180 400 50]);

% start
disp('Starting water port control loop')

while true
    
    %only dispense if port is activated
    if active
        
        %read touch
        touchCounts = read(daq6323,'OutputFormat','Matrix');
        
        %dispense water if any touch activation edges were detected
        if touchCounts >= prevTouchCounts+minTouchSamples
            write(daq6323,[0 1 0])
            pause(dispenseTime)
            write(daq6323,[1 1 0])
            
            %update counters
            totalDispensed = totalDispensed + 1;
            activeDispensed = activeDispensed + 1;
            
            %update display
            set(activeCountDisp,'Text',['Current activation dispensed: ' num2str(activeDispensed)],...
                'FontSize',20,'Position',[100 230 400 50]);
            set(totalCountDisp,'Text',['Total dispensed: ' num2str(totalDispensed)],...
                'FontSize',20,'Position',[100 180 400 50]);
            
        end
        
        prevTouchCounts = touchCounts;
        
    end
    
    %check if active dispense limit is reached
    if activeDispensed >= activeLimit
        active = false;
        write(daq6323,[1 0 0])
        activeDispensed = 0;
        set(activeStatusDisp,'Text','Port not active','FontColor','r')
    end
    
    %check user inputs
    allKeysPressed = getappdata(mainFig,'allKeysPressed');
    if any(cellfun(@(x) strcmpi(x, exitKey), allKeysPressed))
        break;
        
    elseif any(cellfun(@(x) strcmpi(x, pulseKey), allKeysPressed))
        %do sync pulse
        startSyncPulse(daq6323, 1, syncPulseSignal);
        
    elseif any(cellfun(@(x) strcmpi(x, activateKey), allKeysPressed))...
            && active == false
        active = true;
        write(daq6323,[1 1 0])
        set(activeStatusDisp,'Text','Port active','FontColor','g')
        
    elseif any(cellfun(@(x) strcmpi(x, deactivateKey), allKeysPressed))...
            && active == true
        active = false;
        write(daq6323,[1 0 0])
        activeDispensed = 0;
        set(activeStatusDisp,'Text','Port not active','FontColor','r')
        
    end
    allKeysPressed = {};
    setappdata(mainFig,'allKeysPressed',allKeysPressed);
    clear allKeysPressed
    
    pause(timeoutDuration)
    
end

write(daq6323,[1 0 0])
stop(daq6323);
close(mainFig)

end

function KeyPress(src,event)
allKeysPressed = getappdata(src,'allKeysPressed');
allKeysPressed{end+1} = event.Key;
setappdata(src,'allKeysPressed',allKeysPressed);
end


function startSyncPulse(daqID, nPorts, pulseSig)

writeVec = [repmat([ones(length(pulseSig),1) zeros(length(pulseSig),1)],1,nPorts) pulseSig'];

readwrite(daqID,writeVec);

end


%
