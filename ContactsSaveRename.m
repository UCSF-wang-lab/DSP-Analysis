% contacts should be cell array


function contacts_save = ContactsSaveRename(contacts)
    n_chan = length(contacts);
    contacts_save = cell(n_chan,1);
    for chan = 1:n_chan
        contacts_save{chan} = erase(contacts{chan},'+');
        contacts_save{chan} = replace(contacts_save{chan},'-','_');
    end
end