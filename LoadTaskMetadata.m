function [block_order,n_blocks,seqs,n_reps] = LoadTaskMetadata(full_path)

% loads relevant matlab task metadata for preprocessing teensy data
% 
% inputs
% full_path = full path to the file, including the filename itself
%
% outputs
% block_order = order of sequences occurring across blocks
% n_blocks
% seqs = the sequences being used
% n_reps = total number of repetitions/trials per block

fid = fopen(full_path);
line = fgetl(fid);
while line ~= -1
    if contains(line,'block_seq')
        block_order = [str2num(strtrim(line(strfind(line,'=')+1:end)))];
        n_blocks = max(size(block_order));
    elseif contains(line,'key_sequence')
        seqs = [str2num(strtrim(line(strfind(line,'=')+1:end)))]';
    elseif contains(line,'trials_per_block')
        n_reps = str2num(strtrim(line(strfind(line,'=')+1:end)));
    end
    line = fgetl(fid);
end
fclose(fid);

end