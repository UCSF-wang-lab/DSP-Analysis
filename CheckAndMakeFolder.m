function CheckAndMakeFolder(subfolder)

if ~isfolder(subfolder)
   disp([['Creating directory: '],subfolder])
   mkdir(subfolder)
end

end