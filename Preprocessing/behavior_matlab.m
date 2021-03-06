response = 1; clock = 2; block = 3; rep = 4; seq = 5;
seqs = [2 4 1 2; 2 1 4 2];
n_elements = 4;
% 
% data = struct();
% data.response = data_matlab(:,1);
% data.time = data_matlab(:,2);
% data.block = data_matlab(:,3);
% data.rep = data_matlab(:,4);
% data.seq = data_matlab(:,5);

n_blocks = max(data_matlab(:,3));
n_reps = max(data_matlab(:,4));
n_seq = max(data_matlab(:,5));

% n_blocks = max(data.block);
% n_reps = max(data.rep);
% n_seq = max(data.seq);

respT = nan(n_blocks,n_reps);
ITI = nan(n_blocks,n_reps,n_elements-1);
block_order = nan(1,n_blocks);

% determine block order, inter tap interval and response time to cue within each block
for b = 1:n_blocks 
    b_data = data(:,block)== b;    
    b_data = find(b_data);
    b_data = data(b_data,:);
    block_order(b) = b_data(2,seq);
    
    for r = 1:n_reps
        r_data = b_data(:,rep)==r;
        r_data = find(r_data);
        r_data = b_data(r_data,:);
        
        % response to cue
        respT(b,r) = r_data(2,clock)-r_data(1,clock);
        
        % ITIs
        temp = r_data(2:end,clock);
        ITI(b,r,:) = diff(temp);
        
    end

end
    
% average across the repetitions within the block
resp_block = mean(respT, 2);
ITI_block = mean(ITI,[2 3]);
ITI_block_var = var(ITI, 0, [2 3]);

% plot
f1 = figure(1);
plot(1:(n_blocks/2),resp_block(block_order==1),'DisplayName','Sequence 1','Color','b');
hold on
plot(1:(n_blocks/2),resp_block(block_order==2),'DisplayName','Sequence 2','Color','r');
xlabel('Block')
ylabel('Mean Response Time to Cue (s)')
ax = gca;
ax.YLim = [0.15 0.65];
ax.FontSize = 18;
legend()

f2 = figure(2);
plot(1:(n_blocks/2),ITI_block(block_order==1),'DisplayName','Sequence 1','Color','b');
hold on
plot(1:(n_blocks/2),ITI_block(block_order==2),'DisplayName','Sequence 2','Color','r');
xlabel('Block')
ylabel('Mean ITI (s)')
ax = gca;
ax.XLim = [1 8];
ax.YLim = [0.05 0.2];
ax.FontSize = 18;
legend()

f3 = figure(3);
plot(1:(n_blocks/2),ITI_block_var(block_order==1),'DisplayName','Sequence 1','Color','b');
hold on
plot(1:(n_blocks/2),ITI_block_var(block_order==2),'DisplayName','Sequence 2','Color','r');
xlabel('Block')
ylabel('Var(ITI) (s)')
ax = gca;
ax.XLim = [1 8];
% ax.YLim = [0.05 0.2];
ax.FontSize = 18;
legend()



