%fileType should be char vector that says which type of file to select

function [filenames,paths]=FileSelector(n_files,fileType,file_extension,multiselect_mode)
filenames = cell(1,n_files);
paths = cell(1,n_files);


switch multiselect_mode
    case 'on'
        fprintf('\n')
        disp(['Select ALL ',fileType,' files'])
        [filenames,paths] = uigetfile(file_extension,'MultiSelect',multiselect_mode);

    case 'off'
        % first make an array of the file paths by having user select all files
        for f = 1:n_files
            % select file that contains teensy data, lfp data and their alignment
            % points to harmonize. should be output of Preprocess3of5 called
            % AlignmentPointsWorkspace
            fprintf('\n')
            disp(['Select ',fileType,' file: ',num2str(f)])
            [filenames{f},paths{f}] = uigetfile(file_extension,'MultiSelect',multiselect_mode);
        end    
end




% display the file names and have user confirm before starting
fprintf('\n')
fprintf('\n')
fprintf('\n')
disp('\\\\\\\\\\\\\\\\\\')
fprintf('\n')
for f = 1:n_files
    disp(filenames{f})
    fprintf('\n')
end
disp('\\\\\\\\\\\\\\\\\\')
fprintf('\n')

abort = input('confirm that these are the correct files [0/1]: ');
if isempty(abort) || abort ~= 1
    error('restart function to re-do file selection process')
end
end