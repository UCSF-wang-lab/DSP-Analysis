%%%%
% teensy sensor processing and autodetection
%
% use Processed > Aligned as current folder
%
% MUST HAVE CURVE FITTING TOOLBOX TO EXECUTE THIS CODE
%%%%

% sound notification
xxx = 1:3000;
notification = 0.1*sin(.15*xxx);

% load data
disp('select ALIGNED datafile containing LFP, Teensy and time')
[filen,filep] = uigetfile('*.mat');
disp(filen)
load([filep,filen])

% indicate whether doing bilateral or unilateral for trimming and saving
if strcmp(filen(1:5),'Bilat')
    subfolder = [pwd,'/Bilateral/'];
    [left,right,data_teensy,time, delete_before, delete_after] = DataTrim_Bilateral(left,right,data_teensy,time);
    save([subfolder,'LFP_PreprocessedAndAligned_',left.id,'_day',num2str(left.day),'_',left.treatment,'_',date,'.mat'],'-struct','left')
    save([subfolder,'LFP_PreprocessedAndAligned_',right.id,'_day',num2str(right.day),'_',right.treatment,'_',date,'.mat'],'-struct','right')
    save([subfolder,'DataTrimPoints_',id,'_day',num2str(day),'_',treatment,'_',date,'.mat'],'delete_before','delete_after')
elseif strcmp(filen(1:5),'Align')
    subfolder = [pwd,'/Unilateral/'];
    [data_teensy,time,lfp,delete_before,delete_after] = DataTrim(channel_align,data_teensy,time,lfp);
    save([subfolder,'LFP_PreprocessedAndAligned_',id,'_day',num2str(day),'_',treatment,'_',date,'.mat'],'contacts_save','contacts','day','fs','id','lfp','n_chan','time','treatment')
    id = id(1:end-1);
    save([subfolder,'DataTrimPoints_',id,'_day',num2str(day),'_',treatment,'_',date,'.mat'],'delete_before','delete_after')
else
    error('Please indicate whether it is a bilateral or unilateral file for data trimming')
end
close all

subfolder_teensyplots = [subfolder,'Teensy Sensor Preprocessing/'];
% create folder for saving teensy plots
if ~isfolder(subfolder_teensyplots)
   disp([['Creating directory: '],subfolder_teensyplots])
   mkdir(subfolder_teensyplots)
end

% instantiate vars
n_time = length(time);
vars = data_teensy.Properties.VariableNames;
n_vars = length(vars);


% show prox sensors for decision on whether to ignore any
figure()
tiledlayout(n_cap,1,'TileSpacing','none')
for c = 1:n_cap
    nexttile
    plot(data_teensy.(['cap',num2str(c)]),'LineWidth',2)
    title(['Cap ',num2str(c)])
end

use_prox = input('Should any proximity sensor data be used? [y/n] ','s');
if strcmp(use_prox,'y')
    ignore_prox = input('List any specific proximity sensors that should be ignored. If none, press return.  ');
    prox_to_use = [1,2,3,4,5];
    if ~isempty(ignore_prox)
        for i = ignore_prox
            prox_to_use(prox_to_use == i) = [];
        end
    end
elseif strcmp(use_prox,'n')
    prox_to_use = [];
end
close all


% select the max capacitance value to use as cutoff when thresholding
if ~isempty(prox_to_use)
    figure()
    for pr = prox_to_use
        plot(time, data_teensy.(['cap',num2str(prox_to_use(pr))]),'LineWidth',2)
        hold on
        plot(time, data_teensy.(['key',num2str(pr)])*1000,'LineWidth',2)
    end
    max_cap = input('Please indicate the threshold capacitance value above which local mins will be ignored: ');
    close all
else
    error('must select max cap value if using proximity data')
end


% select starting point for cue detection, i.e., ignore any front/end of
% the data that for some reason didnt want to just trim off . everything
% prior to or after that will automatically be labeled block -9 and rep -9,
% and cue_state will be adjusted
figure()
plot(data_teensy.photo)
hold on
for k = 1:n_keys
    plot(data_teensy.(['key',num2str(k)]),'LineWidth',2)
end

trim = [1,n_time];
temp = input('Please indicate the indices before which photodiode switches should be ignored. If none, press return.  ');
if ~isempty(temp)
    trim(1) = temp;
end
temp = input('Please indicate the indices after which photodiode switches should be ignored. If none, press return.  ');
if ~isempty(temp)
    trim(2) = temp;
end

close all


%% handle the photodiode signal

% could prob nearly replicate what i do for prox or fsr if it becomes not
% worth it for the time saved with current photodiode code

% filter the photodiode before selecting ranges
d_photo = designfilt('lowpassfir', ...
    'PassbandFrequency',0.15,'StopbandFrequency',0.2, ...
    'PassbandRipple',1,'StopbandAttenuation',60, ...
    'DesignMethod','equiripple');
PhotoD_Filtered = filtfilt(d_photo,data_teensy.photo);

photo_movmean_smooth = round(0.2*fs); % 200ms sliding window
photo_movmean_shift = round(.1*photo_movmean_smooth);
grad_smooth = 0.2*fs; % 200ms sliding window for smoothing gradient
photo_movmean = movmean(PhotoD_Filtered,photo_movmean_smooth/2);
photo_movmean = flip(movmean(flip(photo_movmean),photo_movmean_smooth/2));
grad = gradient(photo_movmean);
grad_mean = movmean(grad,grad_smooth);
grad_mean(abs(grad_mean)<.015)=0;

% used for rcs17 stim off and grcs02 stim off
if max(photo_movmean) > 7
grad_cutoff = 0.03;
else
% used for rcs16 day 4 stim off
grad_cutoff = 0.01;
end

% his house has a lot of electrical noise so the slopes are slower
if strcmp(id,'gaitRCS04')
    grad_cutoff = 0.02;
end
% curv = gradient(grad_mean);
% curv(abs(curv)>1)=0;

% find intersections bw moving mean and filtered signal 
% depending on how long this takes, may just want to do it for small parts
% of the signal each time you're checking. 

%% select ranges for photodiode thresholding

figure()
plot(time,PhotoD_Filtered,'LineWidth',2)
hold on
plot(time,photo_movmean,'LineWidth',2)

photo_movmean_range = input('Indicate the range of cue values to use for photodiode thresholding  ');

close all

figure()
plot(time,PhotoD_Filtered,'LineWidth',2)
hold on
plot(time,photo_movmean,'LineWidth',2)
for i = 1:size(photo_movmean_range,1)
    for j = 1:size(photo_movmean_range,2)
        yline(photo_movmean_range(i,j),'LineWidth',2)
    end
end

new = input('Double check and then press enter to continue, or re-enter new values:  ');
if ~isempty(new)
    photo_movmean_range = new;
end

% just choose min and max of plot as lowest and highest point in range
% overal
% want to have boundaries that match up for all states except states 3 and
% 4. between states 3 and 4, want top of range of state 3 being pretty low
% and bottom of range of state 4 being pretty high. this is basically
% because want to capture the 2 > 3 transition at beginning of block on the
% correct side of the blip (searches for intersections in any direction). 
% and when leaving state 4, it searches for intersections only to the right 
% of leaving state 4.
close all

% % rcs14 day 1 lowoff
% cue_vals_narrow = [0,1.1;1.25,2.75;7,8];        % this is so that we only count slope=0 points, the neighbors of which are within a smaller range
% trim = [1,810043];
% cue_vals_wide = [-1,1.2;1.2,3;6.5,8.3];          % this is so that we have to check fewer


% rcs16 day 0 lowoff, DO THIS BASED ON FILTERED
% trim = [1,length(data_teensy.photo)];
% cue_vals_narrow = [-.1,0.4; 0.8,1.6; 2.4,3; 4.2,5.6 ];        % this is so that we only count slope=0 points, the neighbors of which are within a smaller range.... this should encompass what you think a reasonable range of avg values might be for some n points in the given state leading up to a switch
% cue_vals_wide = [-0.5,0.55; 0.55,2; 2,3.3; 4,6];          % this is so that we have to check fewer... switch point is allowed to fall within this range... want these boundaries of these to all be continuous with each other except between the last two, and btween the last two we want the max space we can afford

%% find intersections

[x0,y0,iout,jout]=intersections(time,PhotoD_Filtered,time,photo_movmean);

%% find switches

avg_samplesz = 0.005; % in seconds
avg_samplesz = round(avg_samplesz*fs);

% his house has a lot of electrical noise so the slopes are slower
if strcmp(id,'gaitRCS04')
    space3 = 0.08*fs;
else
    space3 = 0.08*fs; % check 80ms duration starting 80ms past current point to see if it is in different state than previous state
end
space4 = 0.08*fs;   % determine last state based on what average was 180-80 ms prior to 
space5= 0.18*fs;

% if strcmp(id,'gaitRCS04')
%     space3 = 0.12*fs;
%     space4 = 0.08*fs;
%     space5 = 0.18*fs;
% end

% find range each local min and max fall into
localmins = islocalmin(PhotoD_Filtered);
localmaxs = islocalmax(PhotoD_Filtered);
    
is = []; js = [];
cue_state = zeros(n_time,1); % this is a vector same length as time that indicates what the current light state is
cue_switch_inds = [0]; laststate = 10;

found = 0; k = 1;
    
% only search within indicated indices
for i = trim(1):trim(2)
% for i = 496760:496900
%     i
    % if we're just returning from a found point, want to skip ahead to
    % next slope instead of getting stuck on this one
    if found == 1
        % if current value outside of one of the acceptable ranges still (on same slope),
        % go to next point
        if sum(photo_movmean(i) < photo_movmean_range(:,2) & photo_movmean(i) > photo_movmean_range(:,1)) == 0  
            continue
        % there must be 70 values within acceptable range in order to change the found state and
        % start looking for another slope and switch point
        else
            k = k+1;
            if k == 70
%             if k == 70*(fs/4000)
                k = 1;
                found = 0;
            end
            continue
        end
    end

    % if current value outside of one of the acceptable ranges
    if sum(photo_movmean(i) < photo_movmean_range(:,2) & photo_movmean(i) > photo_movmean_range(:,1)) == 0  
        % only scanning vector in forward direction, so shift forward by fraction of the
        % movmean window
        z = i;
        
        % check whether it is actually on a major slope by checking whether
        % mag of gradient is larger than cutoff
        if abs(grad_mean(z)) >= grad_cutoff
            'here';
            % check whether future state is diff than recent state
            laststate = mean(photo_movmean(z-space5:z-space4));
            laststate = find(laststate < photo_movmean_range(:,2) & laststate > photo_movmean_range(:,1));
            
            nextstate = mean(photo_movmean(z+space3:z+2*space3));
            nextstate = find(nextstate < photo_movmean_range(:,2) & nextstate > photo_movmean_range(:,1));
            
            if ~isempty(laststate) && ~isempty(nextstate)

                if laststate ~= nextstate
                    'hi';
                    % if it is negative slope, find recent local max
                    if grad_mean(z) < 0
                        'yo';
                        % find relative index of the nearest intersection to the right
                        diffs = round(iout)-z;
                        diffs = diffs(diffs>=0);
                        diffs_min = min(diffs);
                        j = z+diffs_min;
                        
                        js = [js,j];
                        
                        while found == 0
                            lm_timept = j;
                            % the reason to use photod_filtered for this
                            % part instead of movmean is that i really just
                            % want to make sure that the filtered signal
                            % falls within any of the defined ranges, it
                            % doesnt need to be the actual state since
                            % using laststate to set cue_state anyway.
                            temp = mean(PhotoD_Filtered(lm_timept-avg_samplesz:lm_timept+avg_samplesz));
%                             temp = mean(photo_movmean(lm_timept-avg_samplesz-left_shift:lm_timept+avg_samplesz-left_shift));
                            lm_timept_cat = find(temp < photo_movmean_range(:,2) & temp > photo_movmean_range(:,1));
                            j = j-1;

                            if localmaxs(lm_timept) ~= 0
                                if lm_timept_cat ~= nextstate
                                    cue_state(cue_switch_inds(end)+1:lm_timept) = laststate;
                                    cue_switch_inds = [cue_switch_inds, lm_timept];
    %                                     is = [is, z];
                                    found = 1 ;
                                end
                            end
                        end
                           
                    % if it is positive slope, do local min
                    elseif grad_mean(z) > 0       
                        'hey';
                        % if in any states 1 or 2, find relative index of nearest intersection in
                        % any direction
                        if laststate == 1 || laststate == 2
                            diffs = z-round(iout);
                            diffs_min = min(abs(diffs));
                            j = find(abs(diffs) == diffs_min,1);
                            j = round(iout(j));
                            js = [js,j];
                      
                        % if in state 3, find nearest intersection to the
                        % right
                        elseif laststate == 3
                            diffs = round(iout)-z;
                            diffs = diffs(diffs>=0);
                            diffs_min = min(diffs);
                            j = z+diffs_min;

                            js = [js,j];
                        % if in state 4, this is a spurrious slope, not a
                        % state change
                        elseif laststate == 4
                            continue
                        end
                                    
                        if laststate == 1
                            while found == 0
                                lm_timept = j;
                                temp = mean(PhotoD_Filtered(lm_timept-avg_samplesz:lm_timept+avg_samplesz));
    %                             temp = mean(photo_movmean(lm_timept-avg_samplesz-left_shift:lm_timept+avg_samplesz-left_shift));
                                lm_timept_cat = find(temp < photo_movmean_range(:,2) & temp > photo_movmean_range(:,1));
                                j = j-1;

                                if localmins(lm_timept) ~= 0
                                    if lm_timept_cat ~= nextstate & lm_timept_cat == laststate
                                        cue_state(cue_switch_inds(end)+1:lm_timept) = laststate;
                                        cue_switch_inds = [cue_switch_inds, lm_timept];
        %                                 is = [is, i];
                                        found = 1;
                                        lm_timept;
                                    end
                                end
                            end
                        else
                            while found == 0
                                lm_timept = j;
                                temp = mean(PhotoD_Filtered(lm_timept-avg_samplesz:lm_timept+avg_samplesz));
    %                             temp = mean(photo_movmean(lm_timept-avg_samplesz-left_shift:lm_timept+avg_samplesz-left_shift));
                                lm_timept_cat = find(temp < photo_movmean_range(:,2) & temp > photo_movmean_range(:,1));
                                j = j-1;

                                if localmins(lm_timept) ~= 0
                                    if lm_timept_cat ~= nextstate
                                        cue_state(cue_switch_inds(end)+1:lm_timept) = laststate;
                                        cue_switch_inds = [cue_switch_inds, lm_timept];
        %                                 is = [is, i];
                                        found = 1;
                                    end
                                end
                            end
                        end
                        
                    else
                        continue                    
                    end
                    
                end
            end
        end
    end
end
            
cue_switch_inds(1) = [];
temp = zeros(n_time,1);
temp(cue_switch_inds) = 1;
data_teensy.cue_switches = temp;
data_teensy.cue_state = cue_state;

% LEAVE THIS BLANK!
manually_changed_switch_inds = [];

%% for manually inserting/deleting/moving cue switches & modifying cue state
% 
% %%%% ONLY CHANGE THIS PART
% % first mark them with brush and paste to command line so can put into these
% % vectors. Needs to be EXACT index, so zoom in all the way!
% 
% % USE COMMAS TO SEPARATE MULTIPLE VALUES
% 
% % Completely missing cue switch:    Add it using missing_switch_inds and
% % its state
% 
% % Extraneous/extra cue switch:    Delete it using wrong_timept_switch_inds
% 
% % Cue switch in correct time point but incorrect preceding state:
% % Change the state by using wrong_state_switch_inds and the correct state
% 
% % Cue switch in incorrect time point, regardless of if preceding state is
% % correct:      Delete it by adding the index to wrong_timept_switch_inds,
% % AND add the correct replacement cue switch index and its state to the
% % missing_switch_inds vectors
% 
% % Desired preceding state is what goes into the inds_state vectors
% 
% % Cue switch indices and respective preceding state for cue switches that
% % were missed
% missing_switch_inds = [];  missing_switch_inds_state = [];    
% % 
% % % same but instead of cue switches that were captured except wrong preceding state was assigned
% wrong_state_switch_inds = [];   wrong_state_switch_inds_state = [];   
% % 
% % % same but this deletes incorrect cue switches
% wrong_timept_switch_inds = [];
% % 
% % %%%%%%%%%%%
% 
% 
% % keep track for saving
% manually_changed_switch_inds = [missing_switch_inds, wrong_state_switch_inds, wrong_timept_switch_inds];
% manually_changed_switch_inds_state = [missing_switch_inds_state, wrong_state_switch_inds_state];
% 
% % delete extraneous cue_switches & remove actual state change
% delete_ind = nan(1,length(wrong_timept_switch_inds));
% for i = 1:length(wrong_timept_switch_inds)
%     delete_ind(i) = find(cue_switch_inds==wrong_timept_switch_inds(i));
%     if length(cue_switch_inds)>delete_ind(i)
%         cue_state(cue_switch_inds(delete_ind(i)-1)+1:cue_switch_inds(delete_ind(i)))= cue_state(cue_switch_inds(delete_ind(i)+1));
%     elseif length(cue_switch_inds)==delete_ind(i)
%         cue_state(cue_switch_inds(delete_ind(i)-1)+1:cue_switch_inds(delete_ind(i)))= 0;
%     end
%     cue_switch_inds(delete_ind(i)) = [];
% end
% 
% % then add missing switches to the cue_switch_inds vector
% cue_switch_inds = cat(2,cue_switch_inds, missing_switch_inds);
% cue_switch_inds = sort(cue_switch_inds);
% 
% % recompute the data_teensy vector
% temp = zeros(n_time,1);
% temp(cue_switch_inds) = 1;
% data_teensy.cue_switches = temp;
% 
% % keep track of which cue_switch it is amongst the other cue switches
% new_ind = nan(1,length(missing_switch_inds));
% for i  = 1:length(new_ind)
%     new_ind(i) = find(cue_switch_inds == missing_switch_inds(i));
% end   
% 
% change_ind = nan(1,length(wrong_state_switch_inds));
% for i  = 1:length(change_ind)
%     change_ind(i) = find(cue_switch_inds == wrong_state_switch_inds(i));
% end  
% 
% % Then update cue_state vector
% % Can't do this directly indexing with missing_switch_inds because have to
% % know how far back the state change applies which means have to know index
% % of previous cue_switch as well
% for i = 1:length(new_ind)
%     cue_state(cue_switch_inds(new_ind(i)-1)+1:cue_switch_inds(new_ind(i))) = missing_switch_inds_state(i);
% end
% 
% % adjust ones that were caught but just marked as wrong state
% for i = 1:length(change_ind)
%     cue_state(cue_switch_inds(change_ind(i)-1)+1:cue_switch_inds(change_ind(i)))= wrong_state_switch_inds_state(i);
% end
% 
% % update data_teensy.cue_state vector
% data_teensy.cue_state = cue_state;

%% check whether there is expected number of cue switches
% DOES NOT APPLY TO RCS14 OR TASKS ABORTED EARLY

cue_switch_inds = find(data_teensy.cue_switches);
n_cue_switches = sum(data_teensy.cue_switches);

% 5*2 warmup + 2*2 tutorial + 1*2 baseline + 7*n_blocks for early block
% switches + n_reps*2*n_blocks for reps + 2*(n_blocks-1) for breaks + for
% last switch after last block
n_cue_switches_expected = (8*2)+ (7*n_blocks) + (n_reps*2*n_blocks) + 2*(n_blocks-1) + 1;

if n_cue_switches ~= n_cue_switches_expected
    error('Incorrect number of state switches detected. Photodiode likely processed incorrectly.')
end


%% plot

% figure()
% plot(PhotoD_Filtered)
% hold on
% temp = 1:length(localmaxs_wide);
% scatter(temp(localmaxs_wide~=0),PhotoD_Filtered(localmaxs_wide~=0))


f1 = figure();
% title(num2str(photo_movmean_range))
plot(PhotoD_Filtered)
hold on
plot(photo_movmean)
scatter(cue_switch_inds,PhotoD_Filtered(cue_switch_inds),'LineWidth',2)
% scatter(find(localmaxs_wide),PhotoD_Filtered(logical(localmaxs_wide)),'m','LineWidth',2)
savefig(f1,[subfolder_teensyplots,'PhotoD_Filtered with cue_switch_inds_',date])
% 
% % plot to check points where it starts back searching from
% f11 = figure();
% % title(num2str(photo_movmean_range))
% plot(PhotoD_Filtered)
% hold on
% plot(photo_movmean)
% scatter(js',PhotoD_Filtered(js),'LineWidth',2)
% % 
% making sure cue_state changes overlap appropriately with cue switches
f12 = figure();
% title(num2str(photo_movmean_range))
plot(PhotoD_Filtered)
hold on
plot(photo_movmean)
scatter(cue_switch_inds,PhotoD_Filtered(cue_switch_inds),'LineWidth',2)
plot((data_teensy.cue_state-1)*4,'LineWidth',2)
savefig(f12,[subfolder_teensyplots,'PhotoD_Filtered with cue_switch_inds_andcuestate',date])

% 
% f0 = figure();
% plot(PhotoD_Filtered)
% hold on
% scatter(cue_switch_inds,PhotoD_Filtered(cue),'LineWidth',2)
% % scatter(find(localmaxs_wide),PhotoD_Filtered(logical(localmaxs_wide)),'m','LineWidth',2)
% savefig(f1,[subfolder_teensyplots'PhotoD_Filtered with cue_switch_inds_',date])

f2 = figure();
plot(data_teensy.photo)
hold on
plot(cue_state,'LineWidth',2)
savefig(f2,[subfolder_teensyplots,'Photo with cue_state_',date])

f3 = figure();
plot(data_teensy.photo)
hold on
scatter(cue_switch_inds,data_teensy.photo(cue_switch_inds),'LineWidth',2)
savefig(f3,[subfolder_teensyplots,'Photo with cue_switch_inds_',date])

x = input('Is this photodiode fine? [y/n]  ','s');
if strcmp(x,'y')
    disp('Photodiode done')
else
    error('Fix photodiode thresholding windows.')
end

% % debug plot
% temp = find(localmins);
% figure()
% plot(PhotoD_Filtered)
% hold on
% scatter(temp, PhotoD_Filtered(temp))
% hold on
% scatter(debugk, PhotoD_Filtered(debugk),'g')

%% determine block & rep of each time point & overall onset/offset times

%%%%%% information about behavioral matrix structure and number meanings
% cue_rep per warmup = [1, -9, 2, -9, 3, -9, 4, -9, 5, -9];
% cue_rep per tutorial = [-1, 1, -1, 2]
% cue_rep per baseline = [1, -9];
% cue_rep_per_block = [-9, -9, -1, -2, -1, -9, -6, temp, -7, -8, -5];
% after last block cue_rep = -9

% -9 is just like instructional slides or stuff not interested in
% -6 is the last screen used as reference for start of first trial in each
% block
% -1 is for when sequence is showing
% -2 is for when they are doing the tutorial in the experiment
% -7 is the inter trial intervals
% -8 is breaks
% -5 is the part of breaks where it counts down with an audible beep

%%%%%%%
% for rcs14 Off Stim only!!vvv
% cue_rep per warmup = [1, -9, 2, -9, 3, -9, 4, -9, 5, -9];
% cue_rep per tutorial = 
% cue_rep per baseline = [1, -9];
% cue_rep_per_block = [-9, -6, temp, -7, -8, -5];
% after last block cue_rep = -9
% ^^^^^
%%%%%%%

%%%%% columns of behavioral matrix
% response = 1; overall movement onset = 2; overall movement offset = 3,
% fsrandkey onset = 4,   fsrandkey offset = 5
% key switch onset = 6, key switch offset = 7, 
% block = 8; cue_rep = 9, rep = 10
%%%%%%%
response = 1; overall_onset = 2; overall_offset = 3;
fk_onset = 4; fk_offset = 5;
key_onset = 6; key_offset = 7; block = 8; cue_rep = 9; rep = 10;

block_num = repelem(-9,n_time)';
cue_reprep = repelem(-9,n_time)';
reprep = repelem(-9,n_time)';

% %%%%%%%%%%
% %%%% for RCS14 ONLY
% block_labels = [-3, -2, -1, 1:n_blocks, -9]; n_blocklabels = length(block_labels);
% cue_rep_labels = cell(1,n_blocklabels);
% cue_rep_labels{1} = [1, -9, 2, -9, 3, -9, 4, -9, 5];  % for warmup
% cue_rep_labels{2} = -9;         % for tutorial
% cue_rep_labels{3} = 1;                % for baseline
% temp = repelem(1:n_reps,2); temp(1:2:end) = -7;
% cue_rep_per_block = [-9, -6, temp, -7, -8];
% temp_block_order = [0, 0, 0, block_order, 0];
% temp_time = time;
% behavioral = [];
% for crl = 4:3+n_blocks
%     cue_rep_labels{crl} = cue_rep_per_block;
% end
% % cue_rep_labels{3+n_blocks} = cue_rep_per_block(1:end-2);
% cue_rep_labels{4+n_blocks} = -9;
% 
% rep_labels{1} = [1,-9,2,-9,3,-9,4,-9,5];
% rep_labels{2} = [-9];
% rep_labels{3} = [1];
% temp = repelem([1:n_reps],2);
% rep_per_block = [-9,-9,temp,n_reps+1,-9];
% for rl = 4:3+n_blocks
%     rep_labels{rl} = rep_per_block;
% end
% rep_labels{4+n_blocks} = -9;
% 
% %%%%
% %%%%%%%%%%

%%%%%%%% for everyone else after RCS14 %%%%%%
block_labels = [-3, -2, -1, 1:n_blocks, -9]; n_blocklabels = length(block_labels);
cue_rep_labels = cell(1,n_blocklabels);
cue_rep_labels{1} = [1, -9, 2, -9, 3, -9, 4, -9, 5, -9];  % for warmup
cue_rep_labels{2} = [-1, 1, -1, 2];         % for tutorial
cue_rep_labels{3} = [1, -9];                % for baseline
temp = repelem(1:n_reps,2); temp(1:2:end) = -7;
cue_rep_per_block = [-9, -1, -2, -1, -9, -6, temp, -7, -8, -5];
temp_block_order = [0, 0, 0, block_order, 0];
temp_time = time;
behavioral = [];
for crl = 4:2+n_blocks
    cue_rep_labels{crl} = cue_rep_per_block;
end
cue_rep_labels{3+n_blocks} = cue_rep_per_block(1:end-2);
cue_rep_labels{4+n_blocks} = -9;


rep_labels{1} = [1,-9,2,-9,3,-9,4,-9,5,-9];
rep_labels{2} = [1,1,2,2];
rep_labels{3} = [1,-9];
temp = repelem([1:n_reps],2);
rep_per_block = [-9,1,-9,2,-9,-9,temp,n_reps+1,-9,-9];
for rl = 4:2+n_blocks
    rep_labels{rl} = rep_per_block;
end
rep_labels{3+n_blocks} = rep_per_block(1:end-2);
rep_labels{4+n_blocks} = -9;
%%%%%%%%%%%%%%%%%%%%%%%%%


% generating cue entries to the behavioral matrix (so when is cue onset and
% offset
% also keep track of what repetition and block it is
csi = 1;
for bl = 1:n_blocklabels
    n_cuereps = length(cue_rep_labels{bl});
    block_num(cue_switch_inds(csi)+1:end) = block_labels(bl);
    
    for cr = 1:n_cuereps
         cue_reprep(cue_switch_inds(csi)+1:end) = cue_rep_labels{bl}(cr);
         reprep(cue_switch_inds(csi)+1:end) = rep_labels{bl}(cr);

         if bl == n_blocklabels
             behavioral = [behavioral; -9, time(cue_switch_inds(csi)+1), max(time), time(cue_switch_inds(csi)+1), max(time), time(cue_switch_inds(csi)+1), max(time), block_labels(bl), cue_rep_labels{bl}(cr), rep_labels{bl}(cr)];
         else
             behavioral = [behavioral; -9, time(cue_switch_inds(csi)+1), time(cue_switch_inds(csi+1)+1), time(cue_switch_inds(csi)+1), time(cue_switch_inds(csi+1)+1), time(cue_switch_inds(csi)+1), time(cue_switch_inds(csi+1)+1), block_labels(bl), cue_rep_labels{bl}(cr), rep_labels{bl}(cr)];
         end
         csi = csi+1;
    end
end
% toc
data_teensy.block = block_num; data_teensy.cue_rep = cue_reprep; data_teensy.rep = reprep;
% clear block_num cue_rep

ff1=figure();
plot(time,data_teensy.cue_state)
hold on
plot(time,block_num)
plot(time,cue_reprep)
savefig(ff1, [subfolder_teensyplots,'Cue_state vs Cuerep and Blocknum_',date])

ff2=figure();
plot(time,data_teensy.cue_state)
hold on
plot(time,data_teensy.rep)
% plot(time,data_teensy.cue_rep)
savefig(ff2,[subfolder_teensyplots,'Cue_state vs rep_',date])


x = input('Is this data structuring fine? [y/n]  ','s');
if strcmp(x,'y')
    disp('Data structuring done')
else
    error('Fix data structure.')
end



disp('Behavioral data structuring done')

close all

%% key on/offsets

key_onoffsets = cell(2,n_keys);   % second cell row contains the block and rep information
vars = data_teensy.Properties.VariableNames;
n_vars = length(vars);
for v = 1:n_vars
    % important to screen all one key before screening the next so that
    % block/rep labels vs onset/offset times dont get mixed up between keys
    if contains(vars{v},'key','IgnoreCase',true)
        key_name = vars{v};
        key = str2num(key_name(end));
        temp = data_teensy.(key_name);
        last_state = 0;
        set = [];
        
        for t = 1:n_time
            state = temp(t);
            if state == 1
                % if key just turned on
                if last_state == 0
                    % mark the onset time
                    set = time(t);
                    % mark what block/cue_rep/rep it is at the point of key
                    % onset since that's how we'll sort it based on onset
                    key_onoffsets{2,key} = [key_onoffsets{2,key}; block_num(t), cue_reprep(t), reprep(t)];
                end
            elseif state == 0
                % if key just turned off
                if last_state == 1
                    % add the offset time to the note that contains the
                    % onset time and add to the cell array
                    set = [set,time(t)];
                    key_onoffsets{1,key} = [key_onoffsets{1,key}; set];
                end
            end
            last_state = state;
        end     
    end
end

disp('Key onsets and offsets done')

%% Save intermediate in case of error or crash

save([subfolder_teensyplots,'OnsetOffsetParamsAndVars_',id,'_day',num2str(day),'_',treatment,'_',date,'.mat'])


%% deal with proximity sensors

%%%%%%% this section is just for troubleshooting for a given patient before
%%%%%%% filtering all of it to save time
% % shift = 1087000;
% shift = 1109400;
% % shift = 2395401;
% tic
% smoothing_factor = 0.99999999;
% % temp = fit(time(1004000:1044000),data_teensy.cap2(1004000:1044000),'smoothingspline','SmoothingParam',smoothing_factor);
% cap2_filtered_coeff = fit(time(1+shift:shift+.001*n_time),data_teensy.cap2(1+shift:shift+.001*n_time),'smoothingspline','SmoothingParam',smoothing_factor);
% cap2_filtered = cap2_filtered_coeff(time(1+shift:shift+.001*n_time));
% toc
% 
% figure()
% % plot(time(1:10000),data_teensy.cap2(1:10000))
% % hold on
% plot(time(1+shift:shift+.001*n_time),data_teensy.cap2(1+shift:shift+.001*n_time),'LineWidth',3)
% hold on
% plot(time(1+shift:shift+.001*n_time),cap2_filtered,'LineWidth',3)
% % plot(time(1+shift:shift+.001*n_time),islocalmin(cap2_filtered),'LineWidth',3)
%%%%%%% 

% only want to do this if there is proximity sensor data at all

% first smooth the data
window_size = 8000;
window_size_lastrun = mod(n_time,window_size);
if window_size_lastrun ~= 0
    n_runs = floor(n_time/window_size)+1;
else
    n_runs = n_time/window_size;
end
% smoothing_factor = 0.999999;
smoothing_factor_cap = 0.99999999;
% i=1;
filtered_cap = nan(n_time,n_cap);

% this is just to fit a polynomial to the data in small windows so that it
% doesn't take too long or crash
if ~isempty(prox_to_use)
    for v = 1:n_vars
        if contains(vars{v},'cap','IgnoreCase',true)
            cap_name = vars{v};
            cap_num = str2num(vars{v}(end));
            
            if sum(prox_to_use == cap_num) ~= 0
                tic
            
                shift = 0;
                    for run = 1:n_runs
                        if run == n_runs
                            filtered_coeff = fit(time(1+shift:shift+window_size_lastrun),data_teensy.(cap_name)(1+shift:shift+window_size_lastrun),'smoothingspline','SmoothingParam',smoothing_factor_cap);
                            filtered_cap(1+shift:shift+window_size_lastrun,cap_num) = filtered_coeff(time(1+shift:shift+window_size_lastrun));
                            shift = shift+window_size_lastrun;
                        else
                            filtered_coeff = fit(time(1+shift:shift+window_size),data_teensy.(cap_name)(1+shift:shift+window_size),'smoothingspline','SmoothingParam',smoothing_factor_cap);
                            filtered_cap(1+shift:shift+window_size,cap_num) = filtered_coeff(time(1+shift:shift+window_size));
                            shift = shift+window_size;
                        end
                    end        
                disp([cap_name,' filtering complete'])
                toc
            end
        end
    end

end


%% thresholding

local_mins_cap = nan(n_time,n_cap);
for cap = 1:n_cap
    local_mins_cap(:,cap) = islocalmin(filtered_cap(:,cap)); % anything coded as nan bc it isn't supposed to be used will just be made into a zero
end

% any local main above the stated threshold will be ignored
for cap = 1:n_cap
    crossings = data_teensy.(['cap',num2str(cap)]) >= max_cap;
    local_mins_cap(crossings,cap) = 0;
end

% jsut screen really big jumps
jump_size = 100;
% for offset, if it is still decreasing after the current local min, the current
% local min is not the min we're looking for
future_check_offset_cap = 0.1; % how far ahead to check, in seconds     % 0.05 and 0.005 on not filtered cap
halfwidth_avgingwindow_cap = .005; % how wide of a window to avg when looking ahead, in seconds    % was .04 last using with onset

future_check_offset_cap = round(future_check_offset_cap*fs);
halfwidth_avgingwindow_cap = round(halfwidth_avgingwindow_cap*fs);
for cap = 1:n_cap
    if sum(prox_to_use == cap) ~= 0
        tic
        for t = 1:n_time
           if local_mins_cap(t,cap) == 1
               if t+halfwidth_avgingwindow_cap+future_check_offset_cap > n_time
                   break
               elseif t-(halfwidth_avgingwindow_cap+future_check_offset_cap)<1
                   continue
               end
               curr_val = mean(filtered_cap((t-halfwidth_avgingwindow_cap:t+halfwidth_avgingwindow_cap),cap));
               future_val = mean(filtered_cap((t-halfwidth_avgingwindow_cap+future_check_offset_cap:t+halfwidth_avgingwindow_cap+future_check_offset_cap),cap));
               if (curr_val-future_val) >= jump_size
                   local_mins_cap(t,cap) = 0;
               end
           end
        end
        disp(['cap',num2str(cap),' scan 1 complete.'])
        toc
    end
end

% for onset, flip the vector, repeat what did for offset, and then flip back
future_check_onset_cap = 0.1; % how far ahead to check, in seconds
future_check_onset_cap = round(future_check_onset_cap*fs);

local_mins_cap = flip(local_mins_cap);
for cap = 1:n_cap
    if sum(prox_to_use == cap) ~= 0
        tic
        flipped_capog = flip(filtered_cap(:,cap));
    %     data_teensy.(['cap',num2str(cap)]));
        for t = 1:n_time
           if local_mins_cap(t,cap) == 1
               if t+halfwidth_avgingwindow_cap+future_check_onset_cap > n_time
                   break
               elseif t-(halfwidth_avgingwindow_cap+future_check_onset_cap)<1
                   continue
               end
               curr_val = mean(flipped_capog(t-halfwidth_avgingwindow_cap:t+halfwidth_avgingwindow_cap));
               future_val = mean(flipped_capog(t-halfwidth_avgingwindow_cap+future_check_onset_cap:t+halfwidth_avgingwindow_cap+future_check_onset_cap));
               if (curr_val-future_val) >= jump_size
                   local_mins_cap(t,cap) = 0;
               end
           end
        end
        disp(['cap',num2str(cap),' scan 2 complete.'])
        toc
    end
end

local_mins_cap = flip(local_mins_cap);


% % take advantage of the filter artifact: any time it goes below zero just
% % mark it for consideration. do this AFTER doing the sweep above
% % local_mins_cap(filtered_cap < 0) = 1;

% 
% %%%%%% this section is just for troubleshooting for a given patient before
% %%%%%% filtering all of it to save time
% cap=2; cap_num=cap;cap_name = ['cap',num2str(cap_num)];
% figure()
% plot(time, (data_teensy.(cap_name)),'LineWidth',3)
% hold on
% plot(time, (filtered_cap(:,cap_num)),'LineWidth',3)
% plot(time, data_teensy.(['key',num2str(cap)])*4000,'LineWidth',3)
% scatter(time(logical(local_mins_cap(:,cap))),(data_teensy.(cap_name)(logical(local_mins_cap(:,cap)))),200,'m','LineWidth',3)

% plot(time, (data_teensy.(cap_name)-750)/7,'LineWidth',3)
% hold on
% plot(time, (filtered_cap(:,cap_num)-750)/7,'LineWidth',3)
% plot(time, data_teensy.(['key',num2str(cap)])*400,'LineWidth',3)
% scatter(time(logical(local_mins_cap(:,cap))),(data_teensy.(cap_name)(logical(local_mins_cap(:,cap)))-750)/7,200,'c','LineWidth',3)


% scatter(time(logical(saving_local_mins_cap(:,cap))),(data_teensy.(cap_name)(logical(saving_local_mins_cap(:,cap)))-750)/7,200,'c','LineWidth',3)
%%%%%%% this section is just for troubleshooting for a given patient before
%%%%%%% filtering all of it to save time
% toc
% xlim([652,654])
% xlim([269,273])

% sound(notification)

disp('Proximity sensors done')

%% Save intermediate in case of error or crash

save([subfolder_teensyplots,'OnsetOffsetParamsAndVars_',id,'_day',num2str(day),'_',treatment,'_',date,'.mat'])

%% deal with fsrs

% %%%%%%% this section is just for troubleshooting for a given patient before
% %%%%%%% filtering all of it to save time
% shift = 1087000;
% shift = 1109400;
% shift = 399*fs;  % 400 sec shift
% tic
% smoothing_factor = 0.999999;
% % temp = fit(time(1004000:1044000),data_teensy.cap2(1004000:1044000),'smoothingspline','SmoothingParam',smoothing_factor);
% fsr2_filtered_coeff = fit(time(1+shift:shift+.01*n_time),data_teensy.fsr2(1+shift:shift+.01*n_time),'smoothingspline','SmoothingParam',smoothing_factor);
% fsr2_filtered = fsr2_filtered_coeff(time(1+shift:shift+.01*n_time));
% toc
% 
% figure()
% % plot(time(1:10000),data_teensy.cap2(1:10000))
% % hold on
% plot(time(1+shift:shift+.01*n_time),data_teensy.fsr2(1+shift:shift+.01*n_time),'LineWidth',3)
% hold on
% plot(time(1+shift:shift+.01*n_time),400*data_teensy.key2(1+shift:shift+.01*n_time),'LineWidth',3)
% plot(time(1+shift:shift+.01*n_time),fsr2_filtered,'LineWidth',3)
% 
% % plot(time(1+shift:shift+.001*n_time),islocalmin(cap2_filtered),'LineWidth',3)
%%%%%%%%%%

% first smooth the data
window_size = 8000;
window_size_lastrun = mod(n_time,window_size);
if window_size_lastrun ~= 0
    n_runs = floor(n_time/window_size)+1;
else
    n_runs = n_time/window_size;
end
smoothing_factor = 0.999999;
filtered_fsr = nan(n_time,n_fsr);

for v = 1:n_vars
    if contains(vars{v},'fsr','IgnoreCase',true)
        tic
        fsr_name = vars{v};
        fsr_num = str2num(vars{v}(end));
        shift = 0;
            for run = 1:n_runs
                if run == n_runs
                    filtered_coeff = fit(time(1+shift:shift+window_size_lastrun),data_teensy.(fsr_name)(1+shift:shift+window_size_lastrun),'smoothingspline','SmoothingParam',smoothing_factor);
                    filtered_fsr(1+shift:shift+window_size_lastrun,fsr_num) = filtered_coeff(time(1+shift:shift+window_size_lastrun));
                    shift = shift+window_size_lastrun;
                else
                    filtered_coeff = fit(time(1+shift:shift+window_size),data_teensy.(fsr_name)(1+shift:shift+window_size),'smoothingspline','SmoothingParam',smoothing_factor);
                    filtered_fsr(1+shift:shift+window_size,fsr_num) = filtered_coeff(time(1+shift:shift+window_size));
                    shift = shift+window_size;
                end
            end        
        
        disp([fsr_name,' filtering complete.'])
        toc
    end
end



%% then threshold

% then find the local minima
local_mins_fsr = nan(n_time,n_fsr);
for fsr = 1:n_fsr
    local_mins_fsr(:,fsr) = islocalmin(filtered_fsr(:,fsr));
end

%%%%%%% this section is just for troubleshooting for a given patient before
%%%%%%% filtering all of it to save time
% figure()
% plot(time(1:size(filtered_fsr,1)), data_teensy.(fsr_name)(1:size(filtered_fsr,1)),'LineWidth',3)
% hold on
% plot(time(1:size(filtered_fsr,1)), filtered_fsr(:,fsr_num),'LineWidth',3)
% plot(time(1:size(filtered_fsr,1)), data_teensy.key2(1:size(filtered_fsr,1))*4000,'LineWidth',3)
% scatter(time(logical(local_mins_fsr(:,fsr))),data_teensy.fsr2(logical(local_mins_fsr(:,fsr))),200,'m','LineWidth',3)
%%%%%%%%

% optimize these for actual reps, not for warmup or verifications. just going to use key
% switches when looking at warmup so that i dont have to deal with
% filtering and thresholding it differently since warmup and verification is always a lot
% faster of a rate of typing

% every time fsr is zero, it is a local min. doing this before screening
% since sometimes it bounces around zero at end
for fsr = 1:n_fsr
    local_mins_fsr(data_teensy.(['fsr',num2str(fsr)])<=0,fsr) = 1;
end

grad_fsr = gradient(filtered_fsr')';


if contains(id,'RCS20','IgnoreCase',true) || contains(id,'RCS17','IgnoreCase',true)
    % for offset, if it is still decreasing after the current local min, the current
    % local min is not the min we're looking for
    future_check_offset = 0.1; % how far ahead to check, in seconds     % was 0.1 and 0.005
    % future_check_offset2 = 0.4; % a second check for stuff further ahead, but it has to be much lower at that point
    halfwidth_avgingwindow = .02; % how wide of a window to avg when looking ahead, in seconds

    % for onset, flip the vector, repeat what did for offset, and then flip back
    future_check_onset = 0.05; % how far ahead to check, in seconds    % was 0.04
    future_check_onset = future_check_onset*fs;
    grad_factor_fsr = 0.5;
    zero_cutoff = 10;
    diff_cutoff = 50;
    

    future_check_offset = round(future_check_offset*fs);
    halfwidth_avgingwindow = round(halfwidth_avgingwindow*fs);
    for fsr = 1:n_fsr
    % for fsr = 2:5
        tic
        for t = 1:n_time
    %     for t = 410977: 974752
           if local_mins_fsr(t,fsr) == 1
               if t+halfwidth_avgingwindow+future_check_offset > n_time
                   continue
               elseif t-(halfwidth_avgingwindow+future_check_offset)<1
                   continue
               end

               % if the current value at this point equals zero, then it might be the true
               % offset, but the vals behind it will be positive so we don't
               % want to include those in the average, but we do want to
               % include values in front of it in the avg in case it's a case
               % where it goes to zero for just a second
               point_val = data_teensy.(['fsr',num2str(fsr)])(t);
               if point_val == 0
                   curr_val = mean(data_teensy.(['fsr',num2str(fsr)])(t:t+2*halfwidth_avgingwindow));
               else
                   curr_val = mean(data_teensy.(['fsr',num2str(fsr)])(t-halfwidth_avgingwindow:t+halfwidth_avgingwindow));
               end
               future_val = mean(data_teensy.(['fsr',num2str(fsr)])(t-halfwidth_avgingwindow+future_check_offset:t+halfwidth_avgingwindow+future_check_offset));
    %            time(t)
    %             (curr_val-future_val)
    %            mean(grad_fsr(t-2*halfwidth_avgingwindow:t,key))
    %            mean(grad_fsr(t-2*halfwidth_avgingwindow+future_check_offset:t+future_check_offset,key))
    %            if ((future_val < curr_val) && (abs(mean(grad_fsr(t-2*halfwidth_avgingwindow+future_check_offset:t+future_check_offset,key))) >= abs(grad_factor_fsr*mean(grad_fsr(t-2*halfwidth_avgingwindow:t,key)))) || ((future_val < curr_val) && (mean(filtered_fsr(t-2*halfwidth_avgingwindow+future_check_offset:t+future_check_offset,key)) <= zero_cutoff))) || ((curr_val-future_val) > diff_cutoff)
               if ((curr_val-future_val) > diff_cutoff) || ((future_val < zero_cutoff) && (curr_val > zero_cutoff))
                    local_mins_fsr(t,fsr) = 0;
               end
           end
        end
        disp(['fsr',num2str(fsr),' scan 1 complete.'])
        toc
    end



    local_mins_fsr = flip(local_mins_fsr);
    for fsr = 1:n_fsr
    % for fsr = 2:5
        tic
        flipped_fsrog = flip(data_teensy.(['fsr',num2str(fsr)]));
        for t = 1:n_time
    %     for t = 410977: 974752
           if local_mins_fsr(t,fsr) == 1
               if t+halfwidth_avgingwindow+future_check_offset > n_time
                   continue
               elseif t-(halfwidth_avgingwindow+future_check_offset)<1
                   continue
               end

               point_val = data_teensy.(['fsr',num2str(fsr)])(t);
               if point_val == 0
                   curr_val = mean(flipped_fsrog(t:t+2*halfwidth_avgingwindow));
               else
                   curr_val = mean(flipped_fsrog(t-halfwidth_avgingwindow:t+halfwidth_avgingwindow));
               end
               future_val = mean(flipped_fsrog(t-halfwidth_avgingwindow+future_check_onset:t+halfwidth_avgingwindow+future_check_onset));
                if ((curr_val-future_val) > diff_cutoff) || ((future_val < zero_cutoff) && (curr_val > zero_cutoff))
                    local_mins_fsr(t,fsr) = 0;
               end
           end
        end
        disp(['fsr',num2str(fsr),' scan 2 complete.'])
        toc
    end

else
    % for offset, if it is still decreasing after the current local min, the current
    % local min is not the min we're looking for
    future_check_offset = 0.1; % how far ahead to check, in seconds     % was 0.1 and 0.005
    % future_check_offset2 = 0.4; % a second check for stuff further ahead, but it has to be much lower at that point
    halfwidth_avgingwindow = .005; % how wide of a window to avg when looking ahead, in seconds

    future_check_offset = round(future_check_offset*fs);
    halfwidth_avgingwindow = round(halfwidth_avgingwindow*fs);
    for fsr = 1:n_fsr
        tic
        for t = 1:n_time
           if local_mins_fsr(t,fsr) == 1
               if t+halfwidth_avgingwindow+future_check_offset > n_time
                   continue
               elseif t-(halfwidth_avgingwindow+future_check_offset)<1
                   continue
               end

               % if the current value at this point equals zero, then it might be the true
               % offset, but the vals behind it will be positive so we don't
               % want to include those in the average, but we do want to
               % include values in front of it in the avg in case it's a case
               % where it goes to zero for just a second
               point_val = data_teensy.(['fsr',num2str(fsr)])(t);
               if point_val == 0
                   curr_val = mean(data_teensy.(['fsr',num2str(fsr)])(t:t+2*halfwidth_avgingwindow));
               else
                   curr_val = mean(data_teensy.(['fsr',num2str(fsr)])(t-halfwidth_avgingwindow:t+halfwidth_avgingwindow));
               end
               future_val = mean(data_teensy.(['fsr',num2str(fsr)])(t-halfwidth_avgingwindow+future_check_offset:t+halfwidth_avgingwindow+future_check_offset));
               if future_val < curr_val
                   local_mins_fsr(t,fsr) = 0;
               end
           end
        end
        disp(['fsr',num2str(fsr),' scan 1 complete.'])
        toc
    end

    % for onset, flip the vector, repeat what did for offset, and then flip back
    future_check_onset = 0.04; % how far ahead to check, in seconds    % was 0.04
    future_check_onset = future_check_onset*fs;

    local_mins_fsr = flip(local_mins_fsr);
    for fsr = 1:n_fsr
        tic
        flipped_fsrog = flip(data_teensy.(['fsr',num2str(fsr)]));
        for t = 1:n_time
           if local_mins_fsr(t,fsr) == 1
               if t+halfwidth_avgingwindow+future_check_offset > n_time
                   continue
               elseif t-(halfwidth_avgingwindow+future_check_offset)<1
                   continue
               end

               point_val = data_teensy.(['fsr',num2str(fsr)])(t);
               if point_val == 0
                   curr_val = mean(flipped_fsrog(t:t+2*halfwidth_avgingwindow));
               else
                   curr_val = mean(flipped_fsrog(t-halfwidth_avgingwindow:t+halfwidth_avgingwindow));
               end
               future_val = mean(flipped_fsrog(t-halfwidth_avgingwindow+future_check_onset:t+halfwidth_avgingwindow+future_check_onset));
               if future_val < curr_val
                   local_mins_fsr(t,fsr) = 0;
               end
           end
        end
        disp(['fsr',num2str(fsr),' scan 2 complete.'])
        toc
    end

    
end


local_mins_fsr = flip(local_mins_fsr);

% take advantage of the filter artifact: any time it goes below zero just
% mark it for consideration. do this AFTER doing the sweep above
local_mins_fsr(filtered_fsr < 0) = 1;

%%%%%% this section is just for troubleshooting for a given patient before
%%%%%% filtering all of it to save time
% fsr=2; fsr_num=2;fsr_name = 'fsr2';
% figure()
% plot(time, data_teensy.(fsr_name),'LineWidth',3)
% hold on
% plot(time, filtered_fsr(:,fsr_num),'LineWidth',3)
% plot(time, data_teensy.key2*400,'LineWidth',3)
% scatter(time(logical(local_mins_fsr(:,fsr))),data_teensy.fsr2(logical(local_mins_fsr(:,fsr))),200,'m','LineWidth',3)
% scatter(time(logical(local_mins_old(:,fsr))),data_teensy.fsr2(logical(local_mins_old(:,fsr))),200,'c','LineWidth',3)
%%%%%% this section is just for troubleshooting for a given patient before
%%%%%% filtering all of it to save time

disp('FSRs done')

%% Save intermediate in case of error or crash

save([subfolder_teensyplots,'OnsetOffsetParamsAndVars_',id,'_day',num2str(day),'_',treatment,'_',date,'.mat'])

%% overall on/offsets
% constrain to only the fsr and cap onset/offset times in closest proximity
% to the corresponding key switch and its actuation

if contains(id,'RCS20','IgnoreCase',true) || contains(id,'RCS17','IgnoreCase',true)
    cap_leadingfsr_max = 0.1; cap_trailingfsr_max = 0.1;
    fsr_leadingkey_max = 0.25; fsr_trailingkey_max = 0.25;    
else
    cap_leadingfsr_max = 0.3; cap_trailingfsr_max = 0.3;
    fsr_leadingkey_max = 0.3; fsr_trailingkey_max = 0.3;
end

max_moveshift_onset = cap_leadingfsr_max + fsr_leadingkey_max; max_moveshift_offset = cap_trailingfsr_max + fsr_trailingkey_max;
for key = 1:n_keys
    n_keypresses = size(key_onoffsets{1,key},1);
    for kp = 1:n_keypresses
        % for each keypress, find the closest leading onset for both fsr
        % and cap
        keypress_onset = key_onoffsets{1,key}(kp,1);
        keypress_offset = key_onoffsets{1,key}(kp,2);
               
        possible_fsronsets = time(logical(local_mins_fsr(:,key)));
        possible_fsronsets = possible_fsronsets(possible_fsronsets <= keypress_onset);
        [fsr_on_diff,fsr_on_ind] = min(keypress_onset-possible_fsronsets);
        
        % for just the fsr/key onset (in case decide dont want to use prox
        % sensors or dont have them for a patient)
        if fsr_on_diff <= fsr_leadingkey_max
           fsrk_onset = possible_fsronsets(fsr_on_ind);
%                    'bloop'
        elseif fsr_on_diff > fsr_leadingkey_max
           fsrk_onset = keypress_onset; 
%                    'blap'
        end
        
        % for overall onset
        possible_caponsets = time(logical(local_mins_cap(:,key)));
        if ~isempty(possible_caponsets)
        possible_caponsets = possible_caponsets(possible_caponsets <= keypress_onset);
            if ~isempty(possible_caponsets)
    %             possible_caponsets = possible_caponsets(possible_caponsets <= keypress_onset);
                [cap_on_diff,cap_on_ind] = min(keypress_onset-possible_caponsets);

                capvsfsr_diff = fsrk_onset - possible_caponsets(cap_on_ind);    

                % if cap is leading fsr
                if capvsfsr_diff >= 0
                    % use cap as long as cap is less than x past fsr & is within
                    % max_moveshift onset
                   if (capvsfsr_diff <= cap_leadingfsr_max) && (cap_on_diff <= max_moveshift_onset)
                       move_onset = possible_caponsets(cap_on_ind);
        %                'bleep'
                    % if cap more than x past fsr or outside max_moveshift onset, use
                    % fsr
                   elseif (capvsfsr_diff > cap_leadingfsr_max) || (cap_on_diff > max_moveshift_onset)
                        % if trying to use fsr and fsr is more than fsr_leadingkey_max past key onset, use
                        % key onset
                        if fsr_on_diff <= fsr_leadingkey_max
                           move_onset = fsrk_onset;
        %                    'bloop'
                        elseif fsr_on_diff > fsr_leadingkey_max
                           move_onset = keypress_onset; 
        %                    'blap'
                        end
                   else
                       error('something wrong')
                   end
               % if cap trailing fsr
                elseif capvsfsr_diff < 0
                    if fsr_on_diff <= fsr_leadingkey_max
                       move_onset = fsrk_onset;
        %                'hi'
                    elseif fsr_on_diff > fsr_leadingkey_max
                       move_onset = keypress_onset; 
        %                'hello'
                    end
                else
                    error('uh oh')
                end
            else % if cap is high the whole time at start of file and there is no eligible cap onset, use fsr or key onset
                if fsr_on_diff <= fsr_leadingkey_max
                   move_onset = fsrk_onset;
    %                'hi'
                elseif fsr_on_diff > fsr_leadingkey_max
                   move_onset = keypress_onset; 
    %                'hello'
                end
            end
        end
    

        
        % offset
        possible_fsroffsets = time(logical(local_mins_fsr(:,key)));
        possible_fsroffsets = possible_fsroffsets(possible_fsroffsets >= keypress_offset);
        [fsr_off_diff,fsr_off_ind] = min(possible_fsroffsets-keypress_offset);
        
        % for just the fsr/key offset (in case decide dont want to use prox
        % sensors or dont have them for a patient)
        if fsr_off_diff <= fsr_trailingkey_max
           fsrk_offset = possible_fsroffsets(fsr_off_ind);
%                'leep'
        elseif fsr_off_diff > fsr_trailingkey_max
           fsrk_offset = keypress_offset; 
%                'looot'
        end
        
        possible_capoffsets = time(logical(local_mins_cap(:,key)));
        if ~isempty(possible_capoffsets)
        possible_capoffsets = possible_capoffsets(possible_capoffsets >= keypress_offset);
        if ~isempty(possible_capoffsets)
        
%             possible_capoffsets = possible_capoffsets(possible_capoffsets >= keypress_offset);
           
            [cap_off_diff,cap_off_ind] = min(possible_capoffsets-keypress_offset);
        
%             capvsfsr_diff = cap_off_diff - fsr_off_diff;
            capvsfsr_diff = possible_capoffsets(cap_off_ind) - fsrk_offset;



            % if cap is trailing fsr
            if capvsfsr_diff >= 0
                % use cap as long as cap is less than x past fsr & is within
                % max_moveshift onset
               if (capvsfsr_diff <= cap_trailingfsr_max) && (cap_off_diff <= max_moveshift_offset)
                   move_offset = possible_capoffsets(cap_off_ind);
    %                'meep'
                % if cap more than x past fsr or outside max_moveshift onset, use
                % fsr
               elseif (capvsfsr_diff > cap_trailingfsr_max) || (cap_off_diff > max_moveshift_offset)
                    % if trying to use fsr and fsr is more than fsr_trailingkey_max past key onset, use
                    % key onset
                    if fsr_off_diff <= fsr_trailingkey_max
                       move_offset = fsrk_offset;
    %                    'mop'
                    elseif fsr_off_diff > fsr_trailingkey_max
                       move_offset = keypress_offset; 
    %                    'mooooop'
                    end
               else
                   error('something wrong')
               end
           % if cap leading fsr
            else
                if fsr_off_diff <= fsr_trailingkey_max
                   move_offset = fsrk_offset;
    %                'leep'
                elseif fsr_off_diff > fsr_trailingkey_max
                   move_offset = keypress_offset; 
    %                'looot'
                end
            end
        else % if cap is high the whole time until end of file and there is no eligible cap onset, use fsr or key offset
            if fsr_off_diff <= fsr_trailingkey_max
               move_offset = fsrk_offset;
            elseif fsr_off_diff > fsr_trailingkey_max
               move_offset = keypress_offset; 
            end
        end
        end
        
        if ~isnan(move_onset)
            if (keypress_onset - move_onset > max_moveshift_onset)
                error('Something is definitely wrong with onset or offset time detection')
            end
        end
        if ~isnan(move_offset)
            if (move_offset - keypress_offset > max_moveshift_offset)
                error('Something is definitely wrong with onset or offset time detection')
            end
        end
                
        % if any of the movements of a given digit have shared onsets,
        % give the onset to the key that actuates first/closest to the
        % onset, and default the other to keyswitch onset
        % it should work to just index the most recent addition to the
        % behavioral matrix since we're adding by key and doing in keypress
        % order
        % loops by key so this is fine
        if behavioral(end,response) == key  % dont want to accidentally compare last keypress of previous key to first keypress of current key
            if fsrk_onset == behavioral(end,fk_onset)
                fsrk_onset = keypress_onset;
            end
            if ~isnan(move_onset)
                if move_onset == behavioral(end,overall_onset)
                    % if fsr is also same.. it shouldn't be because of our last
                    % check but check again anyway whatever
                    if fsrk_onset == behavioral(end,fk_onset)
                        % use key for both fsr and overall
                        move_onset = keypress_onset;
                        fsrk_onset = keypress_onset;
                    % if fsr is not same
                    elseif fsrk_onset ~= behavioral(end,fk_onset)
                        % use current fsr for overall
                        move_onset = fsrk_onset;
                    end
                end
            end

            % if any of the movements of a given digit have shared offsets 
            % give the offset to the key switch actuates last/closest to
            % the offset, and default the other to keyswitch offset
            if fsrk_offset == behavioral(end,fk_offset)
                behavioral(end,fk_offset) = behavioral(end,key_offset);
            end
            if ~isnan(move_offset)
                if move_offset == behavioral(end,overall_offset)
                    % if fsr is also shared
                    if fsrk_offset == behavioral(end,fk_offset)
                        behavioral(end,fk_offset) = behavioral(end,key_offset);
                        behavioral(end,overall_offset) = behavioral(end,key_offset);
                    % if fsr is not also shared, use fsr
                    elseif fsrk_offset ~= behavioral(end,fk_offset)
                        behavioral(end,overall_offset) = behavioral(end,fk_offset);
                    end
                end
            end

            % if current onset overlaps with previous offset, find the midpoint time
            % point bw the keyswitch offset/onset and use that
            % check this for the fsr and check it for the overall and change
            % either, neither or both
            if fsrk_onset < behavioral(end,fk_offset)
                prev_keyoff = behavioral(end,key_offset);
                curr_keyon = key_onoffsets{1,key}(kp,1);
                midpoint = (prev_keyoff+curr_keyon)/2;

                % closest point in time vector to determined midpoint
                [mm,ii] = min(abs(time-midpoint));
                newt = time(ii);
                fsrk_onset = newt;
                behavioral(end,fk_offset) = newt;
            end
            % actually just default them to the force value for overall
            if move_onset < behavioral(end,overall_offset)
                prev_keyoff = behavioral(end,fk_offset);
                curr_keyon = fsrk_onset;
                
                move_onset = curr_keyon;
                behavioral(end, overall_offset) = prev_keyoff;

            end
        end
        
        if isnan(move_onset) || isnan(move_offset)
            error('There has been an issue with onset/offset time processing')
        end
        
        % save the set inc the subsequent offset
        % maybe also save a data matrix that has just the keyswitch actuations too in
        % case for some reason I decide I want to use that for behavioral and use
        % the fsr/cap for other stuff
        behavioral = [behavioral; key, move_onset, move_offset, fsrk_onset, fsrk_offset, key_onoffsets{1,key}(kp,:), key_onoffsets{2,key}(kp,:)];

        if abs(fsrk_offset-move_offset) > cap_leadingfsr_max
            error('issue')
        end
        
    end
end
    
% sort data matrix by KEY SWITCH onset clock column so that there isn't
% stuff shoved before the corresponding cue unless it's actually fully pressed
% during the ITI
behavioral = sortrows(behavioral, key_onset);

% some sanity checks
for b = 1:n_blocks
    block_data = behavioral(:,block) == b;
    block_data = behavioral(block_data,:);
    
    
    block_reps = max(block_data(:,cue_rep));    % doing this so that it doesn't break if they didn't complete all the reps in the last block or something
    for cr = 1:block_reps
        trial_data = block_data(block_data(:,cue_rep)==cr,:);
        presses = find(trial_data(:,response) ~= -9);
        
        % if the onset of current movement after cue x+1 takes place before the end of the prior
        % cue x, default to the fsr onset value and if not that one then to the key switch onset value for the current movement
        %only do if not the first cue
        if cr ~= 1
             % find onset of first keypress
            first_onset_overall = trial_data(presses(1),overall_onset);
            
            if ~isnan(first_onset_overall)
                first_onset_fsrkey = trial_data(presses(1),fk_onset);

                % find end of prior cue x-1
                temp = block_data(block_data(:,cue_rep) == cr-1,:);
                last_cue_offset = temp((temp(:,response) == -9),overall_offset);

                if first_onset_overall < last_cue_offset
                        temp = (behavioral(:,block) == b) & (behavioral(:,cue_rep) == cr);
                        temp = temp & (behavioral(:,response) ~= -9);
                        temp = find(temp,1);  % need index wrt entire matrix

                    % both overall onset and fsr onset are before prior
                    % cue, change both to key onset
                    if first_onset_fsrkey <= last_cue_offset
                        behavioral(temp,overall_onset) = behavioral(temp,key_onset);
                        behavioral(temp,fk_onset) = behavioral(temp,key_onset);
                    % if only overall onset is before prior cue, only
                    % change that to fsr onset, not changing fsr onset
                    else
                        behavioral(temp,overall_onset) = behavioral(temp,fk_onset);
                    end
                end
            end
        end
        
        % if any of the trials has a keyswitch onset that seems to begin
        % prior to the cue onset, check this manually
        cue_onset = trial_data(trial_data(:,response) == -9, overall_onset);
        if trial_data(presses(1),key_onset) < cue_onset
            error('one of the trials seems to have a keyswitch onset that starts before the cue onset')
        end
    end
end



disp('All onset and offset calculations done')

%%
to_plot = (1:n_keys)';
ff5=figure();
% tl = tiledlayout(n_keys,1); 
tl = tiledlayout(length(to_plot),1); 
i=1;
axs = [];
for key = to_plot'
% for key = 1:n_keys
    nexttile;
%     eval(['ax',num2str(key)]) = nexttile;
    plot(time,data_teensy.(['key',num2str(key)])*400,'Color','r','DisplayName','Key Switch','LineWidth',2)
    hold on
    plot(time,data_teensy.(['fsr',num2str(key)]),'Color',[0.8500 0.3250 0.0980],'DisplayName','FSR','LineWidth',2)
    plot(time,(data_teensy.(['cap',num2str(key)])/2),'Color',[0.4940 0.1840 0.5560],'DisplayName','Cap','LineWidth',2)
%     plot(time,(filtered_cap(:,key)-750)/7,'Color','k','DisplayName','Filtered Cap')
    % plot(time,(filtered_cap-750)/7,'Color',[0.4940 0.1840 0.3560])
%     plot(time,(filtered_fsr(:,key)),'Color','k','DisplayName','Filtered FSR')
    resp = behavioral(:,1) == key;
    ons = behavioral(resp,overall_onset); offs = behavioral(resp,overall_offset);
    ons_fsrkey_only = behavioral(resp,fk_onset); offs_fsrkey_only = behavioral(resp,fk_offset);
    scatter(ons,repelem(400,length(ons)),200,'m','DisplayName','Onset- including cap','LineWidth',2)
    scatter(offs,repelem(400,length(offs)),200,'c','DisplayName','Offset- including cap','LineWidth',2)
    scatter(ons_fsrkey_only,repelem(300,length(ons_fsrkey_only)),200,'b','DisplayName','Onset- no cap','LineWidth',2)
    scatter(offs_fsrkey_only,repelem(300,length(offs_fsrkey_only)),200,'g','DisplayName','Offset- no cap','LineWidth',2)
%     scatter(time(logical(local_mins_fsr(:,key))), repelem(150,sum(local_mins_fsr(:,key))), 200, 'r','DisplayName','FSR mins','LineWidth',2)
%     scatter(time(logical(local_mins_cap(:,key))), repelem(100,sum(local_mins_cap(:,key))), 200, 'k','DisplayName','Cap mins','LineWidth',2)
    title(['Key ',num2str(key)])
    if i == 1
        legend()
    end
    i = i+1;
    axs = [axs,gca];
end
tl.TileSpacing = 'none';
linkaxes(axs,'xy')

% fig1 = gcf;
savefig(ff5,[subfolder_teensyplots,'OnsetOffset_',date])




ff6=figure();
tl2 = tiledlayout(length(to_plot),1); 
i=1;
axs2 = [];
for key = to_plot'
% for key = 1:n_keys
    nexttile;
%     eval(['ax',num2str(key)]) = nexttile;
    plot(time,data_teensy.(['key',num2str(key)])*400,'Color','r','DisplayName','Key Switch','LineWidth',2)
    hold on
    plot(time,filtered_fsr(:,key),'Color',[0.8500 0.3250 0.0980],'DisplayName','Filtered FSR','LineWidth',2)
    plot(time,filtered_cap(:,key)/2,'Color',[0.4940 0.1840 0.5560],'DisplayName','Filtered Cap','LineWidth',2)
    resp = behavioral(:,1) == key;
    ons = behavioral(resp,overall_onset); offs = behavioral(resp,overall_offset);
    ons_fsrkey_only = behavioral(resp,fk_onset); offs_fsrkey_only = behavioral(resp,fk_offset);
    scatter(ons,repelem(400,length(ons)),200,'m','DisplayName','Onset- including cap','LineWidth',2)
    scatter(offs,repelem(400,length(offs)),200,'c','DisplayName','Offset- including cap','LineWidth',2)
    scatter(ons_fsrkey_only,repelem(300,length(ons_fsrkey_only)),200,'b','DisplayName','Onset- no cap','LineWidth',2)
    scatter(offs_fsrkey_only,repelem(300,length(offs_fsrkey_only)),200,'g','DisplayName','Offset- no cap','LineWidth',2)
    scatter(time(logical(local_mins_fsr(:,key))), repelem(150,sum(local_mins_fsr(:,key))), 200, 'r','DisplayName','FSR mins','LineWidth',2)
    scatter(time(logical(local_mins_cap(:,key))), repelem(100,sum(local_mins_cap(:,key))), 200, 'k','DisplayName','Cap mins','LineWidth',2)
    title(['Key ',num2str(key)])
    if i == 1
        legend()
    end
    i = i+1;
    axs2 = [axs2,gca];
end
tl2.TileSpacing = 'none';
linkaxes(axs2,'xy')

savefig(ff6,[subfolder_teensyplots,'Filtered_OnsetOffset_',date])














close all

%% change format of behavioral matrix to table
behavioral = array2table(behavioral,'VariableNames',{'response','overall_onset','overall_offset','fk_onset','fk_offset','key_onset','key_offset','block','cue_rep','rep'});


%% save the parameters used for onset time thresholding in case need to regenerate for some reason and the filtered FSR & Cap since they take a while to generate

% save(['OnsetOffsetParamsAndVars_',id,'_day',num2str(day),'_',treatment,'_',date,'.mat'],'data_teensy','cue_vals_narrow','cue_vals_wide','avg_samplesz','trim','space','space2','space3','space4','space5','smoothing_factor','window_size','filtered_cap','max_cap','future_check_onset_cap','future_check_offset_cap','halfwidth_avgingwindow_cap','filtered_fsr','future_check_offset','halfwidth_avgingwindow','future_check_onset','startpoint','stoppoint','cap_leadingfsr_max','cap_trailingfsr_max','fsr_leadingkey_max','fsr_trailingkey_max','max_moveshift_onset','max_moveshift_offset','fk_onset','fk_offset','local_mins_fsr','local_mins_cap','key_onoffsets','n_keys','n_cap','n_fsr','n_time','rawdata_filename','smoothing_factor_cap','jump_size');
save([subfolder_teensyplots,'OnsetOffsetParamsAndVars_',id,'_day',num2str(day),'_',treatment,'_',date,'.mat'])

%% save processed data as mat and csv file. csv file is specifically for the alignment gui
% 
% save([date,'_UnalignedPreprocessedTeensy_',rawdata_filename,'.mat'],'data_teensy')
% writetable(data_teensy,[date,'_UnalignedPreprocessedTeensy_',rawdata_filename,'.csv'])


save([subfolder,'Teensy_PreprocessedAndAligned_',id,'_day',num2str(day),'_',treatment,'_',date,'.mat'],'time','id','data_teensy','fs','block_order','n_blocks','seqs','n_reps','day','treatment','behavioral','response', 'overall_onset', 'overall_offset','key_onset', 'key_offset','fk_onset','fk_offset', 'block', 'cue_rep','rep','prox_to_use')

% end
%%
sound(notification)