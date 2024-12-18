function matrix = ConvertMatlabAsd(filename)
    a = fopen(filename);
    matrix = fread(a,[5,inf],'double');
    fclose(a);
end