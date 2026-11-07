classdef MetaTableCatalogFake < handle
%MetaTableCatalogFake - A catalog of master MetaTables held in memory
%
%   getMasterMetaTable returns the first master table whose MetaTableClass
%   contains the type name, ignoring case, which is the rule
%   nansen.metadata.MetaTableCatalog.getMasterMetaTable uses. Tests use it
%   to call functions that take a catalog without saving tables to disk.

    properties (SetAccess = immutable)
        MasterTables (1,:) nansen.metadata.MetaTable
    end

    methods
        function obj = MetaTableCatalogFake(masterTables)
            arguments
                masterTables (1,:) nansen.metadata.MetaTable
            end
            obj.MasterTables = masterTables;
        end

        function metaTable = getMasterMetaTable(obj, typeName)
        %getMasterMetaTable - Get the first master table whose class contains typeName
            arguments
                obj (1,1) nansen.unittest.manage.helper.MetaTableCatalogFake
                typeName (1,1) string {mustBeNonzeroLengthText}
            end

            classNames = string({obj.MasterTables.MetaTableClass});
            matchIndex = find(contains(classNames, typeName, IgnoreCase=true), 1);
            assert(~isempty(matchIndex), "NANSEN:MetaTableCatalogFake:MasterNotFound", ...
                "The catalog has no master table whose class contains ""%s"".", typeName)
            metaTable = obj.MasterTables(matchIndex);
        end
    end
end
