%%%%%%%%%%
%
% use Processed > Aligned as current folder
%
% this file is used for aligning the two hemispheres to each other
% first align and harmonize each hemisphere to its respective teensy in
% previous files, and then align the two hemispheres to each other in this
% file by aligning the two teensies to each other using any high frequency
% artifact appearing in both teensies
%
% other option is to align teensy to RCSL first and then align the result
% to RCS R which cuts time in half on harmonizing
%
% which of these options is used really depends on how much of a stim pulse
% is captured in the ones that are inverted on teensy (the R side ones). If
% it is high enough in amplitude then the downsampling wont eradicate the
% presence/smooth over the inverted pulses
%
% can't just align R and L RCS to each other directly bc that relies on
% delay of the pulses being propogated across the hemispheres of the brain
% or between IPGs across the chest. And L/R pulses dont show up in opposing
% side sensing when active recharge is on anyway
%
%%%%%%%%%

function Preprocess5of11_AlignBilateral()

%% create folder for saving
new_folder = [pwd,'/Bilateral/'];
if ~isfolder(new_folder)
   disp([['Creating directory: '],new_folder])
   mkdir(new_folder)
end

subfolder = [new_folder,'Alignment Intermediate Files/'];
if ~isfolder(subfolder)
   disp([['Creating directory: '],subfolder])
   mkdir(subfolder)
end

%% first import all the data from each hemisphere into its own structure

% import left side data
fprintf('\n')
fprintf('\n')
fprintf('\n')
disp('select harmonized LEFT side data')
[l_filename,l_path] = uigetfile('*.mat');
left = struct();
left = load([l_path,l_filename]);

fprintf('\n')
disp('\\\\\\\\\\\\\\\\\\')
fprintf('\n')
disp(l_filename)
fprintf('\n')
disp('\\\\\\\\\\\\\\\\\\')


% import right side data
fprintf('\n')
fprintf('\n')
fprintf('\n')
disp('select harmonized RIGHT side data')
[r_filename,r_path] = uigetfile('*.mat');
right = struct();
right = load([r_path,r_filename]);

fprintf('\n')
disp('\\\\\\\\\\\\\\\\\\')
fprintf('\n')
disp(r_filename)
fprintf('\n')
disp('\\\\\\\\\\\\\\\\\\')

%% make neutral vars

% make it so that everything uses the left side stuff and throws errors if
% they are not the same
id = left.id;
id = id(1:end-1);
block_order = left.block_order;
day = left.day;
fs = left.fs;
n_blocks = left.n_blocks;
n_cap = left.n_cap;
n_fsr = left.n_fsr;
n_keys = left.n_keys;
n_reps = left.n_reps;
rawdata_filename = left.rawdata_filename;
seqs = left.seqs;
treatment = left.treatment;

if sum(block_order ~= right.block_order) > 0
    error('difference bw right and left block_order')
elseif day ~= right.day
    error('difference bw right and left day')
elseif fs ~= right.fs
    error('difference bw right and left fs')
elseif sum(id ~= right.id(1:end-1)) > 0
    error('difference bw right and left id')
elseif sum(rawdata_filename ~= right.rawdata_filename) > 0
    error('difference bw right and left teensy filename')
elseif sum(seqs ~= right.seqs) > 0
    error('difference bw right and left seqs')
elseif sum(treatment ~= right.treatment) > 0
    error('difference bw right and left treatment')
end

% remove the behavioral fields from the left/right structures
to_remove = {'block_order';'n_blocks';'n_cap';'n_fsr';'n_keys';'n_reps';'rawdata_filename';'seqs'};
for var = 1:numel(to_remove)
    left = rmfield(left,to_remove{var});
    right = rmfield(right,to_remove{var});
end

%%

% plot the teensy data & lfp for each side in two separate plots
figure()
tt = tiledlayout(2,1);
t.TileSpacing = 'none';
ax1 = nexttile;
plot(left.time,left.lfp(:,left.channel_align));
title(['left alignment channel: ',num2str(left.channel_align)])
ax2 = nexttile;
plot(left.time,left.data_teensy.eeg)
title('left teensy raw eeg')
linkaxes([ax1,ax2],'x')

figure()
tt = tiledlayout(2,1);
t.TileSpacing = 'none';
ax1 = nexttile;
plot(right.time,right.lfp(:,right.channel_align));
title(['right alignment channel: ',num2str(right.channel_align)])
ax2 = nexttile;
plot(right.time,right.data_teensy.eeg)
title('right teensy raw eeg')
linkaxes([ax1,ax2],'x')

%%

abort = input('Indicate when you are done marking/exporting left_start and right_start [0/1]: ');
if isempty(abort) || abort ~= 1
    error('restart function to re-do alignment point selection process')
end

%% import exported indices from base workspace

left_start = evalin('base','left_start');
right_start = evalin('base','right_start');

%% determine indices of selected alignment points

left_align_ind = find(left_start(1)==left.time);
right_align_ind = find(right_start(1)==right.time);

%% make and save a plot of the alignment point used in case need to look later

f1  = figure();
tt = tiledlayout(2,1);
t.TileSpacing = 'none';
ax1 = nexttile;
plot(left.time,left.lfp(:,left.channel_align));
title(['left alignment channel: ',num2str(left.channel_align)])
ax2 = nexttile;
plot(left.time,left.data_teensy.eeg)
hold on
scatter(left.time(left_align_ind), left.data_teensy.eeg(left_align_ind),3,'m','LineWidth',2)
title('left teensy raw eeg')
linkaxes([ax1,ax2],'x')
savefig(f1,[subfolder,date,'_',left.id,'_','Bilateral_AlignmentPoints_day',num2str(day),'_',treatment,'_plot'])

f2 = figure();
tt = tiledlayout(2,1);
t.TileSpacing = 'none';
ax1 = nexttile;
plot(right.time,right.lfp(:,right.channel_align));
title(['right alignment channel: ',num2str(right.channel_align)])
ax2 = nexttile;
plot(right.time,right.data_teensy.eeg)
hold on
scatter(right.time(right_align_ind), right.data_teensy.eeg(right_align_ind),3,'m','LineWidth',2)
title('right teensy raw eeg')
linkaxes([ax1,ax2],'x')
savefig(f2,[subfolder,date,'_',right.id,'_','Bilateral_AlignmentPoints_day',num2str(day),'_',treatment,'_plot'])


%% save the alignment points

close all

save([subfolder,'PointsWorkspace_Bilateral_',id,'_day',num2str(day),'_',treatment,'_',date,'.mat'])
fclose('all');

%% data alignment and trimming

% make copy for comparisons
og_right = right; og_left = left;

% get rid of excess data
left.lfp(1:left_align_ind-1,:) = []; left.time(1:left_align_ind-1) = [];
left.data_teensy(1:left_align_ind-1,:) = [];

right.lfp(1:right_align_ind-1,:) = []; right.time(1:right_align_ind-1) = [];
right.data_teensy(1:right_align_ind-1,:) = [];

% zero them
left.time = left.time-left.time(1);
right.time = right.time-right.time(1);

% trim to same length
% determine which vector is shorter
ll = length(left.time);
rl = length(right.time);
lengths = [ll, rl];
maxlength = min(lengths);

% trim both to that length
if ll > maxlength
    left.lfp(maxlength+1:end,:) = []; left.time(maxlength+1:end) = [];
    left.data_teensy(maxlength+1:end,:) = [];
end

if rl > maxlength
    right.lfp(maxlength+1:end,:) = []; right.time(maxlength+1:end) = [];
    right.data_teensy(maxlength+1:end,:) = [];
end

% sanity plot
f3 = figure();
tt = tiledlayout(4,1);
tt.TileSpacing = 'none';
ax1 = nexttile;
plot(left.time,left.lfp(:,left.channel_align))
title('left')
ax2 = nexttile;
plot(right.time,right.lfp(:,right.channel_align))
title('right')
ax3=nexttile;
plot(left.time,left.data_teensy.eeg_filtered)
title('left teensy eeg filtered')
ax4=nexttile;
plot(right.time,right.data_teensy.eeg_filtered)
title('right teensy eeg filtered')
linkaxes([ax1,ax2,ax3,ax4],'x')
savefig(f3,[subfolder,date,'_',id,'_','Bilaterally Aligned Data_day',num2str(day),'_',treatment,'_plot'])

%% format

% make it so that everything uses the left side stuff and throws errors if
% they are not the same
data_teensy = left.data_teensy;
time = left.time;

if height(data_teensy) ~= height(right.data_teensy)
    error('difference bw right and left data_teensy tables')
elseif sum(round(time,4) ~= round(right.time,4)) > 0
    error('difference bw right and left time vector')
end
   
% remove the behavioral fields from the left/right structures
to_remove = {'data_teensy'};
for var = 1:numel(to_remove)
    left = rmfield(left,to_remove{var});
    right = rmfield(right,to_remove{var});
end

%% save Aligned File

save([subfolder,'BilaterallyAlignedData_',id,'_day',num2str(day),'_',treatment,'_',date,'.mat'], 'left','right','data_teensy','fs','time','id','treatment','day','n_blocks','block_order','n_reps','seqs','n_keys','n_fsr','n_cap','rawdata_filename')


end