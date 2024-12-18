%%%%
% initial Teensy processing
%
% use Processed > Teensy as current folder
%%%%

function Preprocess2of11_ExtractTeensy()
% does preprocessing wrt: data format, packet loss, debouncing, eeg filtering,
% photodiode filtering
% use different script to process FSRs, Proximity sensors, etc. and do
% AFTER alignment so that if I want to change how I do that preprocessing
% down the line, I don't end up in a situation where I'm potentially having
% to realign data
% doing photodiode preprocessing here just because it's easier to align if
% I have the photodiode preprocessed.

first_pax = 5; % acceptable time duration (in sec) of incorrectly timed packets at beginning
error_space = [0.9, 1.1]; % acceptable proportion range of delay for delayed but not missing packet to still be used

%% file selection

% select teensy file
disp('select raw teensy file')
[rawdata_filename,rawdata_path] = uigetfile('*.txt');

% mark the day and treatment
day = str2num(rawdata_filename(strfind(rawdata_filename,'day')+3));
if isempty(day)
    day = str2num(rawdata_filename(strfind(rawdata_filename,'Day')+3));
    if isempty(day)
        error('Please indicate the day of the experiment in the teensy filename')
    end
end

treatment = [];
poss_treats = ["highon","lowoff","highoff","lowon","highmedonstim","lowmedonstim","highmedoffstim","lowmedoffstim","highdaonstim","lowdaonstim","highdaoffstim","lowdaoffstim","offoff","offmedoffstim","naon","naoff","namedoffstim","namedonstim","nadaonstim","nadaoffstim"]; n_treats = size(poss_treats,2);
for treat = 1:n_treats
    spot = strfind(lower(rawdata_filename),poss_treats(treat));
    if ~isempty(spot)
       treatment = lower(rawdata_filename(spot:spot-1+size(poss_treats{treat},2)));
       treatment = erase(treatment,"med");
       treatment = erase(treatment,"stim");
       treatment = erase(treatment,"da");
    end
end

if isempty(treatment)
    error('Please rename the teensy filename correctly with one of the listed treatment type options: lowoff, highoff, lowon, highon, offoff, onoff, naoff, naon')
end


% select matlab config file
disp('select matlab test_config file')
[config_fn,config_path] = uigetfile('*.txt');
full_path = [config_path,config_fn];


%% teensy data and matlab metadata import

% import raw teensy data as table
data_raw = ConvertTeensyTxt([rawdata_path,rawdata_filename]);
data_teensy = table(); % table for processed data

vars = data_raw.Properties.VariableNames;
n_vars = length(vars);

try 
    teensy_fs = data_raw.Fs(100);
catch
    warning('Teensy data does not include attempted sampling rate')
    teensy_fs = input('What is the teensy sampling rate (Hz)? ');
end
    
try
    debounce = data_raw.Debounce(100)/1000;
catch
    warning('Teensy data does not include debounce')
    debounce = input('What is the teensy debounce (ms)? ')/1000;
end

% debounce = 0.005; % time in sec of the key switch debounce time
% fs = 4000;

% load matlab metadata
[block_order,n_blocks,seqs,n_reps] = LoadTaskMetadata(full_path);


%% first fix missing packets
first_pax = first_pax*teensy_fs;

packet_size = 1/teensy_fs;
packet_range = error_space*packet_size;

% check if any are missing/delayed
temp = diff(data_raw.ElapsedMicros); % difference in micros between each timestamp
figure(1)
plot(temp)
temp = temp/1000000;

indx = find(temp ~= packet_size); % find indices of missing/delayed packets

% if they are within the first throwaways, just delete
if ~isempty(indx)
    trash = indx(indx <= first_pax);      
    trash = max(trash);
    data_raw(1:trash,:) = [];
    % temp(1:trash,:) = [];
    
    if sum(indx > first_pax) ~= 0
        error('There are missing packets after the throwaway period. Deal with this before proceeding.')
        % for any other missing packets, fill them in appropriately
        % MUST BE COMPENSATION IN SUBSEQUENT PACKET (besides first throw out packets) OR THROW ERROR TO ADDRESS
        % then shift the time to start at zero 
    end
    
end

disp('Packets done')

%% then fix debounce

debounce_size = round(debounce*teensy_fs); % how many packets wide to shift for the debounce
if rem(debounce_size,1)~=0
    warning('Debounce was not selected properly, and key values are being shifted by a fractional number of samples')
end

n_keys = 0;

% determine which columns contain key information & shift by debounce
for v = 1:n_vars
    if contains(vars{v},'key','IgnoreCase',true)
        n_keys = n_keys+1;
        key_name = vars{v};
        temp = data_raw.(key_name);
        temp = temp(debounce_size+1:end);
        temp = [temp; nan(debounce_size,1)];
        data_teensy.(lower(key_name)) = temp; 
    end
end

disp('Debounce done')

%% make specific time variable (in units of sec) for alignment with rcs

% at some point need to compare the different clocks on the teensy to each
% other, and see if ElapsedMicros is really best thing to use here

data_teensy.time = data_raw.ElapsedMicros;
data_teensy.time = data_teensy.time-data_teensy.time(1);
data_teensy.time = data_teensy.time/1000000;

n_time = length(data_teensy.time);

disp('New time variable created')

%% then filter EEG

% this filtering induces a phase lag
% data_raw.FilteredEEG = bandstop(data_raw.EEG,[40,70],fs);

%not really sure which of the following two zero phase filters is best.
% the first one adds waveyness to the stim pulse but is spot-on with
% timing. there may be some sort of weird 125us shift to the left in the
% second one, but it doesn't add the waveyness but it filters slightly less
% maybe idk

rng default
% zero-phase filtering:
d = designfilt('bandstopfir', 'PassbandFrequency1', 40, 'StopbandFrequency1', 45, 'StopbandFrequency2', 70, 'PassbandFrequency2', 75, 'PassbandRipple1', 1, 'StopbandAttenuation', 60, 'PassbandRipple2', 1, 'SampleRate', teensy_fs, 'DesignMethod', 'equiripple');

d2 = designfilt('bandstopfir', 'PassbandFrequency1', 40, 'StopbandFrequency1', 45, 'StopbandFrequency2', 200, 'PassbandFrequency2', 205, 'PassbandRipple1', 1, 'StopbandAttenuation', 60, 'PassbandRipple2', 1, 'SampleRate', teensy_fs, 'DesignMethod', 'equiripple');
% lowpass(data_teensy.eeg,10,4000)

% if strcmp(id,'RCS14')
    eeg_100 = bandpass(data_raw.EEG,[70 130],500);
    data_teensy.eeg_filtered3 = eeg_100;
% end

% ...
%     'StopbandFrequency',0.2, ...
%     'PassbandRipple',1,'StopbandAttenuation',60, ...
%     );

data_teensy.eeg = data_raw.EEG;

data_teensy.eeg_filtered = filtfilt(d,data_raw.EEG);
data_teensy.eeg_filtered = filtfilt(d,flip(data_teensy.eeg_filtered));
data_teensy.eeg_filtered = flip(data_teensy.eeg_filtered);

data_teensy.eeg_filtered2 = filtfilt(d2,data_raw.EEG);
data_teensy.eeg_filtered2 = filtfilt(d2,flip(data_teensy.eeg_filtered2));
data_teensy.eeg_filtered2 = flip(data_teensy.eeg_filtered2);

% 
% % plot both raw and filtered EEG on same plot, linked axes
figure(3)
ax1 = subplot(3,1,1);
plot(data_raw.EEG)
title('Raw EEG')
ax2 = subplot(3,1,2);
plot(data_teensy.eeg_filtered)
title('Filtered EEG')
ax3 = subplot(3,1,3);
plot(data_teensy.eeg_filtered2)
title('Filtered EEG 2')
linkaxes([ax1,ax2,ax3],'x')

% GenericTimePlot(data_raw.EEG,fs,'Raw EEG','Analog',[0 1000]);
% GenericTimePlot(data_raw.FilteredEEG,fs,'Filtered EEG','Analog',[0 1000]);

% 
% d_temp = designfilt('lowpassfir', ...
%     'PassbandFrequency',0.15,'StopbandFrequency',0.2, ...
%     'PassbandRipple',1,'StopbandAttenuation',60, ...
%     'DesignMethod','equiripple');
% data_teensy.eeg_filtered_temp = filtfilt(d_temp,data_raw.EEG);

savefig(['very raw EEG',rawdata_filename(1:end-4),'_',date])
disp('EEG done')
% close all

%% copy over the other variables

data_teensy.photo = data_raw.PhotoD;

n_fsr = 0;
for v = 1:n_vars
    if contains(vars{v},'fsr','IgnoreCase',true)
        n_fsr = n_fsr+1;
        data_teensy.(lower(vars{v})) = data_raw.(vars{v});
    end
end

n_cap = 0;
for v = 1:n_vars
    if contains(vars{v},'cap','IgnoreCase',true)
        n_cap = n_cap+1;
        data_teensy.(lower(vars{v})) = data_raw.(vars{v});
    end
end

%% save fig of the teensy data for quick viewing
% % plot both raw and filtered EEG on same plot, linked axes
figure(4)
stackedplot(data_teensy)
savefig(['teensy stackedplot',rawdata_filename(1:end-4),'_',date])
% close all

%% save intermediate data

save(['IntermediateTeensy_',rawdata_filename(1:end-4),'_',date,'.mat'],'data_teensy','teensy_fs','n_blocks','seqs','n_reps','day','treatment','n_keys','n_cap','n_fsr','block_order','rawdata_filename')


end