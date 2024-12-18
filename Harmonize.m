function Harmonize(fname,fpath)

% load data
load([fpath,fname])

xxx = 1:3000;
notification = 0.1*sin(.15*xxx);

%% harmonize

disp(['Starting time is ',datestr(datetime)])

% make copy of teensy data for comparisons
data_teensy_og = data_teensy;

% get rid of excess data
% VERY IMPORTANT to trim the end before trimming the beginning
lfp(rcs_align_ind(2)+1:end,:) = []; time(rcs_align_ind(2)+1:end) = [];
lfp(1:rcs_align_ind(1)-1,:) = []; time(1:rcs_align_ind(1)-1) = [];

data_teensy(teensy_align_ind(2)+1:end,:) = [];
data_teensy(1:teensy_align_ind(1)-1,:) = [];

% zero them
data_teensy.time = data_teensy.time-data_teensy.time(1);
time = time-time(1);

% determine their relative clock speeds   %rcs speed over teensy speed

% !!!!!!! maybe change this to be the ratio of the difference in time in
% case either of the two are missing time points, though they shouldn't be
% at this point in preprocessing
% ratio = (length(time)*(teensy_fs/fs))/length(data_teensy.time);
ratio = max(time)/max(data_teensy.time);
disp(['Clock speed ratio of RCS to teensy is ',num2str(ratio)])

timeshift = max(data_teensy.time)-max(time);
disp(['Time shift from RCS to teensy is ',num2str(timeshift)])

% then change the actual values in the teensy time vector accordingly
data_teensy.time = data_teensy.time*ratio;



% then downsample the teensy by choosing the values closest to the time
% values that correspond to the time values in the rcs time
%for each value in rcs_time, find the index of the closest time value in
%the teensy data. Add that row of values (all the teensy data at that time
%point) to the keep selection
ind_keep = nan(length(time),1);
n_time = length(time);
prog = 0;
temp = data_teensy.time;
tic
for t = 1:n_time      % could make this a lot faster by deleting already skipped points and then shifting index accordingly but meh
    val = time(t);
    diff = abs(temp-val);
    [~,ind] = min(diff);  % if there's more than one min match, it returns the first index corresponding to a min
    ind_keep(t) = ind;
    if prog == 0 && round(t/n_time,2) == 0.25
        toc
        disp(['Current time is ',datestr(datetime)])
        disp('     downsampling 25% complete')
        prog = 1;
    elseif prog == 1 && round(t/n_time,2) == 0.50
        toc
        disp(['Current time is ',datestr(datetime)])
        disp('       downsampling 50% complete')
        prog = 2;
    elseif prog == 2 && round(t/n_time,2) == 0.75
        toc
        disp(['Current time is ',datestr(datetime)])
        disp('          downsampling 75% complete')
        prog = 3;
    elseif prog == 3 && round(t/n_time,2) == 1.00
        toc
        disp(['Current time is ',datestr(datetime)])
        prog = 4;
        disp('             downsampling 100% complete')
        sound(notification)
    end
end

%delete all rows of data_teensy that are not in the keep rows list... or
%just make a new table keeping only those
temp = data_teensy; % copy to compare
data_teensy = data_teensy(ind_keep,:);
data_teensy = removevars(data_teensy,{'time'});

% compare the downsampled data to itself and look at the shift between the
% rcs and teensy datasets
f4 = figure(4);
tiledlayout(2,1)
ax1 = nexttile;
plot(temp.time,temp.fsr3,'LineWidth',2)
xlabel('Time (sec)')
title('FSR3 original')
ax2 = nexttile;
plot(time,data_teensy.fsr3,'LineWidth',2)
xlabel('Time (sec)')
title('FSR3 downsampled')
linkaxes([ax1,ax2],'xy')
savefig(f4,[fpath,'fsr3_downsample_example'])

f5 = figure(5);
plot(ind_keep)
hold on
plot(1:8:length(temp.time))
title('drift between clocks')
savefig(f5,[fpath,id,'_clockdrift'])

close all

% there's a 7.5ms drift between the two clocks for the duration of the
% experiment. The teensy seems to be the faster clock of the two.
% (size(data_teensy,1)/8)-size(rcs_lfp,1)

% questionable VV instead may want to just save the different matrices or
% use structs or something. will eventually want key and fsr stuff to be in
% matrices so that i can loop over them individually more easily rather
% than having to do a var search like i did in the teensy preprocessing
% (maybe go back and change that too eventually). could have diff matrices
% or each and could put them in a shared structure if really necessary
% ... kinda like the idea of having an rcs struct and a teensy struct plus
% a time vector and then only have to save three things
% replace the teensy time vector with the new shared time vector rcs_time
% add rcs data, sampling rate, names etc. to the teensy table just so everything can be saved as one
% table
% ok long term want each in a structure and all the fieldnames to be
% lowercase including teensy ones so move this part to preprocessing before
% modifying all that to be suited for structures or just convert it to a
% structure with lowercase vars at the end of its preprocessing
% but can i delete whole rows of structures across fields at once like you can in tables
% https://www.mathworks.com/matlabcentral/answers/4577-convert-matrix-to-vector-of-structs
% https://www.mathworks.com/matlabcentral/answers/4581-deleting-the-i-th-entry-from-all-fields-of-a-struct
% is it worth it to just forgo the structures or tables all together and
% stick with matrices and just deal with having more variables to pass
% between functions?
% maybe a struct that contains the table time series and then random other
% variables

%% rename contacts for saving files without symbols

contacts_save = cell(n_chan,1);
for chan = 1:n_chan
    contacts_save{chan} = erase(contacts{chan},'+');
    contacts_save{chan} = replace(contacts_save{chan},'-','_');
end

%% save

save([fpath,'AlignedData_',id,'_day',num2str(day),'_',treatment,'_',date,'.mat'],'time','lfp','fs','contacts','contacts_save','id','data_teensy','block_order','n_blocks','n_chan','seqs','n_reps','day','n_keys','n_fsr','n_cap','treatment','rawdata_filename','channel_align')


end