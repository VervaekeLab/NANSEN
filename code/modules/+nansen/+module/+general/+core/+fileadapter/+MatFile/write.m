function write(filePath, data)
    if isstruct(data)
        save(filePath, '-struct', 'data');
    else
        save(filePath, 'data');
    end
end
