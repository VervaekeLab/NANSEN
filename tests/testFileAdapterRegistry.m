function testFileAdapterRegistry()
%testFileAdapterRegistry Verify file adapter registry discovery and lookup.

    registry = nansen.dataio.FileAdapterRegistry.getInstance(true);
    adapterList = registry.list();

    assert(~isempty(adapterList), ...
        'Expected file adapter registry to contain entries')

    adapterNames = {adapterList.FileAdapterName};
    assert(any(strcmp(adapterNames, 'Default')), ...
        'Expected Default file adapter entry')
    assert(any(strcmp(adapterNames, 'ImageStack')), ...
        'Expected ImageStack file adapter entry')

    imageStackEntry = registry.findByName('ImageStack');
    assert(strcmp(imageStackEntry.FunctionName, ...
        'nansen.dataio.fileadapter.imagestack.ImageStack'), ...
        'ImageStack adapter resolved to unexpected class')
    assert(strcmp(imageStackEntry.AdapterId, imageStackEntry.FunctionName), ...
        'Expected adapter id to use the fully qualified class name')

    tifAdapters = registry.findByFileType('.tif');
    tifAdapterNames = {tifAdapters.FileAdapterName};
    assert(any(strcmp(tifAdapterNames, 'ImageStack')), ...
        'Expected ImageStack to support tif files')

    filteredAdapters = nansen.config.varmodel.VariableModel.listFileAdapters('tif');
    filteredAdapterNames = {filteredAdapters.FileAdapterName};
    assert(any(strcmp(filteredAdapterNames, 'ImageStack')), ...
        'Expected VariableModel tif filtering to include ImageStack')

    fixtureRoot = fullfile(fileparts(mfilename('fullpath')), 'fixtures');
    if ~any(strcmp(strsplit(path, pathsep), fixtureRoot))
        addpath(fixtureRoot)
        cleanupFixturePath = onCleanup(@() rmpath(fixtureRoot)); %#ok<NASGU>
    end

    fixtureRegistry = nansen.plugin.fileadapter.Registry();
    fixtureRegistry.addRootPath(fixtureRoot);
    fixtureAdapters = fixtureRegistry.listLegacy();
    fixtureNames = {fixtureAdapters.FileAdapterName};
    assert(any(strcmp(fixtureNames, 'PatientsTable')), ...
        'Expected sidecar-defined PatientsTable adapter')

    tmpFile = [tempname(), '.mat'];
    cleanupObj = onCleanup(@() deleteIfExists(tmpFile));
    Age = [1; 2; 3]; %#ok<NASGU>
    Name = {'a'; 'b'; 'c'}; %#ok<NASGU>
    save(tmpFile, 'Age', 'Name')

    adapter = fixtureRegistry.createAdapter('PatientsTable', tmpFile);
    data = adapter.load();
    assert(istable(data), 'Expected function adapter to return a table')
    assert(isequal(data.Age, [1; 2; 3]), ...
        'Function adapter returned unexpected data')

end

function deleteIfExists(filePath)
    if isfile(filePath)
        delete(filePath)
    end
end
