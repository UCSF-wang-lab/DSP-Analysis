%%%%%
% lfp metadata and alignment point selection
%
% Use Processed > Aligned as current folder
%
% SCREENSHOT THE CLOCK RATIO AND CLOCK DRIFT PRINT OUT AT END AND PUT 
% SCREENSHOT IN Processed > Aligned folder as well
%
%%%%

function Preprocess3of11_AlignUnilateral()

new_folder = [pwd,'/Unilateral/'];
if ~isfolder(new_folder)
   disp([['Creating directory: '],new_folder])
   mkdir(new_folder)
end

subfolder = [new_folder,'Alignment Intermediate Files/'];
if ~isfolder(subfolder)
   disp([['Creating directory: '],subfolder])
   mkdir(subfolder)
end

% clear global
evalin('base','clear rcs_warmup')
evalin('base','clear rcs_ending')
evalin('base','clear teensy_warmup')
evalin('base','clear teensy_ending')

% import intermediate teensy data
disp('select intermediate teensy file')
[t_filename,t_path] = uigetfile('*.mat');
load([t_path,t_filename])

% import intermediate rcs data
disp('select intermediate rcs file')
[r_filename,r_path] = uigetfile('*.mat');
load([r_path,r_filename])

% found in saved workspace from conversion of alldatatables to combineddata table > timeDomainSettings, this is where official
% labels of each channel can be found, and these chans correspond as
% chan0=tdkey0, chan1=tdkey1, chan2=tdkey2, chan3=tdkey3
% for rcs14L on Day1,it's shifted as chan1-4 instead of 0-3 but presumably
% the same. also, the tdkey values are in mV
% DerivedTime in combinedDataTable is actually the harmonized
% unifiedderivedtime

% for rcs16 day 2, when fucked up end of experiment sweep, tried
% calculating clock ratios between different stim artifacts that i do have
% and got inconsistent results. uncorrected total drift across experiment
% may be anywhere between -199 ms to + 1.574 sec
% choosing to just start with beginning and trim some similar amount of
% time


xxx = 1:3000;
notification = 0.1*sin(.15*xxx);

% id data
id = metaData.subjectID;

% lfp data
vars = fieldnames(combinedDataTable); n_vars = length(vars); 
lfp = [];
for v = 1:n_vars
    if contains(vars{v},'TD_key','IgnoreCase',true)
        lfp = [lfp, combinedDataTable.(vars{v})];
    end
end
n_chan = size(lfp,2);

% channel metadata
vars = timeDomainSettings.Properties.VariableNames; n_vars = length(vars);
contacts = cell(1,n_chan);
i = 1;
for v = 1:n_vars
    if contains(vars{v},'chan','IgnoreCase',true)
        contacts{i} = timeDomainSettings.(vars{v}){1};
        del = strfind(contacts{i},'L');
        contacts{i} = eraseBetween(contacts{i}, del(1)-1, length(contacts{i}));
        i = i+1;
    end
end

% downsampling the teensy to match the RCS time vector and sampling rate,
% so the rcs time and fs are going to be the shared vectors
time = (combinedDataTable.DerivedTime-combinedDataTable.DerivedTime(1))/1000;
fs = find(~isnan(combinedDataTable.TD_samplerate));
fs = combinedDataTable.TD_samplerate(fs(1));


% first pick which rcs channel to use for alignment
axes = [];
figure(1)
tiledlayout(n_chan,1)
for n = 1:n_chan
    nexttile;
    plot(lfp(:,n))
    title(['Channel ',num2str(n),'   ',contacts{n}])
    axes = [axes, gca];
end
linkaxes(axes,'x')


channel_align = input('Select which channel to use for alignment:  ');
close all

% for rcs14, using channel 1, expecting to see 22 alignment pulses on rcs
% and only 21 of those reflected on teensy (since last one I did after
% disconnecting teensy

% plot eeg and rcs data together to manually select alignment points
figure(2)
t = tiledlayout(3,1);
t.TileSpacing = 'none';
ax5 = nexttile;
plot(data_teensy.time, data_teensy.eeg)
title('RAW EEG signal')
ax6 = nexttile;
plot(data_teensy.time, data_teensy.eeg_filtered)
title('FILTERED EEG signal')
% hold on
% plot(data_teensy.time, 300*data_teensy.cue_state)
ax7 = nexttile;
plot(data_teensy.time, data_teensy.eeg_filtered2)
title('FILTERED EEG 2 signal')

figure(3)
plot(data_teensy.time,data_teensy.photo);
ax8=gca;
linkaxes([ax5,ax6,ax7,ax8],'x')

figure()
plot(data_teensy.time,data_teensy.eeg_filtered3);
ax9 = gca;
linkaxes([ax5,ax6,ax7,ax8,ax9],'x')

figure(4)
plot(time, lfp(:,channel_align))

%%%%%%%%
disp('Align')
% use tools>brush in plotter toolbar to select points and then right click
% the correct point and save it as appropriate var

% label the RCS warmup alignment point rcs_warmup
% label teensy warmup point teensy_warmup
% then there are also rcs_ending and teensy_ending
%%%%%%%

abort = input('Indicate when you are done marking/exporting rcs_warmup, teensy_warmup, rcs_ending, teensy_ending [0/1]: ');
if isempty(abort) || abort ~= 1
    error('restart function to re-do alignment point selection process')
end

%% import exported indices from base workspace

rcs_warmup = evalin('base','rcs_warmup');
teensy_warmup = evalin('base','teensy_warmup');

rcs_ending = evalin('base','rcs_ending');
teensy_ending = evalin('base','teensy_ending');

%% determine indices of selected alignment points
rcs_align_ind = [find(rcs_warmup(1)==time),find(rcs_ending(1)==time)];
teensy_align_ind = [find(teensy_warmup(1)==data_teensy.time),find(teensy_ending(1)==data_teensy.time)];
% there shouldn't be more than one that equals, but maybe add a check for
% this

% temp for rcs16 day 2
% rcs_ending = rcs_warmup(1) + 1735;
% rcs_align_ind = [find(rcs_warmup(1)==time),find(rcs_ending==time)];
% teensy_ending = teensy_warmup(1)+1735;
% teensy_align_ind = [find(teensy_warmup(1)==data_teensy.time),find(teensy_ending==data_teensy.time)];

%% make and save a plot of the alignment point used in case need to look later

close all

ff=figure();
t = tiledlayout(2,1);
t.TileSpacing = 'none';
ax1 = nexttile;
plot(data_teensy.time, data_teensy.eeg)
title('Raw EEG')
hold on
scatter(data_teensy.time(teensy_align_ind),data_teensy.eeg(teensy_align_ind),3,'m','LineWidth',2)

ax2 = nexttile;
plot(time, lfp(:,channel_align))
title(['alignment channel = ',num2str(channel_align)])
hold on
scatter(time(rcs_align_ind), lfp(rcs_align_ind,channel_align),3,'m','LineWidth',2)

savefig(ff,[subfolder,date,'_',id,'_','AlignmentPoints_',lower(taskday_condition),'_plot'])

%% just do sanity check, do NOT save, to make sure it is correct files selected. screenshot clock ratio and clock drift

% make copy of teensy data for comparisons if troubleshooting
data_teensy_copy = data_teensy;
lfp_copy = lfp;
time_copy = time;

% get rid of excess data
% VERY IMPORTANT to trim the end before trimming the beginning
lfp_copy(rcs_align_ind(2)+1:end,:) = []; time_copy(rcs_align_ind(2)+1:end) = [];
lfp_copy(1:rcs_align_ind(1)-1,:) = []; time_copy(1:rcs_align_ind(1)-1) = [];

data_teensy_copy(teensy_align_ind(2)+1:end,:) = [];
data_teensy_copy(1:teensy_align_ind(1)-1,:) = [];

% zero them
data_teensy_copy.time = data_teensy_copy.time-data_teensy_copy.time(1);
time_copy = time_copy-time_copy(1);

% determine their relative clock speeds   %rcs speed over teensy speed

% !!!!!!! maybe change this to be the ratio of the difference in time in
% case either of the two are missing time points, though they shouldn't be
% at this point in preprocessing
% ratio = (length(time)*(teensy_fs/fs))/length(data_teensy.time); 
ratio = max(time_copy)/max(data_teensy_copy.time);
disp(['Clock speed ratio of RCS to teensy is ',num2str(ratio)])

timeshift = max(data_teensy_copy.time)-max(time_copy);
disp(['Time shift from RCS to teensy is ',num2str(timeshift)])

clear data_teensy_copy
clear time_copy
clear lfp_copy
clear ratio
clear timeshift

%% save the alignment points

close all

save([subfolder,'PointsWorkspace_Unilateral_',id,'_',lower(taskday_condition),'_',date,'.mat'])
fclose('all');

%%

clear all

end