function data_processed = PreprocessDSP(rawdata_filename,Fs)
% Preprocesses raw teensy data and spits out data structure with things
% divided into blocks and cue times etc
% Fs is in Hz

% need to write up something to deal with time stamps and dropped packets
% because dropped packets will lead the plotted raw data to be misleading
% how to deal with discontinuities... so that all of data isn't just
% shifted by 10ms if we lose 10ms worth of data one time

% for today just focus on extracting the intertap intervals per block. can
% deal with reaction times and onset time later if i have time
% want figures showing: (1) data from full task against time, (2) data from
% one repetition against time, (3) inter tap intervals per block

% col numbers corresponding to keys in txt file
keys = [13 14 15 16 17];

% import raw teensy data as table
data_raw = ConvertDSPtxt(rawdata_filename);

data_raw = movevars(data_raw, 'EEG', 'Before', 'FSR1');
data_raw = movevars(data_raw, 'PhotoD', 'Before', 'FSR1');
data_raw = movevars(data_raw, 'Cap1', 'Before', 'FSR1');
data_raw = movevars(data_raw, 'Cap2', 'Before', 'FSR1');
data_raw = movevars(data_raw, 'Cap3', 'Before', 'FSR1');
data_raw = movevars(data_raw, 'Cap4', 'Before', 'FSR1');
data_raw = movevars(data_raw, 'Cap5', 'Before', 'FSR1');

% total raw plot
PlotAllTeensy(data_raw)
ax = gca;
ax.FontSize = 24;
ax.YTicks = [];
ax.XLimits = [2000 649011]


% deal with timestamps (TEMP (and V BAD) SOLUTION)
timestamps_micros = data_raw.ElapsedMicros;
timestamps_micros = timestamps_micros-timestamps_micros(1);
% tottime = double(max(timestamps_micros));
tottime =  double(1328020000);
tottime = (tottime/1000000);

sample_dur = 1/Fs;
time = (0:sample_dur:tottime)';

% data missing between indices 427594 and 427594 of timestamps vector, but elapsed micros is
% 5691 despite only 1 extra value in time vector compared to
% timestamps_micros. going to change it so that i round up instead
% 1.328019701000000e+03,       1.328018000000000e+03
% insert a row of nans where missing values are
new_tsm = ([timestamps_micros(1:427594)' 855188000 855190000 timestamps_micros(427595:end)'])';
new_ts = double(new_tsm)/1000000;
figure(1)
plot(time-new_ts)

% insert nans into table at appropriate place
% data_processed = double(data_raw);

vartypes = {'int64','int64','int64','int64','int64','int64','int64','int64','int64','int64','int64','int64','int64','int64','int64','int64','int64','int64','int64','int64'};
temp = table('Size',[2 20],'VariableTypes',vartypes,'VariableNames',{'EEG','PhotoD','Cap1','Cap2','Cap3','Cap4','Cap5','FSR1','FSR2','FSR3','FSR4','FSR5','Key1','Key2','Key3','Key4','Key5','ElapsedMicros','Ticks','RTC'});
for col = 1:size(temp,2)
    temp.(col) = [nan;nan];
end
data_processed = [data_raw(1:427594,:); temp; data_raw(427595:end,:)];

% shift keypress times by debounce duration
for key = keys
    temp = data_processed.(key);
    temp = temp(3:end);
    temp = [temp; [nan;nan]];
    data_processed.(key) = temp;
end

% plot shifted data
PlotAllTeensy(data_processed)

temp = array2table(time/60,'VariableNames',{'Time'});
data_processed = [data_processed, temp];

temp = array2table(time,'VariableNames',{'Time'});
data_processed = [data_processed, temp];

% plot only relevant sensors
% figure()
% s = stackedplot(data_processed,{'PhotoD','Cap1','Cap3','Cap4','Cap5','FSR1','FSR3','FSR4','FSR5','Key1','Key3','Key4','Key5'},'XVariable','Time');
% s.FontSize = 14;
% s.XLimits = [0, 21.7];
% s.LineProperties(1).Color = 'k';
% s.LineProperties(6).Color = 'magenta';
% s.LineProperties(7).Color = 'magenta';
% s.LineProperties(8).Color = 'magenta';
% s.LineProperties(9).Color = 'magenta';
% s.LineProperties(10).Color = 'green';
% s.LineProperties(11).Color = 'green';
% s.LineProperties(12).Color = 'green';
% s.LineProperties(13).Color = 'green';

figure()
s = stackedplot(data_processed,{'PhotoD','Cap1', 'FSR1','Key1','Cap3','FSR3','Key3','Cap5','FSR5','Key5'},'XVariable','Time');
s.FontSize = 14;
s.XLimits = [0, 21.7];
s.LineProperties(1).Color = 'k';
s.LineProperties(2).Color = 'magenta';
s.LineProperties(3).Color = 'magenta';
s.LineProperties(4).Color = 'magenta';
s.LineProperties(5).Color = 'g';
s.LineProperties(6).Color = 'g';
s.LineProperties(7).Color = 'g';
s.LineProperties(8).Color = 'b';
s.LineProperties(9).Color = 'b';
s.LineProperties(10).Color = 'b';


% plot of a single trial (also do a plot with them directly overlayed
s.XLimits = [6.505 8.52];

xlims = [428.9 429.8];
lw = 2;

figure(4)
tlo = tiledlayout(4,1,'TileSpacing','none','Padding','none');
nexttile, plot(time,data_processed.PhotoD,'DisplayName','Cue','Linestyle','-','LineWidth',1,'Color','k')
ax = gca;
legend()
ax.XLim = xlims;
ax.FontSize = 18;
ax.XTick = [];
ax.YTick = [];

nexttile, plot(time,data_processed.FSR1,'DisplayName','Force','Linestyle','-','LineWidth',lw,'Color',[0 0.4470 0.7410]);
hold on
plot(time,data_processed.Cap1,'DisplayName','Capacitance','Linestyle','-','LineWidth',lw,'Color',[0.4660 0.6740 0.1880]);
ax = gca;
ax.YLim = [0 2500];
ax.YTick = [];
yyaxis right
plot(time,data_processed.Key1,'DisplayName','Key Switch','Linestyle','-','LineWidth',lw,'Color',[0.6350 0.0780 0.1840]);
ax = gca;
ax.YLim = [0 2];
% ax.FontSize = 18;
ax.XLim = xlims;
ax.XTick = [];
ax.YTick = [];

nexttile, plot(time,data_processed.FSR3,'DisplayName','Force','Linestyle','-','LineWidth',lw,'Color',[0 0.4470 0.7410]);
hold on
plot(time,data_processed.Cap3,'DisplayName','Capacitance','Linestyle','-','LineWidth',lw,'Color',[0.4660 0.6740 0.1880]);
ax = gca;
ax.YLim = [0 2500];
ax.YTick = [];
yyaxis right
plot(time,data_processed.Key3,'DisplayName','Key Switch','Linestyle','-','LineWidth',lw,'Color',[0.6350 0.0780 0.1840]);
ax = gca;
ax.YLim = [0 2];
% ax.FontSize = 18;
ax.XLim = xlims;
ax.XTick = [];
ax.YTick = [];

nexttile, plot(time,data_processed.FSR5,'DisplayName','Force','Linestyle','-','LineWidth',lw,'Color',[0 0.4470 0.7410]);
hold on
plot(time,data_processed.Cap5,'DisplayName','Capacitance','Linestyle','-','LineWidth',lw,'Color',[0.4660 0.6740 0.1880]);
ax = gca;
ax.YLim = [0 2500];
ax.YTick = [];
yyaxis right
plot(time,data_processed.Key5,'DisplayName','Key Switch','Linestyle','-','LineWidth',lw,'Color',[0.6350 0.0780 0.1840]);
ax = gca;
ax.YLim = [0 2];
ax.XLim = xlims;
ax.YTick = [];
ax.FontSize = 18;

% set(tlo.Children,'XTick',[], 'YTick', []); % all in one

% ticks in seconds
% ax.XTick = 1:length(time);
ax.XTick = 1:0.1:length(time);
xlabel('Time (s)')
legend()


figure()
a = plot(time,data_processed.FSR1,'DisplayName','Force','Linestyle','-','LineWidth',1,'Color',[0 0.4470 0.7410]);
ax1 = gca;
hold on
b = plot(time, data_processed.Cap1,'DisplayName','Capacitance','LineStyle','-','LineWidth',1,'Color',[0.4660 0.6740 0.1880]);

xlabel('Time (s)')
ax1.XTickLabel(time)

ax1.XLim = [375.1 375.45];
ax1.YLim = [0 2750];

yyaxis right
c = plot(time, data_processed.Key1,'Displayname','Key Siwtch','Linestyle','-','LineWidth',1,'Color',[0.6350 0.0780 0.1840]);
ax2 = gca;
ax2.YLim = [0 2];
ax2.YTick = [0 1];
ylabel('Actuation');

legend()


% inter tap intervals
actuations = [];
% actuation_times = 
for key = keys
    temp = diff(data_processed.(key));
    temp = temp==1;
    temp = [0; temp];
    actuations = [actuations temp];
end
    




% filter streams that need to be filtered


% determine cue on/off times


% determine start and end of each block
% for now, just use the number of sequence repetitions per block to divide
% things up, but later will want to know precise timing of breaks and time
% between when sequence is shown and first cue is presented etc.


% format data into output for analysis
