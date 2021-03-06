function bed_height_experiment()
%%
filename = 'bed_height_180.txt';
calibration = 52;
numtrials = 5;
decel_time = 180;
frequency = 56;

fileID = fopen(filename,'w');
fprintf(fileID,'bed height experiment\r\n');
fprintf(fileID,'%s\r\n',datetime('today'));
fprintf(fileID,'blower deceleration time = %d s\r\n',decel_time);
fprintf(fileID,'blower frequency = %d Hz\r\n',frequency);
fprintf(fileID,'calibration: %d pixel/cm\r\n',calibration);
%%
% NU32 board serial port
NU32_port = 'COM5';

% GRBL board serial port
XY_port = 'COM4';

% Opening COM connection
if ~isempty(instrfind)
    fclose(instrfind);
    delete(instrfind);
end

% configure ports
XY_Serial = serial(XY_port, 'BaudRate', 115200,'Timeout',30);
NU32_Serial = serial(NU32_port, 'BaudRate', 403200, 'FlowControl', 'hardware','Timeout',30); 

fprintf('Opening ports %s and %s....\n',NU32_port,XY_port);

% opens serial connection
fopen(NU32_Serial);
fopen(XY_Serial);

clean = onCleanup(@() cleanup(NU32_Serial,XY_Serial,fileID)); % close serial ports and turn off motors

%%
fprintf(fileID,'\r\nTrail    Mean Height(cm)    Std (cm)\r\n');
for i = 1:numtrials
    % fluidize the bed
    fluidize_bed(NU32_Serial,frequency, 10);
    pause(decel_time);
    
    % aquire image
    fprintf('aquiring image\r\n');
    imgID = sprintf('trial%d.bmp',i);
    [means(i), stds(i)] = acquire_image(imgID);
    fprintf(fileID,'%d        %f           %f\r\n',i,means(i),stds(i));
end

fprintf(fileID,'\r\n average: %f cm\r\n',mean(means));
fprintf(fileID,'std of means: %f cm\r\n',std(means));

fprintf('done\r\n');
