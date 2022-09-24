function memoryBytes = getAvailableMemory()
    if ismac
        [~,txt] = system('sysctl -a | grep hw.memsize | awk ''{print $2}'''); 
        memory_avail_gb = (eval(txt)/1024^3);
        memoryBytes = memory_avail_gb*1e9;
    elseif ispc  
        m = memory;
        memoryBytes = m.MemAvailableAllArrays;
    elseif isunix % better way?
        [~,txt] = system('free -m'); 
        txtItems = strsplit(txt, ' ');
        memory_avail_mb = txtItems{8};
        memoryBytes = str2double(memory_avail_mb)*1e6;
    else
        error('not implemented')
    end
end