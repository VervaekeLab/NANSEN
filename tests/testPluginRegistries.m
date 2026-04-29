function testPluginRegistries()
%testPluginRegistries Verify unified registry facade for core plugin types.

    fixtureRoot = fullfile(fileparts(mfilename('fullpath')), 'fixtures');
    if ~any(strcmp(strsplit(path, pathsep), fixtureRoot))
        addpath(fixtureRoot)
        cleanupFixturePath = onCleanup(@() rmpath(fixtureRoot)); %#ok<NASGU>
    end

    actionRegistry = nansen.plugin.action.Registry();
    actionRegistry.addRootPath(fixtureRoot);
    actionSpecs = actionRegistry.list();
    actionIds = {actionSpecs.Id};
    assert(any(strcmp(actionIds, 'nansen_plugin_fixture.action.hello')), ...
        'Expected sidecar-defined action plugin')

    action = actionRegistry.get('nansen_plugin_fixture.action.hello');
    action = nansen.plugin.action.ActionSpec.fromPluginSpec(action);
    assert(strcmp(action.EntityType, 'session'), ...
        'Expected action entity type to be session')
    assert(strcmp(action.MethodName, 'Hello Session'), ...
        'Expected action method name from sidecar')

    actionRegistry.disable('nansen_plugin_fixture.action.hello')
    cleanupActionState = onCleanup( ...
        @() actionRegistry.enable('nansen_plugin_fixture.action.hello')); %#ok<NASGU>
    assert(~actionRegistry.isEnabled('nansen_plugin_fixture.action.hello'), ...
        'Expected disabled action state to be persisted')
    assert(~any(strcmp({actionRegistry.list().Id}, ...
        'nansen_plugin_fixture.action.hello')), ...
        'Expected disabled action to be hidden from normal listing')
    assert(any(strcmp({actionRegistry.list('IncludeDisabled', true).Id}, ...
        'nansen_plugin_fixture.action.hello')), ...
        'Expected disabled action to be visible when requested')

    tableVariableRegistry = nansen.plugin.tablevariable.Registry();
    tableVariableRegistry.addRootPath(fixtureRoot);
    names = tableVariableRegistry.listVariableNames('session');
    assert(any(strcmp(names, 'SessionLabel')), ...
        'Expected sidecar-defined table variable plugin')

    attrs = tableVariableRegistry.listAttributes('session');
    attrNames = {attrs.Name};
    assert(any(strcmp(attrNames, 'SessionLabel')), ...
        'Expected table variable attributes for fixture plugin')

    facadeSpecs = nansen.plugin.Registry.list('action');
    assert(isa(facadeSpecs, 'nansen.plugin.action.ActionSpec'), ...
        'Expected facade to return action specs')

end
