classdef SpecificationTest < matlab.unittest.TestCase

    methods (TestClassSetup)
        % Shared setup for the entire test class
    end

    methods (TestMethodSetup)
        % Setup for each test
    end

    methods (Test)
        % Test methods

        function testConstructorWithMissingRequiredProps(testCase)
            testCase.verifyError( ...
                @() nansen.unittest.common.helper.ConcreteSpecification(), ...
                'NANSEN:Specification:MissingRequiredProperties' ...
            )
            
            props = struct('Name', 'a name'); % Missing RequiredValue
            testCase.verifyError( ...
                @() nansen.unittest.common.helper.ConcreteSpecification(props), ...
                'NANSEN:Specification:MissingRequiredProperties' ...
            )

            props = struct('RequiredValue', 0); % Missing Name
            testCase.verifyError( ...
                @() nansen.unittest.common.helper.ConcreteSpecification(props), ...
                'NANSEN:Specification:MissingRequiredProperties' ...
            )
               
            props = struct('Name', 'a name', 'RequiredValue', nan); % Missing RequiredValue
            testCase.verifyError( ...
                @() nansen.unittest.common.helper.ConcreteSpecification(props), ...
                'NANSEN:Specification:MissingRequiredProperties' ...
            )
        end

        function testConstructorWithRequiredProps(testCase)
            props = struct('Name', 'a name', 'RequiredValue', 1);
            concrete = nansen.unittest.common.helper.ConcreteSpecification(props);
            testCase.verifyClass(concrete, 'nansen.unittest.common.helper.ConcreteSpecification')
            testCase.verifyTrue(isa(concrete, 'nansen.common.abstract.Specification'))
        end

        function testConstructorWithOptionalProps(testCase)
            props = struct('Name', 'test spec', 'RequiredValue', [1, 2, 3], 'OptionalValue', [4, 5]);
            concrete = nansen.unittest.common.helper.ConcreteSpecification(props);
            
            testCase.verifyEqual(concrete.Name, "test spec")
            testCase.verifyEqual(concrete.RequiredValue, [1; 2; 3])
            testCase.verifyEqual(concrete.OptionalValue, [4; 5])
        end

        function testPropertyValidation(testCase)
            % Test that properties accept correct data types
            props = struct('Name', 'valid name', 'RequiredValue', [1.5, 2.7]);
            concrete = nansen.unittest.common.helper.ConcreteSpecification(props);
            testCase.verifyEqual(concrete.RequiredValue, [1.5; 2.7])
            
            % Test empty arrays are allowed for optional properties
            props = struct('Name', 'test', 'RequiredValue', 1, 'OptionalValue', []);
            concrete = nansen.unittest.common.helper.ConcreteSpecification(props);
            testCase.verifyEmpty(concrete.OptionalValue)
        end

        function testToCellMethod(testCase)
            props = struct('Name', 'test spec', 'RequiredValue', [1, 2], 'OptionalValue', 3);
            concrete = nansen.unittest.common.helper.ConcreteSpecification(props);
            
            cellArray = concrete.toCell();
            
            % Verify it's a cell array with even number of elements (name-value pairs)
            testCase.verifyTrue(iscell(cellArray))
            testCase.verifyEqual(mod(length(cellArray), 2), 0)
            
            % Convert back to struct to verify content
            reconstructedStruct = struct(cellArray{:});
            testCase.verifyEqual(reconstructedStruct.Name, "test spec")
            testCase.verifyEqual(reconstructedStruct.RequiredValue, [1; 2])
            testCase.verifyEqual(reconstructedStruct.OptionalValue, 3)
        end

        function testToStructMethod(testCase)
            props = struct('Name', 'test spec', 'RequiredValue', [1, 2]);
            concrete = nansen.unittest.common.helper.ConcreteSpecification(props);
            
            structOutput = concrete.toStruct();
            
            % Verify structure has expected fields
            testCase.verifyTrue(isfield(structOutput, 'x_type'))
            testCase.verifyTrue(isfield(structOutput, 'x_version'))
            testCase.verifyTrue(isfield(structOutput, 'Properties'))
            
            % Verify metadata
            testCase.verifyEqual(structOutput.x_type, "ConcreteSpecification")
            testCase.verifyEqual(structOutput.x_version, "1.0.1")
            
            % Verify properties (TYPE and VERSION should be excluded)
            testCase.verifyFalse(isfield(structOutput.Properties, 'TYPE'))
            testCase.verifyFalse(isfield(structOutput.Properties, 'VERSION'))
            testCase.verifyEqual(structOutput.Properties.Name, "test spec")
            testCase.verifyEqual(structOutput.Properties.RequiredValue, [1; 2])
        end

        function testToJsonMethod(testCase)
            props = struct('Name', 'json test', 'RequiredValue', 42);
            concrete = nansen.unittest.common.helper.ConcreteSpecification(props);
            
            jsonStr = concrete.toJson();
            
            % Verify it's a valid JSON string
            testCase.verifyTrue(ischar(jsonStr) || isstring(jsonStr))
            
            % Parse JSON and verify structure
            parsedJson = jsondecode(jsonStr);
            testCase.verifyEqual(parsedJson.x_type, 'ConcreteSpecification')
            testCase.verifyEqual(parsedJson.x_version, '1.0.1')
            testCase.verifyEqual(parsedJson.Properties.Name, 'json test')
            testCase.verifyEqual(parsedJson.Properties.RequiredValue, 42)
        end

        function testSetGetFunctionality(testCase)
            props = struct('Name', 'initial', 'RequiredValue', 1);
            concrete = nansen.unittest.common.helper.ConcreteSpecification(props);
            
            % Test get method
            nameValue = concrete.get('Name');
            testCase.verifyEqual(nameValue, "initial")
            
            % Test set method
            concrete.set('Name', 'updated');
            testCase.verifyEqual(concrete.Name, "updated")
            
            % Test setting multiple properties
            newProps = struct('Name', 'multi update', 'OptionalValue', [10, 20]);
            concrete.set(newProps);
            testCase.verifyEqual(concrete.Name, "multi update")
            testCase.verifyEqual(concrete.OptionalValue, [10; 20])
        end

        function testConstantProperties(testCase)
            props = struct('Name', 'test', 'RequiredValue', 1);
            concrete = nansen.unittest.common.helper.ConcreteSpecification(props);
            
            % Verify constant properties
            testCase.verifyEqual(concrete.TYPE, "ConcreteSpecification")
            testCase.verifyEqual(concrete.VERSION, "1.0.1")
        end

        function testCompleteWorkflow(testCase)
            % Test a complete workflow from construction to JSON conversion
            originalProps = struct('Name', 'workflow test', 'RequiredValue', [1, 2, 3], 'OptionalValue', [4, 5]);
            concrete = nansen.unittest.common.helper.ConcreteSpecification(originalProps);
            
            % Convert to cell and back
            cellArray = concrete.toCell();
            reconstructed = struct(cellArray{:});
            
            % Verify reconstruction preserves data
            testCase.verifyEqual(reconstructed.Name, "workflow test")
            testCase.verifyEqual(reconstructed.RequiredValue, [1; 2; 3])
            testCase.verifyEqual(reconstructed.OptionalValue, [4; 5])
            
            % Convert to JSON and verify
            jsonStr = concrete.toJson();
            parsedJson = jsondecode(jsonStr);
            testCase.verifyEqual(parsedJson.Properties.Name, 'workflow test')
            testCase.verifyEqual(parsedJson.Properties.RequiredValue, [1; 2; 3])
        end
    end
    
end
