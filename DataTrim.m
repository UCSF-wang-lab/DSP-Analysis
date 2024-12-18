%%%%%
% helper function that trims excess data and adjusts time stamps
%
% returns trimmed data and also trimmed time points
%%%%%

function [data_teensy,time,lfp, delete_before, delete_after] = DataTrim(channel_align,data_teensy,time,lfp)

% TRIM EXCESS DATA SO THAT DONT HAVE ANNOYING CUE STATE BLEH AT BEGINNING AND END & adjust behavioral matrix timestamps

% get rid of any remaining excess data
% plot to select points
figure()
tiledlayout(2,1)
ax1 = nexttile;
plot(lfp(:,channel_align))
ax2 = nexttile;
plot(data_teensy.photo)
hold on
plot(data_teensy.key1*5,'LineWidth',2)
plot(data_teensy.key2*5,'LineWidth',2)
plot(data_teensy.key3*5,'LineWidth',2)
plot(data_teensy.key4*5,'LineWidth',2)
plot(data_teensy.key4*5,'LineWidth',2)
linkaxes([ax1,ax2],'x')
delete_before = input('Select index before which to delete. It is fine to leave empty, just press return.:  ');
delete_after = input('Select index after which to delete. It is fine to leave empty, just press return.:   ');
close all

if ~isempty(delete_after)
    time(delete_after:end) = [];
    lfp(delete_after:end,:) = [];
    data_teensy(delete_after:end,:) = [];
end
if ~isempty(delete_before)
    time(1:delete_before) = [];
    time = time-time(1);
    lfp(1:delete_before,:) = [];
    data_teensy(1:delete_before,:) = [];
end


end