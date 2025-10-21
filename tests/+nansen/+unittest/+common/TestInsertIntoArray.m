classdef TestInsertIntoArray < matlab.unittest.TestCase
    % TestInsertIntoArray - Comprehensive unit tests for utility.insertIntoArray
    %
    % This test class validates the insertIntoArray function across various
    % scenarios including different dimensions, data types, edge cases, and
    % error conditions.

    methods (Test)
        %% Basic functionality tests
        
        function testBasic2DRowInsertion(testCase)
            % Test inserting rows into a 2D array (documented example)
            A = reshape(1:12, 4, 3);             % 4x3
            B = [100 101 102; 200 201 202];      % 2x3
            C = utility.insertIntoArray(A, B, [2 4], 1);
            
            expected = [
                1     5     9
                100   101   102
                2     6    10
                200   201   202
                3     7    11
                4     8    12
            ];
            
            testCase.verifyEqual(C, expected);
        end
        
        function testBasic2DColumnInsertion(testCase)
            % Test inserting columns into a 2D array
            A = reshape(1:12, 3, 4);             % 3x4
            B = [100; 200; 300];                 % 3x1
            C = utility.insertIntoArray(A, B, 2, 2);
            
            expected = [
                1   100   4   7   10
                2   200   5   8   11
                3   300   6   9   12
            ];
            
            testCase.verifyEqual(C, expected);
        end
        
        function testInsertAtBeginning(testCase)
            % Test inserting at the beginning of dimension
            A = [1 2 3; 4 5 6];
            B = [100 200 300];
            C = utility.insertIntoArray(A, B, 1, 1);
            
            expected = [100 200 300; 1 2 3; 4 5 6];
            testCase.verifyEqual(C, expected);
        end
        
        function testInsertAtEnd(testCase)
            % Test inserting at the end of dimension
            A = [1 2 3; 4 5 6];
            B = [100 200 300];
            C = utility.insertIntoArray(A, B, 3, 1);
            
            expected = [1 2 3; 4 5 6; 100 200 300];
            testCase.verifyEqual(C, expected);
        end
        
        function testMultipleNonConsecutiveInsertions(testCase)
            % Test inserting at multiple non-consecutive positions
            A = (1:5)';
            B = [100; 200; 300];
            C = utility.insertIntoArray(A, B, [2 5 7], 1);
            
            expected = [1; 100; 2; 3; 200; 4; 300; 5];
            testCase.verifyEqual(C, expected);
        end
        
        %% 3D array tests
        
        function testBasic3DInsertion(testCase)
            % Test inserting along first dimension of 3D array
            A = reshape(1:24, 2, 3, 4);
            B = reshape(100:111, 1, 3, 4);
            C = utility.insertIntoArray(A, B, 2, 1);
            
            testCase.verifySize(C, [3, 3, 4]);
            testCase.verifyEqual(C(1, :, :), A(1, :, :));
            testCase.verifyEqual(C(2, :, :), B(1, :, :));
            testCase.verifyEqual(C(3, :, :), A(2, :, :));
        end
        
        function test3DInsertionSecondDimension(testCase)
            % Test inserting along second dimension of 3D array
            A = reshape(1:24, 2, 3, 4);
            B = reshape(100:107, 2, 1, 4);
            C = utility.insertIntoArray(A, B, 2, 2);
            
            testCase.verifySize(C, [2, 4, 4]);
            testCase.verifyEqual(C(:, 1, :), A(:, 1, :));
            testCase.verifyEqual(C(:, 2, :), B(:, 1, :));
            testCase.verifyEqual(C(:, 3:4, :), A(:, 2:3, :));
        end
        
        function test3DInsertionThirdDimension(testCase)
            % Test inserting along third dimension of 3D array
            A = reshape(1:24, 2, 3, 4);
            B = reshape(100:105, 2, 3, 1);
            C = utility.insertIntoArray(A, B, 3, 3);
            
            testCase.verifySize(C, [2, 3, 5]);
            testCase.verifyEqual(C(:, :, 1:2), A(:, :, 1:2));
            testCase.verifyEqual(C(:, :, 3), B(:, :, 1));
            testCase.verifyEqual(C(:, :, 4:5), A(:, :, 3:4));
        end
        
        %% Higher dimensional tests
        
        function test4DInsertion(testCase)
            % Test inserting into 4D array
            A = reshape(1:48, 2, 3, 4, 2);
            B = reshape(100:123, 1, 3, 4, 2);
            C = utility.insertIntoArray(A, B, 1, 1);
            
            testCase.verifySize(C, [3, 3, 4, 2]);
            testCase.verifyEqual(C(1, :, :, :), B(1, :, :, :));
            testCase.verifyEqual(C(2:3, :, :, :), A(1:2, :, :, :));
        end
        
        %% Data type tests
        
        function testDoubleDataType(testCase)
            A = [1.5, 2.5, 3.5];
            B = [10.1, 20.2];
            C = utility.insertIntoArray(A, B, [2 4], 2);
            
            expected = [1.5, 10.1, 2.5, 20.2, 3.5];
            testCase.verifyEqual(C, expected, 'AbsTol', 1e-10);
        end
        
        function testIntegerDataType(testCase)
            A = int32([1, 2, 3]);
            B = int32([10, 20]);
            C = utility.insertIntoArray(A, B, [2 4], 2);
            
            expected = int32([1, 10, 2, 20, 3]);
            testCase.verifyEqual(C, expected);
            testCase.verifyClass(C, 'int32');
        end
        
        function testLogicalDataType(testCase)
            A = logical([1 0 1]);
            B = logical([0 1]);
            C = utility.insertIntoArray(A, B, [2 4], 2);
            
            expected = logical([1 0 0 1 1]);
            testCase.verifyEqual(C, expected);
            testCase.verifyClass(C, 'logical');
        end
        
        function testCharDataType(testCase)
            A = 'abc';
            B = 'XY';
            C = utility.insertIntoArray(A, B, [2 4], 2);
            
            expected = 'aXbYc';
            testCase.verifyEqual(C, expected);
        end

        function testCellDataType(testCase)
            A = {'a', 'b', 'c'};
            B = {'X', 'Y'};
            C = utility.insertIntoArray(A, B, [2 4], 2);
            
            expected = {'a', 'X', 'b', 'Y', 'c'};
            testCase.verifyEqual(C, expected);
        end
        
        function testComplexDataType(testCase)
            A = [1+1i, 2+2i, 3+3i];
            B = [10+10i, 20+20i];
            C = utility.insertIntoArray(A, B, [2 4], 2);
            
            expected = [1+1i, 10+10i, 2+2i, 20+20i, 3+3i];
            testCase.verifyEqual(C, expected);
        end
        
        %% Edge cases
        
        function testSingleElementArrays(testCase)
            A = 5;
            B = 10;
            C = utility.insertIntoArray(A, B, 1, 1);
            
            expected = [10; 5];
            testCase.verifyEqual(C, expected);
        end
        
        function testInsertSingleSlice(testCase)
            A = [1 2 3; 4 5 6];
            B = [10 20 30];
            C = utility.insertIntoArray(A, B, 2, 1);
            
            expected = [1 2 3; 10 20 30; 4 5 6];
            testCase.verifyEqual(C, expected);
        end
        
        function testLargeArray(testCase)
            % Test with larger arrays to ensure scalability
            A = ones(100, 50);
            B = rand(10, 50);
            insertPos = [5 15 25 35 45 55 65 75 85 95];
            
            C = utility.insertIntoArray(A, B, insertPos, 1);
            
            testCase.verifySize(C, [110, 50]);
            % Verify a sample of original data is preserved
            testCase.verifyEqual(C(1, :), A(1, :));
        end
        
        function testAllPositionsInserted(testCase)
            % Test inserting at every other position
            A = [1; 2; 3];
            B = [100; 200; 300];
            C = utility.insertIntoArray(A, B, [1 3 5], 1);
            
            expected = [100; 1; 200; 2; 300; 3];
            testCase.verifyEqual(C, expected);
        end
        
        %% Singleton dimension handling
        
        function testRowVectorAsColumnInsert(testCase)
            % Row vector is 1xN, inserting along dim 1
            A = [1 2 3 4];  % 1x4
            B = [10 20];    % 1x2
            C = utility.insertIntoArray(A, B, [2 4], 2);
            
            expected = [1 10 2 20 3 4];
            testCase.verifyEqual(C, expected);
        end
        
        function testColumnVectorInsert(testCase)
            A = [1; 2; 3; 4];  % 4x1
            B = [10; 20];      % 2x1
            C = utility.insertIntoArray(A, B, [2 4], 1);
            
            expected = [1; 10; 2; 20; 3; 4];
            testCase.verifyEqual(C, expected);
        end
        
        %% Error condition tests
        
        function testErrorIncompatibleSizes(testCase)
            A = rand(3, 4);
            B = rand(2, 5);  % Wrong size in non-insert dimension
            
            testCase.verifyError(...
                @() utility.insertIntoArray(A, B, [2 3], 1), ...
                'NANSEN:InsertArray:IncompatibleArraySizes');
        end
        
        function testErrorWrongNumberOfIndices(testCase)
            A = rand(3, 4);
            B = rand(2, 4);
            
            % Provide 3 indices but B only has 2 rows
            testCase.verifyError(...
                @() utility.insertIntoArray(A, B, [1 2 3], 1), ...
                'NANSEN:InsertArray:InvalidInsertionIndices');
        end
        
        function testErrorDuplicateIndices(testCase)
            A = rand(3, 4);
            B = rand(2, 4);
            
            % Duplicate index
            testCase.verifyError(...
                @() utility.insertIntoArray(A, B, [2 2], 1), ...
                'NANSEN:InsertArray:NonUniqueInsertionIndices');
        end
        
        function testErrorIndicesOutOfRange(testCase)
            A = rand(3, 4);
            B = rand(2, 4);
            
            % Index 6 is out of range (max should be 5)
            testCase.verifyError(...
                @() utility.insertIntoArray(A, B, [2 6], 1), ...
                'NANSEN:InsertArray:NonUniqueInsertionIndices');
        end
        
        function testErrorZeroIndex(testCase)
            A = rand(3, 4);
            B = rand(1, 4);
            
            % Zero index should be caught by argument validation
            testCase.verifyError(...
                @() utility.insertIntoArray(A, B, 0, 1), ...
                'MATLAB:validators:mustBePositive');
        end
        
        function testErrorNegativeIndex(testCase)
            A = rand(3, 4);
            B = rand(1, 4);
            
            % Negative index should be caught by argument validation
            testCase.verifyError(...
                @() utility.insertIntoArray(A, B, -1, 1), ...
                'MATLAB:validators:mustBePositive');
        end
        
        function testErrorInvalidDimension(testCase)
            A = rand(3, 4);
            B = rand(2, 4);
            
            % Dimension 5 exceeds array dimensions
            testCase.verifyError(...
                @() utility.insertIntoArray(A, B, [2 3], 5), ...
                'NANSEN:InsertArray:InvalidInsertDimension');
        end
        
        function testErrorNonIntegerDimension(testCase)
            A = rand(3, 4);
            B = rand(2, 4);
            
            % Non-integer dimension should be caught by argument validation
            testCase.verifyError(...
                @() utility.insertIntoArray(A, B, [2 3], 1.5), ...
                'MATLAB:validators:mustBeInteger');
        end
        
        %% Preservation tests
        
        function testOriginalDataPreserved(testCase)
            % Verify that original data is not modified and is preserved correctly
            A = magic(5);
            B = ones(2, 5) * 100;
            
            A_original = A;
            C = utility.insertIntoArray(A, B, [2 5], 1);
            
            % Original should be unchanged
            testCase.verifyEqual(A, A_original);
            
            % Check that original data appears in correct positions
            testCase.verifyEqual(C(1, :), A(1, :));
            testCase.verifyEqual(C(3, :), A(2, :));
            testCase.verifyEqual(C(4, :), A(3, :));
            testCase.verifyEqual(C(6, :), A(4, :));
            testCase.verifyEqual(C(7, :), A(5, :));
        end
        
        function testInsertedDataPreserved(testCase)
            % Verify that inserted data appears correctly
            A = magic(5);
            B = [100 200 300 400 500; 600 700 800 900 1000];
            
            C = utility.insertIntoArray(A, B, [2 5], 1);
            
            % Check that inserted data appears in correct positions
            testCase.verifyEqual(C(2, :), B(1, :));
            testCase.verifyEqual(C(5, :), B(2, :));
        end
        
        %% Order and consistency tests
        
        function testInsertionOrderMatters(testCase)
            % Verify that insertion indices are interpreted as final positions
            A = (1:5)';
            B = [100; 200];
            
            C1 = utility.insertIntoArray(A, B, [2 5], 1);
            C2 = utility.insertIntoArray(A, B, [5 2], 1);
            
            expected1 = [1; 100; 2; 3; 200; 4; 5];
            expected2 = [1; 200; 2; 3; 100; 4; 5];
            
            testCase.verifyEqual(C1, expected1);
            testCase.verifyEqual(C2, expected2);
        end
        
        function testConsistencyAcrossDimensions(testCase)
            % Test that function behaves consistently across different dimensions
            A = reshape(1:24, 2, 3, 4);
            B = reshape(100:111, 1, 3, 4);
            
            % Insert along dim 1
            C1 = utility.insertIntoArray(A, B, 2, 1);
            testCase.verifySize(C1, [3, 3, 4]);
            
            % Permute and insert along what was dim 1 (now dim 2)
            A_perm = permute(A, [2, 1, 3]);
            B_perm = permute(B, [2, 1, 3]);
            C2 = utility.insertIntoArray(A_perm, B_perm, 2, 2);
            
            % Results should be equivalent after permutation
            testCase.verifyEqual(C1, ipermute(C2, [2, 1, 3]));
        end
    end
end
