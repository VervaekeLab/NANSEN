function testPluginDiagnose()
%testPluginDiagnose Verify plugin diagnosis command.

    report = nansen.plugin.diagnose('fileadapter');
    assert(isstruct(report), 'Expected diagnosis report to be a struct array')
    assert(all(isfield(report, {'PluginType', 'Severity', ...
        'Message', 'SourcePath'})), ...
        'Expected diagnosis report fields')

    modules = nansen.plugin.Registry.list('module');
    assert(any(strcmp({modules.Id}, 'nansen.core')), ...
        'Expected core module metadata to be discoverable')
end
