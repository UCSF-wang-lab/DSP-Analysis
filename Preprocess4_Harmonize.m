%%%%%
% CLEAR WORKSPACE FIRST
%
% loop through harmonizing many files
%
% can be used to harmonize a single file too
%
% current folder does not matter
%
% MAKE SURE ALL FOLDERS OF INTEREST (like where data is located) are added
% to path
%%%%%

function Preprocess4of11_Harmonize(n_files)

filenames = cell(1,n_files);
paths = cell(1,n_files);

% first make an array of the file paths by having user select all files
for f = 1:n_files
    % select file that contains teensy data, lfp data and their alignment
    % points to harmonize. should be output of Preprocess3of5 called
    % AlignmentPointsWorkspace
    fprintf('\n')
    disp(['Select AlignmentPointsWorkspace file: ',num2str(f)])
    [filenames{f},paths{f}] = uigetfile('*.mat');
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

% Harmonize each file
for f = 1:n_files
    fprintf('\n')
    disp('\\\\\\\\\\\\\\\\\\')
    fprintf('\n')
    disp(['Starting file: ',filenames{f}])
    
    Harmonize(filenames{f},paths{f})
   
   disp(['File ',num2str(f),' of ',num2str(n_files),' harmonization complete!'])
   fprintf('\n')
end

fprintf('\n')
disp('DONE HARMONIZING ALL FILES')

end