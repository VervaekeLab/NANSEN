function results = createFileAdapter(options)

    arguments
        options.?nansen.dataio.fileadapter.FileAdapterMeta
    end

    nvPairs = namedargs2cell(options);
    results = nansen.plugin.fileadapter.createFileAdapter(nvPairs{:});
end
