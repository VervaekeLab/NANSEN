classdef MetaTableCacheInvalidationTest < matlab.unittest.TestCase

    methods (TestMethodTeardown)
        function resetMetaTableCache(~)
            nansen.metadata.MetaTableCache.instance("reset");
        end
    end

    methods (Test)
        function testTableEditInvalidatesCachedMetaObject(testCase)
            metaTable = testCase.createSubjectMetaTable();

            subjectObj = metaTable.getMetaObjects(1);
            metaTable.editEntriesFromTable(1, 'Description', 'Updated description')

            testCase.verifyFalse(isvalid(subjectObj));

            newSubjectObj = metaTable.getMetaObjects(1);
            testCase.verifyTrue(isvalid(newSubjectObj));
            testCase.verifyEqual(newSubjectObj.Description, 'Updated description');
        end

        function testRemoveEntriesInvalidatesCachedMetaObject(testCase)
            metaTable = testCase.createSubjectMetaTable();

            subjectObj = metaTable.getMetaObjects(1);
            subjectId = metaTable.entries.SubjectID{1};
            metaTable.removeEntries(subjectId)

            testCase.verifyFalse(isvalid(subjectObj));
            testCase.verifyFalse(any(strcmp(metaTable.members, subjectId)));
        end
    end

    methods (Access = private)
        function metaTable = createSubjectMetaTable(~)
            subjectIds = {'sub-001'; 'sub-002'; 'sub-003'};
            datesOfBirth = repmat(datetime(2020, 1, 1), 3, 1);
            biologicalSex = {'F'; 'M'; 'F'};
            species = {'Mouse'; 'Mouse'; 'Mouse'};
            strain = {'C57BL/6J'; 'C57BL/6J'; 'C57BL/6J'};
            description = {'Initial 1'; 'Initial 2'; 'Initial 3'};

            entries = table( ...
                subjectIds, datesOfBirth, biologicalSex, species, strain, description, ...
                'VariableNames', {'SubjectID', 'DateOfBirth', 'BiologicalSex', ...
                    'Species', 'Strain', 'Description'});

            metaTable = nansen.metadata.MetaTable(entries, ...
                'MetaTableClass', 'nansen.metadata.type.Subject', ...
                'MetaTableIdVarname', 'SubjectID');
        end
    end
end
