local helper = require('spec.helper')
local Vector3, Entity = helper.Vector3, helper.Entity

local EPSILON = 0.0000000001

local align = require('mod.scripts.align').private

describe("align", function()
    describe('FindFirstAxisSnapTarget()', function()
        it('returns nil when there is no items', function()
            local e, a, oa = align.FindFirstAxisSnapTarget({})
            assert.is_nil(e)
            assert.is_nil(a)
            assert.is_nil(oa)
        end)

        it('returns nil when there is not entity to align', function()
            local e, a, oa = align.FindFirstAxisSnapTarget({
                Vector3(1, 0, 1),
                Vector3(-1, 0, -1),
            })
            assert.is_nil(e)
            assert.is_nil(a)
            assert.is_nil(oa)
        end)

        it('returns entity when x is small enough', function()
            local refs = {
                Vector3(-1, 0, 1.0),
                Vector3(0.1, 0, 1),
            }
            local e, a, oa = align.FindFirstAxisSnapTarget(refs)
            assert.are.same(refs[2], e)
            assert.are.equals('x', a)
            assert.are.equals('z', oa)
        end)

        it('returns entity when z is small enough', function()
            local refs = {
                Vector3(0.1, 0, 0.1),
                Vector3(0.1, 0, 0.01),
            }
            local e, a, oa = align.FindFirstAxisSnapTarget(refs)
            assert.are.same(refs[2], e)
            assert.are.equals('z', a)
            assert.are.equals('x', oa)
        end)
    end)

    describe('FindSecondAxisSnapTarget()', function()
        it('returns nil when no item to snap', function()
            local first = Vector3(0.01, 0, 1)
            local refs = {
                first,
                Vector3(1, 11, 1),
                Vector3(0.01, 22, 3),
                Vector3(0.01, 33, 1),
            }
            local second, offset = align.FindSecondAxisSnapTarget(refs, 'z', first)
            assert.is_nil(second)
            assert.are.equals(0, offset)
        end)

        it('returns online aligned (entity <-> placer <-> first)', function()
            local first = Vector3(0.01, 0, 1)

            local refs = {
                first,
                Vector3(1, 11, 1),
                Vector3(0.01, 22, 3),
                Vector3(0.01, 33, -1.2),
            }
            local second, offset = align.FindSecondAxisSnapTarget(refs, 'z', first)
            assert.is_true(rawequal(refs[4], second))
            assert.are.near(-0.1, offset, EPSILON)
        end)

        it('returns online aligned (entity <-> placer <-> first)', function()
            local first = Vector3(0.01, 41, 1)

            local refs = {
                first, -- first item itself
                Vector3(1, 42, 1), -- not align at all
                Vector3(0.01, 43, -1.2), -- online aligned, but not the best one
                Vector3(0.01, 44, 0.2), -- offline aligned, but not the best one
                Vector3(0.01, 45, -1.1), -- best one
            }
            local second, offset = align.FindSecondAxisSnapTarget(refs, 'z', first)
            assert.is_true(rawequal(refs[5], second))
            assert.are.near(-0.05, offset, EPSILON)
        end)

        it('returns online aligned (placer <-> first <-> entity)', function()
            local first = Vector3(0.01, 51, 1)

            local refs = {
                first, -- first item itself
                Vector3(1, 52, 1), -- not align at all
                Vector3(0.01, 53, 2.2), -- online aligned, but not the best one
                Vector3(0.01, 54, 0.2), -- offline aligned, but not the best one
                Vector3(0.01, 55, 2.1), -- best one
            }
            local second, offset = align.FindSecondAxisSnapTarget(refs, 'z', first)
            assert.is_true(rawequal(refs[5], second))
            assert.are.near(-0.1, offset, EPSILON)
        end)

        it('returns online aligned (placer <-> entity <-> first)', function()
            local first = Vector3(0.01, 61, 2)

            local refs = {
                first, -- first item itself
                Vector3(1, 62, 1), -- not align at all
                Vector3(0.01, 63, 1.2), -- online aligned, but not the best one
                Vector3(0.01, 64, 0.2), -- offline aligned, but not the best one
                Vector3(0.01, 65, 0.95), -- best one
            }
            local second, offset = align.FindSecondAxisSnapTarget(refs, 'z', first)
            assert.are.equals(refs[5], second)
            assert.are.near(-0.1, offset, EPSILON)
        end)

        it('returns offline aligned item when its better', function()
            local first = Vector3(0.01, 71, 1)

            local refs = {
                first,
                Vector3(1, 72, 1),
                Vector3(0.01, 73, -1.21), -- online aligned, but not the best one
                Vector3(0.01, 74, 0.2), -- offline aligned, but not the best one
                Vector3(0.01, 75, 0.1),
            }
            local second, offset = align.FindSecondAxisSnapTarget(refs, 'z', first)
            assert.are.equals(refs[5], second)
            assert.are.near(0.1, offset, EPSILON)
        end)
    end)

    describe('RoundPoint()', function()
        it('should rund to 0.1', function()
            local got = align.RoundPoint(Vector3(0.11, 0, 2.02))
            assert.are.same(Vector3(0.1, 0, 2.0), got)
        end)
    end)

    describe('FinalAlignedPoint(placerPoint, axis, first, nextAxis, off)', function()
        it('should return the final placer aligned position', function()
            local placer = Vector3(1, 0, 1)
            local e = Entity("a", 1.1, 0, 1)
            local first = e:GetPosition()
            first.entity = e

            local got = align.FinalAlignedPoint(placer, 'x', first, 'z', -0.1)

            assert.are.same(Vector3(1.1, 0, 0.9), got)
        end)
    end)
end)
