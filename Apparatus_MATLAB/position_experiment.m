function position_experiment()
% Runs position control experiment and records data

numTrials = 10;
filename = 'edges.mat';
trajectory = [0,0;.5,40;1,80];    % [t1,p1;t2,p2;t3,p3]
mode = 'linear';                  % 'linear','cubic', or 'step' trajectory

%% Configure serial communications

NU32_port = 'COM5'; % NU32 board serial port
XY_port = 'COM4';   % GRBL board serial port

% Opening COM connection
if ~isempty(instrfind)
    fclose(instrfind);
    delete(instrfind);
end

% configure ports
XY_Serial = serial(XY_port, 'BaudRate', 115200,'Timeout',15);
NU32_Serial = serial(NU32_port, 'BaudRate', 403200, 'FlowControl', 'hardware','Timeout',15); 

fprintf('Opening ports %s and %s....\n',NU32_port,XY_port);

% opens serial connection
fopen(NU32_Serial);
fopen(XY_Serial);

clean1 = onCleanup(@() cleanup(NU32_Serial,XY_Serial)); % close serial ports and turn off motors

%% Configure data structure for data collection

% Store metadata info in metadata struct
experimental_data.metadata.date = datetime();
experimental_data.metadata.foot_radius = 25.4; % mm
experimental_data.metadata.deceleration_time = 10; % s
experimental_data.metadata.control_frequency = 2000; % Hz

%% Setup apparatus for experiment

% startup the linear motor
linmot_startup(NU32_Serial);

% startup the xy table
grbl_startup(XY_Serial);

% generate linear motor trajectory
fprintf('Loading trajectory ...\n');

fprintf(NU32_Serial,'%c\n','i');            % tell PIC to load position trajectory
ref = genRef_position(trajectory,mode);     % generate trajectory
ref = ref * 1000;                           % convert trajectory to um
fprintf(NU32_Serial,'%d\n',size(ref,2));    % send number of samples to PIC32
for i = 1:size(ref,2)
    fprintf(NU32_Serial,'%f\n',ref(i));  % send trajectory to PIC32
end

%% experiment %%

for trial = 1:numTrials
    
    save(filename,'experimental_data'); % save file after every trial
    
    %% Setup apparatus for trial
    return_to_origin(NU32_Serial);  % return motor to origin
    grbl_home(XY_Serial);           % return table to home
    
    % fluidize the bed
    frequency = 56;
    time = 10;
    fluidize_bed(NU32_Serial,frequency,time);
    pause(10);
    
    % move table to initial position
    posy = 100;   % y coordinate
    posx = 100;    % x coordinate
    grbl_moveX(XY_Serial,posx);
    grbl_moveY(XY_Serial,posy);
    
    % determine bed height
    fprintf('Determining bed height\n');
    img_name = sprintf('trial%d.bmp',trial);
    bedheight = acquire_image(img_name);
    experimental_data.trials(trial).bedheight = bedheight;
    
    %% Perform intrusions and record data
    
    DECIMATION = 2; % sample rate = control rate / DECIMATION (needs to match value on PIC32)
    
    intrude = 'l';       % execute trajectory
    intrusion = 1;       % counter
    
    
    step_size = 200; % movement distance
    stepsx = 2;      % number of steps in x direction
    stepsy = 1;      % number of steps in y direction
    
    fprintf('Plunging motor ...\n');
    for i = 1:stepsx
        for j = 1:stepsy
            % Perform intrusion
            fprintf(NU32_Serial,'%c\n',intrude);                                      % tell PIC32 to intrude
            data = read_plot_matrix_position(NU32_Serial,0,ref(1:DECIMATION:end));    % read data back from PIC32
            return_to_origin(NU32_Serial);                                            % return motor to origin
            
            % Store data
            experimental_data.trials(trial).intrusion(intrusion).sample_number = 1:size(data,1);
            experimental_data.trials(trial).intrusion(intrusion).reference_position = data(:,1);
            experimental_data.trials(trial).intrusion(intrusion).actual_position = data(:,2);
            experimental_data.trials(trial).intrusion(intrusion).motor_current = data(:,3);
            experimental_data.trials(trial).intrusion(intrusion).Fz = data(:,4);
            experimental_data.trials(trial).intrusion(intrusion).Tx = data(:,5);
            experimental_data.trials(trial).intrusion(intrusion).Ty = data(:,6);
            experimental_data.trials(trial).intrusion(intrusion).x_pos = posx;
            experimental_data.trials(trial).intrusion(intrusion).y_pos = posy;
            
            % Move table
            if j ~= stepsy
                if mod(i,2) == 1
                    posy = posy + step_size; % move position forward
                else
                    posy = posy - step_size; % move position backward
                end
                grbl_moveY(XY_Serial,posy); % move table to target position
                pause(3);                   % wait
            end
            
            intrusion =+ 1; % increment intrusion number
            
        end
        
        if i ~= stepsx
            posx = posx + step_size;    % move position forward
            grbl_moveX(XY_Serial,posx); % move table to target position
            pause(4);                   % wait
        end
    end
    
    fprintf('Trial %d complete\n',trial);

end

save(filename,'experimental_data');

end