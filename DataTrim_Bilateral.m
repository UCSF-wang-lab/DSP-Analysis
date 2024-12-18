%%%%%
% helper function that trims excess data and adjusts time stamps
%%%%%

function [left,right,data_teensy,time, delete_before, delete_after] = DataTrim_Bilateral(left,right,data_teensy,time)

% TRIM EXCESS DATA SO THAT DONT HAVE ANNOYING CUE STATE BLEH AT BEGINNING AND END & adjust behavioral matrix timestamps

% get rid of any remaining excess data
% plot to select points
figure()
tiledlayout(3,1)
ax1 = nexttile;
plot(left.lfp(:,left.channel_align))
title('left channel align')
ax2 = nexttile;
plot(right.lfp(:,right.channel_align))
title('right channel align')
ax3 = nexttile;
plot(data_teensy.photo)
hold on
plot(data_teensy.key1*5,'LineWidth',2)
plot(data_teensy.key2*5,'LineWidth',2)
plot(data_teensy.key3*5,'LineWidth',2)
plot(data_teensy.key4*5,'LineWidth',2)
plot(data_teensy.key4*5,'LineWidth',2)
linkaxes([ax1,ax2,ax3],'x')
delete_before = input('Select index before which to delete. It is fine to leave empty, just press return.:  ');
delete_after = input('Select index after which to delete. It is fine to leave empty, just press return.:   ');
close all

if ~isempty(delete_after)
    time(delete_after:end) = [];
    
    left.lfp(delete_after:end,:) = [];
    left.time(delete_after:end) = [];
    
    right.lfp(delete_after:end,:) = [];
    right.time(delete_after:end) = [];
    
    data_teensy(delete_after:end,:) = [];
end
if ~isempty(delete_before)
    time(1:delete_before) = [];
    time = time-time(1);
    
    
    left.lfp(1:delete_before,:) = [];    
    left.time(1:delete_before) = [];
    left.time = left.time-left.time(1);
    
    right.lfp(1:delete_before,:) = [];
    right.time(1:delete_before) = [];
    right.time = right.time-right.time(1);
    
    
    data_teensy(1:delete_before,:) = [];
end


end