classdef Registry < nansen.plugin.base.Registry
%Registry Project-owned registry for FileAdapter plugins.
%
%   Scans +fileadapter/ subfolders of registered sources and provides the
%   same struct-array shape that nansen.dataio.listFileAdapters previously
%   returned via Module.getTable.
%
%   Fields per entry:
%       FileAdapterName     - Class name (string)
%       FunctionName        - Full MATLAB function/package name (string)
%       SupportedFileTypes  - Supported extensions (string array)
%       DataType            - Data type returned on load (string)
%       IsDynamic           - true for sidecar-based, false for class-based
%
%   See also: nansen.plugin.base.Registry, nansen.dataio.listFileAdapters

    methods % Public list extension
        function entries = list(obj, fileExtension)
        %list Return the struct array, optionally filtered by file extension.
        %
        %   entries = list() returns all adapters.
        %   entries = list(fileExtension) filters to adapters that support the
        %     given extension (with or without a leading dot).
            arguments
                obj
                fileExtension (1,1) string = ""
            end
            entries = list@nansen.plugin.base.Registry(obj);

            if fileExtension == "" || isempty(entries)
                return
            end

            ext = strrep(fileExtension, ".", "");
            matchFcn = @(extList) any(contains(extList, ext, "IgnoreCase", true));
            keep = arrayfun(@(s) matchFcn(s.SupportedFileTypes), entries);
            entries = entries(keep);
        end
    end

    methods (Access = protected)
        function id = primaryId(~, entry)
        %primaryId Return the FileAdapterName as the unique entry id.
            id = string(entry.FileAdapterName);
        end

        function entries = scanSource(obj, sourceId, sourcePath) %#ok<INUSL>
        %scanSource Scan a +fileadapter/ subfolder for adapters.
        %
        %   Returns a struct array with the five standard adapter fields.
        %   Returns an empty struct with those fields if the source has no
        %   +fileadapter/ subfolder.
            emptyEntry = struct( ...
                'FileAdapterName', {}, ...
                'FunctionName',    {}, ...
                'SupportedFileTypes', {}, ...
                'DataType',   {}, ...
                'IsDynamic',  {});

            fileadapterRoot = fullfile(sourcePath, '+fileadapter');
            if ~isfolder(fileadapterRoot)
                entries = emptyEntry;
                return
            end

            mFiles    = nansen.module.Module.listMFiles( ...
                fileadapterRoot, ["read.m", "write.m", "view.m"]);
            jsonFiles = nansen.module.Module.listJsonFiles( ...
                fileadapterRoot, 'fileadapter');
            fileList  = [mFiles; jsonFiles];

            if isempty(fileList)
                entries = emptyEntry;
                return
            end

            tbl = nansen.dataio.FileAdapter.buildFileAdapterTable(fileList);
            if isempty(tbl)
                entries = emptyEntry;
            else
                entries = table2struct(tbl);
                entries = obj.normalizeEntries(entries);
            end
        end
    end

    methods (Access = private)
        function entries = normalizeEntries(~, entries)
        %normalizeEntries Keep file adapter metadata text fields as strings.
            for i = 1:numel(entries)
                entries(i).FileAdapterName = string(entries(i).FileAdapterName);
                entries(i).FunctionName = string(entries(i).FunctionName);
                entries(i).SupportedFileTypes = string(entries(i).SupportedFileTypes);
                entries(i).DataType = string(entries(i).DataType);
            end
        end
    end
end
