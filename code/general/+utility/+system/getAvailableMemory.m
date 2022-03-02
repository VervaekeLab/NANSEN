function memoryBytes = getAvailableMemory()
    if ismac
        [~,txt] = system('sysctl -a | grep hw.memsize | awk ''{print $2}'''); 
        memory_avail_gb = (eval(txt)/1024^3);
        memoryBytes = memory_avail_gb*1e9;
    elseif ispc  
        m = memory;
        memoryBytes = m.MemAvailableAllArrays;
    else
        error('not implemented')
    end
end