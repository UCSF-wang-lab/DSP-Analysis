%%%%
% initial RCS processing
%
% ENTIRE PIPELINE IS DONE WITH MATLAB 2020b
%
% will need Curve Fitting Toolbox
%
% use Processed > RCS as current folder
%
% Always clear workspace before starting any preprocessing
%
% Rename session folder with _TASK on end once determine which one is task
% file
%%%%

function Preprocess1of11_ExtractRCS(taskday_condition)

ProcessRCS();
% ProcessRCS('',1,1);

% Select file
[fileName,pathName] = uigetfile('AllDataTables.mat');

% Load file
disp('Loading selected .mat file')
load([pathName fileName])

% Create unified table with selected data streams -- use timeDomain data as
% time base
dataStreams = {timeDomainData, AccelData, PowerData, FFTData, AdaptiveData};
[combinedDataTable] = createCombinedTable(dataStreams,unifiedDerivedTimes,metaData);

f_name = [metaData.subjectID,'_',taskday_condition,'_',date,'OpenMind'];

save(f_name)

n_chan = 4;

for chan = 1:n_chan
    time_plot = combinedDataTable.localTime;
    lfp_plot = eval(['combinedDataTable.TD_key',num2str(chan-1)]);
    nan_ignore = ~isnan(lfp_plot);
    
    fig = figure(chan);
    plot(time_plot(nan_ignore),lfp_plot(nan_ignore))
    ttl=strjoin({metaData.subjectID,taskday_condition,eval(['timeDomainSettings.chan',num2str(chan),'{1}'])},' ');
    title(ttl)
    savefig(fig,ttl)
    saveas(fig, [eval(['timeDomainSettings.chan',num2str(chan),'{1}']),' ',metaData.subjectID,'.png'])  
end

% if there is accelerometry data, plot and save it
vars = combinedDataTable.Properties.VariableNames;
n_vars = length(vars);

for v = 1:n_vars
    if strcmp(vars{v},'Accel_XSamples')
        f5 = figure(5);
        ttl=strjoin({metaData.subjectID,taskday_condition,'Accelerometry'},' ');
        t=tiledlayout(3,1);
        title(t,ttl)
        nexttile;
        scatter(combinedDataTable.localTime,combinedDataTable.Accel_XSamples,3);
        title('X Accel')
        ax1=gca;
        nexttile;
        scatter(combinedDataTable.localTime,combinedDataTable.Accel_YSamples,3);
        title('Y Accel')
        ax2 = gca;
        nexttile;
        scatter(combinedDataTable.localTime,combinedDataTable.Accel_ZSamples,3);
        title('Z Accel')
        ax3=gca;
        linkaxes([ax1,ax2,ax3],'x')
        savefig(f5,ttl)
        saveas(f5, [ttl,'.png'])
    end
end

end