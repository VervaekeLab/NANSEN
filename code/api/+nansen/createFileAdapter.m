function createFileAdapter(options)

    arguments
        options.?nansen.plugin.fileadapter.FileAdapterMeta
    end

    nvPairs = namedargs2cell(options);
    nansen.plugin.createFileAdapter(nvPairs{:});
end
