classdef InstallationReporter
%InstallationReporter User-facing reporting for add-on installation results.

    properties (Constant)
        TroubleshootingUrl = "https://github.com/VervaekeLab/NANSEN/wiki/Installation-troubleshooting"
    end

    methods (Static)
        function show(installationReport)
        %show Print a concise add-on installation summary.
            if ~installationReport.HasFailures
                return
            end

            failedResults = installationReport.FailedResults;
            if any([failedResults.IsRequired])
                fprintf(2, '\nSome required add-ons could not be installed.\n\n')
            else
                fprintf(2, '\nSome optional add-ons could not be fully set up.\n\n')
            end

            nansen.config.addons.InstallationReporter.printStageFailures( ...
                failedResults, "download", "Download problems")
            nansen.config.addons.InstallationReporter.printStageFailures( ...
                failedResults, "setup", "Setup problems")

            fprintf(2, '\nTroubleshooting: %s\n', ...
                nansen.config.addons.InstallationReporter.createWebLink( ...
                nansen.config.addons.InstallationReporter.TroubleshootingUrl, ...
                "Troubleshooting guide"))
            fprintf(2, '\n')
        end

        function message = createUserMessage(addonEntry, stage, exception)
        %createUserMessage Create concise text for users.
            addonName = string(addonEntry.Name);
            if string(stage) == "download"
                message = sprintf( ...
                    '%s could not be downloaded or installed.', ...
                    char(addonName));
                return
            end

            if contains(string(exception.message), "mex", "IgnoreCase", true)
                message = sprintf( ...
                    ['%s was downloaded, but its compiled MEX components ', ...
                    'could not be built. NANSEN can continue, but ', ...
                    'functionality that depends on this add-on may be ', ...
                    'unavailable.'], char(addonName));
            else
                message = sprintf( ...
                    ['%s was downloaded, but its setup step did not ', ...
                    'complete. NANSEN can continue, but functionality ', ...
                    'that depends on this add-on may be unavailable.'], ...
                    char(addonName));
            end
        end

        function tf = hasMexFailure(failedResults)
        %hasMexFailure True when any failed result mentions MEX.
            tf = any(contains( ...
                string({failedResults.ErrorMessage}), "mex", ...
                "IgnoreCase", true));
        end

        function printStageFailures(failedResults, stage, heading)
        %printStageFailures Print failures for one installation stage.
            isStageFailure = string({failedResults.Stage}) == stage;
            if ~any(isStageFailure)
                return
            end

            fprintf(2, '%s:\n', heading)
            stageResults = failedResults(isStageFailure);
            for i = 1:numel(stageResults)
                fprintf(2, '- %s: %s\n', ...
                    stageResults(i).Name, stageResults(i).Message)
                reason = nansen.config.addons.InstallationReporter.getReason( ...
                    stageResults(i));
                if strlength(reason) > 0
                    fprintf(2, '  Reason: %s\n', reason)
                end
                if ~isempty(stageResults(i).LogFilePath)
                    fprintf(2, '  Error details: %s\n', ...
                        nansen.config.addons.InstallationReporter.createOpenLink( ...
                        stageResults(i).LogFilePath, "Open error details"))
                end
            end
        end

        function reason = getReason(installationResult)
        %getReason Return a concise reason for command-window output.
            reason = strtrim(string(installationResult.ErrorMessage));
            if reason == ""
                return
            end

            if contains(reason, "mex", "IgnoreCase", true)
                reason = "Native MEX build failure.";
                return
            end

            reasonLines = splitlines(reason);
            reason = strtrim(reasonLines(1));
        end

        function logFilePath = writeErrorLog( ...
                installationResult, exception, installationFolder)
        %writeErrorLog Persist the full technical error report.
            logFolder = fullfile(installationFolder, '.nansen', ...
                'install_logs');
            if ~isfolder(logFolder)
                mkdir(logFolder)
            end

            addonSlug = lower(regexprep(installationResult.Name, ...
                '[^a-zA-Z0-9]+', '_'));
            addonSlug = regexprep(addonSlug, '^_+|_+$', '');
            timestamp = char(datetime("now", ...
                "Format", "yyyyMMdd_HHmmss_SSS"));
            logFilePath = fullfile(logFolder, sprintf('%s_%s.log', ...
                timestamp, addonSlug));

            fileIdentifier = fopen(logFilePath, 'wt');
            if fileIdentifier == -1
                logFilePath = '';
                return
            end
            closeFile = onCleanup(@() fclose(fileIdentifier));

            fprintf(fileIdentifier, 'NANSEN add-on installation error\n');
            fprintf(fileIdentifier, 'Generated: %s\n', char(datetime("now")));
            fprintf(fileIdentifier, 'Add-on: %s\n', installationResult.Name);
            fprintf(fileIdentifier, 'Stage: %s\n', installationResult.Stage);
            fprintf(fileIdentifier, 'Installation folder: %s\n\n', ...
                char(installationFolder));
            fprintf(fileIdentifier, '%s\n', ...
                nansen.config.addons.InstallationReporter.createPlainTextReport( ...
                exception));
        end

        function warn(installationResult)
        %warn Warn without dumping the full technical report.
            if ~strcmp(installationResult.Status, 'failed')
                return
            end

            if isempty(installationResult.LogFilePath)
                warning('NANSEN:AddonManager:InstallFailed', ...
                    '%s', installationResult.Message)
            else
                warning('NANSEN:AddonManager:InstallFailed', ...
                    '%s Error details: %s', ...
                    installationResult.Message, ...
                    nansen.config.addons.InstallationReporter.createOpenLink( ...
                    installationResult.LogFilePath, "Open error details"))
            end
        end

        function linkText = createOpenLink(filePath, title)
        %createOpenLink Create a MATLAB command-window link to open a file.
            if nargin < 2
                title = "Open";
            end
            filePath = char(filePath);
            escapedFilePath = strrep(filePath, '''', '''''');
            linkText = sprintf('<a href="matlab:open(''%s'')">%s</a>', ...
                escapedFilePath, char(title));
        end

        function linkText = createWebLink(url, title)
        %createWebLink Create a MATLAB command-window link to open a URL.
            if nargin < 2
                title = "Open";
            end
            url = char(url);
            escapedUrl = strrep(url, '''', '''''');
            linkText = sprintf( ...
                '<a href="matlab:web(''%s'', ''-browser'')">%s</a>', ...
                escapedUrl, char(title));
        end

        function reportText = createPlainTextReport(exception)
        %createPlainTextReport Create an error report without HTML links.
            reportText = getReport(exception, 'extended', ...
                'hyperlinks', 'off');
        end
    end
end
