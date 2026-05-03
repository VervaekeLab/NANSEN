function verifyJavaDependencies()
% Verify that NANSEN's Java dependencies can be loaded.

    persistent wasVerified
    if isequal(wasVerified, true)
        return
    end

    if ~usejava('jvm')
        error('NANSEN:setup:JavaUnavailable', ...
            'NANSEN requires Java, but this MATLAB session has no JVM.')
    end

    javaDependencies = struct('Name', {}, 'MatlabProbe', {}, 'JavaProbe', {});

    javaDependencies(1).Name = 'YAML-Matlab';
    javaDependencies(1).MatlabProbe = 'yaml.WriteYaml';
    javaDependencies(1).JavaProbe = 'org.yaml.snakeyaml.Yaml';

    javaDependencies(2).Name = 'Widgets Toolbox';
    javaDependencies(2).MatlabProbe = 'uiw.widget.Table';
    javaDependencies(2).JavaProbe = 'com.mathworks.consulting.widgets.table.Table';

    for i = 1:numel(javaDependencies)
        dependency = javaDependencies(i);

        if isempty(which(dependency.MatlabProbe))
            error('NANSEN:setup:MatlabDependencyNotFound', ...
                ['NANSEN relies on the "%s" toolbox, but "%s" was not ', ...
                'found on MATLAB''s search path. Please run nansen.install ', ...
                'and try again.'], ...
                dependency.Name, dependency.MatlabProbe)
        end

        try
            javaObject(dependency.JavaProbe);
        catch exception
            if strcmp(exception.identifier, 'MATLAB:Java:ClassLoad')
                % Static Java class path changes require a MATLAB restart.
                error('NANSEN:setup:JavaClassNotFound', ...
                    ['NANSEN relies on Java classes from the "%s" toolbox, ', ...
                    'but "%s" could not be loaded in the current MATLAB ', ...
                    'session. Please restart MATLAB and try again.'], ...
                    dependency.Name, dependency.JavaProbe)
            else
                rethrow(exception)
            end
        end
    end

    wasVerified = true;
end
