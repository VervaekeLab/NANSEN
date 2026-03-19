function generateRequirementsTxt(manifestFilePath, outputFilePath)
%generateRequirementsTxt Generate requirements.txt from a manifest file.
%
%   generateRequirementsTxt(manifestFilePath, outputFilePath) reads a
%   requirements.nansen.json manifest and writes a requirements.txt
%   containing only community-toolbox entries with their Source URIs.
%
%   MathWorks products are excluded. Entries without a Source field are
%   skipped with a warning.
%
%   Input:
%       manifestFilePath (1,1) string - Path to requirements.nansen.json
%       outputFilePath (1,1) string - Path to write requirements.txt

    arguments
        manifestFilePath (1,1) string {mustBeFile}
        outputFilePath (1,1) string
    end

    dependencies = nansen.internal.dependencies.readManifest(manifestFilePath);

    sourceLines = string.empty;
    for i = 1:numel(dependencies)
        entry = dependencies(i);

        if entry.DependencyType ~= "community-toolbox"
            continue
        end

        if entry.Source == ""
            warning("NANSEN:Dependencies:MissingSource", ...
                "Community toolbox '%s' has no Source field — skipping.", ...
                entry.Name);
            continue
        end

        sourceLines(end+1) = entry.Source; %#ok<AGROW>
    end

    % Write output file
    fileContent = strjoin(sourceLines, newline) + newline;
    fileId = fopen(outputFilePath, 'w');
    cleanupObj = onCleanup(@() fclose(fileId));
    if fileId == -1
        error("NANSEN:Dependencies:FileWriteError", ...
            "Could not open '%s' for writing.", outputFilePath);
    end
    fprintf(fileId, '%s', fileContent);
end
