function table = ConvertDSPtxt(filename)
    opts = detectImportOptions(filename);
    opts = setvartype(opts,'double');

    table = readtable(filename,opts);

%     fileID = fopen(filename);
%     table = fscanf(fileID, '%d');
end

