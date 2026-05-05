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
    javaDependencies(1).JavaSetup = @nansen.internal.setup.addYamlJarToJavaClassPath;

    javaDependencies(2).Name = 'Widgets Toolbox';
    javaDependencies(2).MatlabProbe = 'uiw.widget.Table';
    javaDependencies(2).JavaProbe = 'com.mathworks.consulting.widgets.table.Table';
    javaDependencies(2).JavaSetup = @nansen.internal.setup.addUiwidgetsJarToJavaClassPath;

    for i = 1:numel(javaDependencies)
        dependency = javaDependencies(i);

        if isempty(which(dependency.MatlabProbe))
            error('NANSEN:setup:MatlabDependencyNotFound', ...
                ['NANSEN relies on the "%s" toolbox, but "%s" was not ', ...
                'found on MATLAB''s search path. Please run nansen.install ', ...
                'and try again.'], ...
                dependency.Name, dependency.MatlabProbe)
        end

        for j = 1:2
        % Try two times to catch edge case where the java dependency is on
        % MATLABs search path, but not on the java class path. Can happen
        % if user switches between MATLAB releases.
            try
                javaObject(dependency.JavaProbe);
                break
            catch exception
                if strcmp(exception.identifier, 'MATLAB:Java:ClassLoad')
                    if j == 1
                        dependency.JavaSetup()
                    else
                        % Static Java class path changes require a MATLAB restart.
                        error('NANSEN:setup:JavaClassNotFound', ...
                            ['NANSEN relies on Java classes from the "%s" toolbox, ', ...
                            'but "%s" could not be loaded in the current MATLAB ', ...
                            'session. Please restart MATLAB and try again.'], ...
                            dependency.Name, dependency.JavaProbe)
                    end
                else
                    rethrow(exception)
                end
            end
        end
    end

    wasVerified = true;
end
