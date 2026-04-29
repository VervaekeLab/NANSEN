function testCreateFileAdapter()
%testCreateFileAdapter Verify file adapter scaffolding.

    rootPath = tempname();
    mkdir(rootPath)
    cleanupRoot = onCleanup(@() cleanupFixture(rootPath)); %#ok<NASGU>

    info = nansen.plugin.createFileAdapter( ...
        'Name', 'Spike Table', ...
        'RootPath', rootPath, ...
        'SupportedFileTypes', {'mat'}, ...
        'DataType', 'table', ...
        'Description', 'Test scaffolded adapter');

    assert(isfolder(info.PluginFolder), ...
        'Expected plugin folder to be created')
    assert(isfile(info.SidecarPath), ...
        'Expected fileadapter.plugin.json to be created')
    assert(isfile(info.ReadFunctionPath), ...
        'Expected read.m template to be created')

    addpath(rootPath)

    registry = nansen.plugin.fileadapter.Registry();
    registry.addRootPath(rootPath);
    entry = registry.findByName('Spike Table');
    assert(strcmp(entry.AdapterId, 'fileadapter.SpikeTable'), ...
        'Expected stable adapter id from scaffolded package')
    assert(any(strcmp(entry.SupportedFileTypes, 'mat')), ...
        'Expected scaffolded adapter extension metadata')
end

function cleanupFixture(folderPath)
    if any(strcmp(strsplit(path, pathsep), folderPath))
        rmpath(folderPath)
    end

    if isfolder(folderPath)
        rmdir(folderPath, 's')
    end
end
