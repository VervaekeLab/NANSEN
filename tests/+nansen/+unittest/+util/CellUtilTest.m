classdef CellUtilTest < matlab.unittest.TestCase
    %CellUtilTest Unit tests for nansen.util.cell utilities.
    %
    %   Covers isWrapped and unWrap, which detect and remove the
    %   scalar-cell-in-cell nesting pattern used by NANSEN cell columns.
    %
    %   Run tests:
    %       runtests('nansen.unittest.util.CellUtilTest')

    methods (Test)

        % ----------------------------------------------------------------
        % isWrapped
        % ----------------------------------------------------------------

        function testIsWrappedTrueForNestedScalarCell(testCase)
            % A 1x1 cell whose content is itself a cell is "wrapped".
            testCase.verifyTrue(nansen.util.cell.isWrapped({{'hello'}}));
        end

        function testIsWrappedFalseForFlatScalarCell(testCase)
            % A 1x1 cell whose content is not a cell is not wrapped.
            testCase.verifyFalse(nansen.util.cell.isWrapped({'hello'}));
            testCase.verifyFalse(nansen.util.cell.isWrapped({42}));
        end

        function testIsWrappedFalseForNonScalarCell(testCase)
            % A multi-element cell is not scalar, so it is not wrapped
            % regardless of its content.
            testCase.verifyFalse(nansen.util.cell.isWrapped({'a', 'b'}));
            testCase.verifyFalse(nansen.util.cell.isWrapped({{'a'}, {'b'}}));
        end

        function testIsWrappedFalseForNonCell(testCase)
            % Non-cell inputs are never wrapped.
            testCase.verifyFalse(nansen.util.cell.isWrapped('hello'));
            testCase.verifyFalse(nansen.util.cell.isWrapped(42));
            testCase.verifyFalse(nansen.util.cell.isWrapped([]));
        end

        % ----------------------------------------------------------------
        % unWrap
        % ----------------------------------------------------------------

        function testUnWrapStripsOneNestingLevel(testCase)
            % A single-wrapped cell is unwrapped to the inner cell.
            result = nansen.util.cell.unWrap({{'hello'}});
            testCase.verifyEqual(result, {'hello'});
        end

        function testUnWrapIsIdempotentOnFlatCell(testCase)
            % A flat (non-wrapped) cell passes through unchanged.
            result = nansen.util.cell.unWrap({'hello'});
            testCase.verifyEqual(result, {'hello'});
        end

        function testUnWrapHandlesMultipleLevels(testCase)
            % Repeatedly unwraps until no more nesting remains.
            result = nansen.util.cell.unWrap({{{'hello'}}});
            testCase.verifyEqual(result, {'hello'});
        end

    end
end
