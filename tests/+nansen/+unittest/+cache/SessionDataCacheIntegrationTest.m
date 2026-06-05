classdef SessionDataCacheIntegrationTest < matlab.unittest.TestCase
%SessionDataCacheIntegrationTest Integration tests for SessionData + DataCache
%
%   Drives the real SessionData subsref load-through path with a fake
%   session (no project fixture required), verifying that variable access
%   loads from disk only once and is then served from the shared cache,
%   that displaying the object triggers no load, and that resetCache
%   invalidates the right entries.

    methods (TestMethodSetup)
        function resetSharedCache(testCase)
            nansen.cache.DataCache.instance("reset");
            testCase.addTeardown(@() nansen.cache.DataCache.instance("reset"));
        end
    end

    methods (Test)
        function accessLoadsOnceThenServesFromCache(testCase)
        %accessLoadsOnceThenServesFromCache Repeated access reads disk once.
            [fake, sd] = testCase.makeSession("sess-1");
            sd.registerVariable("dff");

            first = sd.dff;
            second = sd.dff;

            testCase.verifyEqual(fake.loadCount("dff"), 1, ...
                "Repeated access should load from disk only once")
            testCase.verifyEqual(first, second)
        end

        function cacheKeyFollowsEntityConvention(testCase)
        %cacheKeyFollowsEntityConvention Key is session:<id>:<variable>.
            [~, sd] = testCase.makeSession("sess-1");
            sd.registerVariable("dff");

            testCase.verifyEqual(sd.dff, magic(8))   % populate the cache

            cache = nansen.cache.DataCache.instance();
            testCase.verifyTrue(cache.isKey("session:sess-1:dff"))
        end

        function displayDoesNotTriggerLoad(testCase)
        %displayDoesNotTriggerLoad Rendering the object loads nothing.
            [fake, sd] = testCase.makeSession("sess-1");
            sd.registerVariable("dff");

            evalc('disp(sd)');

            testCase.verifyEqual(fake.loadCount("dff"), 0, ...
                "Displaying the object must not load any variable")
            testCase.verifyFalse( ...
                nansen.cache.DataCache.instance().isKey("session:sess-1:dff"), ...
                "Display must not populate the cache")
        end

        function resetCacheForcesReload(testCase)
        %resetCacheForcesReload Invalidating one variable forces a reload.
            [fake, sd] = testCase.makeSession("sess-1");
            sd.registerVariable("dff");

            firstValue = sd.dff;
            sd.resetCache("dff");
            secondValue = sd.dff;

            testCase.verifyEqual(fake.loadCount("dff"), 2, ...
                "resetCache should invalidate the entry, forcing a reload")
            testCase.verifyEqual(firstValue, secondValue)
        end

        function resetCacheAllDropsOnlyThisSession(testCase)
        %resetCacheAllDropsOnlyThisSession No-arg reset is scoped to one session.
            [~, sessionA] = testCase.makeSession("sess-A");
            [~, sessionB] = testCase.makeSession("sess-B");
            sessionA.registerVariable("dff");
            sessionB.registerVariable("dff");
            testCase.assertEqual(sessionA.dff, magic(8))
            testCase.assertEqual(sessionB.dff, magic(8))

            sessionA.resetCache();   % drop everything for session A

            cache = nansen.cache.DataCache.instance();
            testCase.verifyFalse(cache.isKey("session:sess-A:dff"))
            testCase.verifyTrue(cache.isKey("session:sess-B:dff"), ...
                "Other sessions must be untouched")
        end
    end

    methods (Static, Access = private)
        function [fake, sd] = makeSession(sessionID)
            fake = nansen.unittest.cache.FakeSession(sessionID);
            sd = nansen.unittest.cache.SessionDataHarness(fake);
        end
    end
end
