//===- Tiling.cpp - Implementation of linalg Tiling -----------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements the linalg dialect Tiling pass.
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Affine/IR/AffineOps.h"
#include "mlir/Dialect/Affine/LoopUtils.h"
#include "mlir/Dialect/Arith/Utils/Utils.h"
#include "mlir/Dialect/ControlFlow/IR/ControlFlowOps.h"
#include "mlir/Dialect/Linalg/IR/Linalg.h"
#include "mlir/Dialect/Linalg/Transforms/Transforms.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/Dialect/SCF/Transforms/Transforms.h"
#include "mlir/Dialect/Tensor/IR/Tensor.h"
#include "mlir/Dialect/Utils/IndexingUtils.h"
#include "mlir/Dialect/Utils/StaticValueUtils.h"
#include "mlir/IR/AffineExpr.h"
#include "mlir/IR/AffineMap.h"
#include "mlir/IR/ValueRange.h"
#include "mlir/Transforms/FoldUtils.h"
#include "llvm/ADT/STLExtras.h"
#include <utility>

namespace mlir {
#define GEN_PASS_DEF_LINALGTILINGPASS
#include "mlir/Dialect/Linalg/Passes.h.inc"
} // namespace mlir

using namespace mlir;
using namespace mlir::affine;
using namespace mlir::linalg;
using namespace mlir::scf;

#define DEBUG_TYPE "linalg-tiling"

std::tuple<SmallVector<Range, 4>, LoopIndexToRangeIndexMap>
mlir::linalg::makeTiledLoopRanges(RewriterBase &b, Location loc, AffineMap map,
                                  ArrayRef<OpFoldResult> allShapeSizes,
                                  ArrayRef<OpFoldResult> allTileSizes) {
  assert(allTileSizes.size() == map.getNumResults());
  // Apply `map` to get shape sizes in loop order.
  SmallVector<OpFoldResult> shapeSizes =
      makeComposedFoldedMultiResultAffineApply(b, loc, map, allShapeSizes);
  SmallVector<OpFoldResult> tileSizes(allTileSizes);

  // Traverse the tile sizes, which are in loop order, erase zeros everywhere.
  LoopIndexToRangeIndexMap loopIndexToRangeIndex;
  for (int idx = 0, e = tileSizes.size(), zerosCount = 0; idx < e; ++idx) {
    if (getConstantIntValue(tileSizes[idx - zerosCount]) ==
        static_cast<int64_t>(0)) {
      shapeSizes.erase(shapeSizes.begin() + idx - zerosCount);
      tileSizes.erase(tileSizes.begin() + idx - zerosCount);
      ++zerosCount;
      continue;
    }
    loopIndexToRangeIndex[idx] = idx - zerosCount;
  }

  // Create a new range with the applied tile sizes.
  SmallVector<Range, 4> res;
  for (unsigned idx = 0, e = tileSizes.size(); idx < e; ++idx)
    res.push_back(Range{b.getIndexAttr(0), shapeSizes[idx], tileSizes[idx]});
  return std::make_tuple(res, loopIndexToRangeIndex);
}

void mlir::linalg::transformIndexOps(
    RewriterBase &b, LinalgOp op, SmallVectorImpl<Value> &ivs,
    const LoopIndexToRangeIndexMap &loopIndexToRangeIndex) {
  SmallVector<Value> allIvs(op.getNumLoops(), nullptr);
  for (auto en : enumerate(allIvs)) {
    auto rangeIndex = loopIndexToRangeIndex.find(en.index());
    if (rangeIndex == loopIndexToRangeIndex.end())
      continue;
    en.value() = ivs[rangeIndex->second];
  }
  offsetIndices(b, op, getAsOpFoldResult(allIvs));
}

/// Asserts that the given index-typed value is strictly positive. If the value
/// is an attribute, asserts at compile time, otherwise emits an assertion
/// checked at runtime.
static void emitIsPositiveIndexAssertion(ImplicitLocOpBuilder &b,
                                         OpFoldResult value) {
  if (auto attr = llvm::dyn_cast_if_present<Attribute>(value)) {
    assert(cast<IntegerAttr>(attr).getValue().isStrictlyPositive() &&
           "expected strictly positive tile size and divisor");
    return;
  }

  Value zero = arith::ConstantIndexOp::create(b, 0);
  Value condition = arith::CmpIOp::create(b, arith::CmpIPredicate::sgt,
                                          cast<Value>(value), zero);
  cf::AssertOp::create(
      b, condition,
      b.getStringAttr("expected strictly positive tile size and divisor"));
}

FailureOr<StaticContinuousTileSizeSpecification>
mlir::linalg::computeStaticContinuousTileSizes(LinalgOp op, unsigned dimension,
                                               unsigned targetSize) {

  assert(!op.hasDynamicShape() &&
         "cannot compute static multi-tile sizes for an op with dynamic shape");
  assert(targetSize > 0 && "target size must be non-negative");
  assert(dimension < op.getNumLoops() && "dimension overflow");

  StaticContinuousTileSizeSpecification spec;
  int64_t loopRange = op.getStaticLoopRanges()[dimension];
  int64_t tripCount = loopRange / targetSize;

  unsigned tileSize = targetSize;

  spec.tileSizes.push_back(tileSize);
  spec.tripCounts.push_back(tripCount);

  int64_t remainderChunk = loopRange % targetSize;

  while (tileSize > 1 && remainderChunk != 0) {

    uint64_t maxPower = llvm::bit_floor(tileSize);
    tileSize = maxPower == tileSize ? maxPower >> 1 : maxPower;

    tripCount = remainderChunk / tileSize;

    if (tripCount > 0) {
      spec.tileSizes.push_back(tileSize);
      spec.tripCounts.push_back(tripCount);
    }

    remainderChunk = remainderChunk % tileSize;
  }

  auto tripCountCheck = [&](SmallVector<int64_t> tileSizes,
                            SmallVector<int64_t> tripCounts,
                            int64_t range) -> bool {
    int64_t computedRange = 0;
    for (auto [tileSize, tripCount] : llvm::zip(tileSizes, tripCounts))
      computedRange += tileSize * tripCount;
    return range == computedRange;
  };

  if (!tripCountCheck(spec.tileSizes, spec.tripCounts, loopRange))
    return failure();

  return spec;
}

FailureOr<ContinuousTileSizeSpecification>
mlir::linalg::computeContinuousTileSizes(OpBuilder &builder, TilingInterface op,
                                         unsigned dimension,
                                         OpFoldResult targetSize,
                                         bool emitAssertions) {

  SmallVector<Range> loopRanges = op.getIterationDomain(builder);
  unsigned numLoops = loopRanges.size();

  // Bail out on dimension overflow.
  if (dimension >= numLoops)
    return failure();

  // The code below works only on values.
  Location loc = op->getLoc();
  ImplicitLocOpBuilder b(loc, builder);
  if (emitAssertions) {
    emitIsPositiveIndexAssertion(b, targetSize);
  }
  Value targetSizeValue =
      getValueOrCreateConstantIndexOp(builder, loc, targetSize);

  // Find the trip count of the iteration space dimension for which the tile
  // sizes are computed.
  Value loopRange =
      getValueOrCreateConstantIndexOp(b, loc, loopRanges[dimension].size);
  ContinuousTileSizeSpecification spec;

  // Compute the tile sizes and the respective numbers of tiles.
  AffineExpr s0 = b.getAffineSymbolExpr(0);
  AffineExpr s1 = b.getAffineSymbolExpr(1);
  auto apply = [&](AffineExpr expr, ArrayRef<OpFoldResult> ofrs) -> Value {
    return affine::makeComposedAffineApply(b, b.getLoc(), expr, ofrs);
  };

  Value tripCountValue = apply(s0.floorDiv(s1), {loopRange, targetSizeValue});
  Value remainderChunkValue = apply(s0 % s1, {loopRange, targetSizeValue});

  OpFoldResult tripCountSize = affine::makeComposedFoldedAffineApply(
      b, b.getLoc(), s0.floorDiv(s1), {loopRange, targetSizeValue});

  // emitAssertions above already asserts that targetSize is
  // a poistive integer.
  uint64_t tileSizeInt = *getConstantIntValue(targetSizeValue);

  assert(tileSizeInt > 0 && "target size must be non-negative");

  spec.tileSizes.push_back(targetSizeValue);
  spec.tripCounts.push_back(tripCountValue);

  while (tileSizeInt > 1) {
    uint64_t maxPower = llvm::bit_floor(tileSizeInt);
    tileSizeInt = maxPower == tileSizeInt ? maxPower >> 1 : maxPower;
    auto constStepOp =
        builder.createOrFold<arith::ConstantIndexOp>(b.getLoc(), tileSizeInt);
    tripCountValue = apply(s0.floorDiv(s1), {remainderChunkValue, constStepOp});

    tripCountSize = affine::makeComposedFoldedAffineApply(
        b, b.getLoc(), s0.floorDiv(s1), {remainderChunkValue, constStepOp});

    // Optimization if tripCount can be determined to be zero.
    if (Attribute attr = llvm::dyn_cast_if_present<Attribute>(tripCountSize)) {
      auto intAttr = cast<IntegerAttr>(attr);
      bool isTripCountZero = intAttr.getValue().isZero();

      if (!isTripCountZero) {
        spec.tileSizes.push_back(constStepOp);
        spec.tripCounts.push_back(tripCountValue);
      }
    } else {
      spec.tileSizes.push_back(constStepOp);
      spec.tripCounts.push_back(tripCountValue);
    }

    remainderChunkValue = apply(s0 % s1, {remainderChunkValue, constStepOp});
  }

  return spec;
}

FailureOr<StaticMultiSizeSpecification>
mlir::linalg::computeStaticMultiTileSizes(LinalgOp op, unsigned dimension,
                                          int64_t targetSize, int64_t divisor) {
  assert(!op.hasDynamicShape() &&
         "cannot compute static multi-tile sizes for an op with dynamic shape");
  assert(targetSize > 0 && "target size must be non-negative");
  assert(divisor > 0 && "divisor must be non-negative");
  assert(dimension < op.getNumLoops() && "dimension overflow");

  StaticMultiSizeSpecification spec;
  int64_t tripCount = op.getStaticLoopRanges()[dimension];
  int64_t a = tripCount / divisor;
  int64_t t = (targetSize + divisor - 1) / divisor;
  int64_t totalTripCount = (a + t - 1) / t;
  spec.lowTileSize = (a / totalTripCount) * divisor;
  spec.highTileSize = spec.lowTileSize + divisor;
  spec.highTripCount = a % totalTripCount;
  spec.lowTripCount = totalTripCount - spec.highTripCount;
  if (spec.lowTileSize * spec.lowTripCount +
          spec.highTileSize * spec.highTripCount !=
      tripCount) {
    return failure();
  }
  return spec;
}

FailureOr<MultiSizeSpecification>
mlir::linalg::computeMultiTileSizes(OpBuilder &builder, LinalgOp op,
                                    unsigned dimension, OpFoldResult targetSize,
                                    OpFoldResult divisor, bool emitAssertions) {
  // Bail out on dimension overflow.
  if (dimension >= op.getNumLoops())
    return failure();

  // The code below works only on values.
  Location loc = op.getLoc();
  ImplicitLocOpBuilder b(loc, builder);
  if (emitAssertions) {
    emitIsPositiveIndexAssertion(b, targetSize);
    emitIsPositiveIndexAssertion(b, divisor);
  }
  Value targetSizeValue =
      getValueOrCreateConstantIndexOp(builder, loc, targetSize);
  Value divisorValue = getValueOrCreateConstantIndexOp(builder, loc, divisor);

  // Find the trip count of the iteration space dimension for which the tile
  // sizes are computed.
  SmallVector<OpFoldResult> allShapes =
      op.createFlatListOfOperandDims(b, b.getLoc());
  AffineMap shapesToLoops = op.getShapesToLoopsMap();
  SmallVector<OpFoldResult> loopRanges =
      makeComposedFoldedMultiResultAffineApply(b, op.getLoc(), shapesToLoops,
                                               allShapes);
  Value tripCount =
      getValueOrCreateConstantIndexOp(b, op.getLoc(), loopRanges[dimension]);

  // Compute the tile sizes and the respective numbers of tiles.
  AffineExpr s0 = b.getAffineSymbolExpr(0);
  AffineExpr s1 = b.getAffineSymbolExpr(1);
  AffineExpr s2 = b.getAffineSymbolExpr(2);
  auto apply = [&](AffineExpr expr, ArrayRef<OpFoldResult> ofrs) -> Value {
    return affine::makeComposedAffineApply(b, b.getLoc(), expr, ofrs);
  };
  Value a = apply(s0.floorDiv(s1), {tripCount, divisorValue});
  Value t = apply((s0 + s1 - 1).floorDiv(s1), {targetSizeValue, divisorValue});
  Value d = apply((s0 + s1 - 1).floorDiv(s1), {a, t});
  Value s = apply(s0.floorDiv(s1) * s2, {a, d, divisorValue});
  Value v = apply(s0 % s1, {a, d});
  Value u = apply(s0 - s1, {d, v});

  MultiSizeSpecification spec;
  spec.lowTileSize = s;
  spec.highTileSize = apply(s0 + s1, {s, divisorValue});
  spec.lowTripCount = u;
  spec.highTripCount = v;

  // If requested, emit the check that the tile sizes are computed correctly.
  // For example, for iteration dimension size of 15 and the target size 8 it is
  // impossible to find two tile sizes both divisible by 8 that fully cover the
  // original space dimension.
  if (emitAssertions) {
    AffineExpr s3 = builder.getAffineSymbolExpr(3);
    Value coveredSize =
        apply(s0 * s1 + s2 * s3, {spec.lowTileSize, spec.lowTripCount,
                                  spec.highTileSize, spec.highTripCount});
    Value equals = arith::CmpIOp::create(b, arith::CmpIPredicate::eq,
                                         coveredSize, tripCount);
    cf::AssertOp::create(
        b, equals,
        builder.getStringAttr(
            "could not compute dynamic multi-size tile shapes"));
  }

  return spec;
}

/// Returns true if the maximum tile offset `tileSize * numThreads-1` is less
/// than `iterationSize`.
static bool canOmitTileOffsetInBoundsCheck(OpFoldResult tileSize,
                                           OpFoldResult numThreads,
                                           OpFoldResult iterationSize) {
  std::optional<int64_t> tileSizeConst = getConstantIntValue(tileSize);
  std::optional<int64_t> numThreadsConst = getConstantIntValue(numThreads);
  std::optional<int64_t> iterSizeConst = getConstantIntValue(iterationSize);
  if (!tileSizeConst || !numThreadsConst || !iterSizeConst)
    return false;
  return *tileSizeConst * (*numThreadsConst - 1) < *iterSizeConst;
}

/// Build an `affine_max` of all the `vals`.
static OpFoldResult buildMax(OpBuilder &b, Location loc,
                             ArrayRef<OpFoldResult> vals) {
  return affine::makeComposedFoldedAffineMax(
      b, loc, AffineMap::getMultiDimIdentityMap(vals.size(), loc.getContext()),
      vals);
}

/// Build an `affine_min` of all the `vals`.
static OpFoldResult buildMin(OpBuilder &b, Location loc,
                             ArrayRef<OpFoldResult> vals) {
  return affine::makeComposedFoldedAffineMin(
      b, loc, AffineMap::getMultiDimIdentityMap(vals.size(), loc.getContext()),
      vals);
}

/// Fill out the `tiledOffsets` and `tiledSizes` to be used to tile to a given
/// number of threads.
static void calculateTileOffsetsAndSizes(
    RewriterBase &b, Location loc, scf::ForallOp forallOp,
    ArrayRef<OpFoldResult> numThreads, SmallVector<Range> loopRanges,
    bool omitTileOffsetBoundsCheck,
    std::optional<ArrayRef<OpFoldResult>> nominalTileSizes,
    SmallVector<OpFoldResult> &tiledOffsets,
    SmallVector<OpFoldResult> &tiledSizes) {
  OpBuilder::InsertionGuard g(b);
  b.setInsertionPointToStart(forallOp.getBody(0));

  SmallVector<Value> threadIds = forallOp.getInductionVars();
  SmallVector<OpFoldResult> nonZeroNumThreads = llvm::filter_to_vector(
      numThreads, [](OpFoldResult ofr) { return !isZeroInteger(ofr); });
  int64_t nLoops = loopRanges.size();
  tiledOffsets.reserve(nLoops);
  tiledSizes.reserve(nLoops);
  for (unsigned loopIdx = 0, threadIdIdx = 0; loopIdx < nLoops; ++loopIdx) {
    bool overflow = loopIdx >= numThreads.size();
    bool isZero = !overflow && isZeroInteger(numThreads[loopIdx]);
    // Degenerate case: take the whole domain.
    if (overflow || isZero) {
      tiledOffsets.push_back(loopRanges[loopIdx].offset);
      tiledSizes.push_back(loopRanges[loopIdx].size);
      continue;
    }

    // Tiled case: compute the offset and size.
    AffineExpr i, j, m, n, o;
    bindDims(b.getContext(), i, j);
    bindSymbols(b.getContext(), m, n, o);
    OpFoldResult size = loopRanges[loopIdx].size;
    OpFoldResult offset = loopRanges[loopIdx].offset;
    OpFoldResult threadId = threadIds[threadIdIdx];
    // Symbolic fixed max size per thread.
    // TODO: floor + 0/1 depending on case for better load-balancing.
    OpFoldResult tileSizePerThread =
        nominalTileSizes.has_value()
            ? (*nominalTileSizes)[loopIdx]
            : makeComposedFoldedAffineApply(
                  b, loc, m.ceilDiv(n),
                  ArrayRef<OpFoldResult>{size, nonZeroNumThreads[threadIdIdx]});

    // Dynamic offset shifted by threadId * maxSizePerThread.
    OpFoldResult offsetPerThread = makeComposedFoldedAffineApply(
        b, loc, i + j * m, {offset, threadId, tileSizePerThread});
    // Dynamic upper-bound depending on the threadId.
    OpFoldResult residualTileSize = makeComposedFoldedAffineApply(
        b, loc, i + j * m - n,
        {offset, nonZeroNumThreads[threadIdIdx], tileSizePerThread, size});
    if (!isZeroInteger(residualTileSize)) {
      OpFoldResult sizeMinusOffsetPerThread = makeComposedFoldedAffineApply(
          b, loc, -i + m, {offsetPerThread, size});
      tileSizePerThread =
          buildMin(b, loc, {sizeMinusOffsetPerThread, tileSizePerThread});
    }

    tiledOffsets.push_back(offsetPerThread);
    // TODO: if tileSizePerThread <= 0 early exit.
    if (!omitTileOffsetBoundsCheck &&
        !canOmitTileOffsetInBoundsCheck(tileSizePerThread,
                                        nonZeroNumThreads[threadIdIdx], size))
      tileSizePerThread =
          buildMax(b, loc, {b.getIndexAttr(0), tileSizePerThread});

    tiledSizes.push_back(tileSizePerThread);
    ++threadIdIdx;
  }
}

template <typename LoopTy>
static FailureOr<TiledLinalgOp>
tileLinalgOpImpl(RewriterBase &b, LinalgOp op, ArrayRef<OpFoldResult> tileSizes,
                 const LinalgTilingOptions &options) {
  OpBuilder::InsertionGuard g(b);

  auto nLoops = op.getNumLoops();
  // Initial tile sizes may be too big, only take the first nLoops.
  tileSizes = tileSizes.take_front(nLoops);

  if (llvm::all_of(tileSizes, [](OpFoldResult ofr) {
        return getConstantIntValue(ofr) == static_cast<int64_t>(0);
      })) {
    TiledLinalgOp tiledOp;
    tiledOp.op = cast<LinalgOp>(b.clone(*op.getOperation()));
    tiledOp.tensorResults.assign(tiledOp.op->result_begin(),
                                 tiledOp.op->result_end());
    return tiledOp;
  }

  // 1. Build the tiled loop ranges.
  SmallVector<OpFoldResult> allShapeSizes =
      op.createFlatListOfOperandDims(b, op.getLoc());
  AffineMap shapeSizesToLoopsMap = op.getShapesToLoopsMap();
  if (!shapeSizesToLoopsMap)
    return failure();

  auto [loopRanges, loopIndexToRangeIndex] = makeTiledLoopRanges(
      b, op.getLoc(), shapeSizesToLoopsMap, allShapeSizes, tileSizes);

  SmallVector<utils::IteratorType, 4> iteratorTypes;
  for (const auto &attr : enumerate(op.getIteratorTypesArray())) {
    if (loopIndexToRangeIndex.count(attr.index()))
      iteratorTypes.push_back(attr.value());
  }
  // If interchangeVector is empty, use the identity. Build the permutation map
  // otherwise.
  auto invPermutationMap =
      AffineMap::getMultiDimIdentityMap(tileSizes.size(), b.getContext());
  if (!options.interchangeVector.empty()) {
    // Based on the pruned iterations (due to zero tile size), recompute the
    // interchange vector.
    SmallVector<unsigned, 4> interchangeVector;
    interchangeVector.reserve(options.interchangeVector.size());
    for (auto pos : options.interchangeVector) {
      auto it = loopIndexToRangeIndex.find(pos);
      if (it == loopIndexToRangeIndex.end())
        continue;
      interchangeVector.push_back(it->second);
    }
    // Interchange vector is guaranteed to be a permutation,
    // `inversePermutation` must succeed.
    invPermutationMap = inversePermutation(
        AffineMap::getPermutationMap(interchangeVector, b.getContext()));
    assert(invPermutationMap);
    SmallVector<int64_t> permutation(interchangeVector.begin(),
                                     interchangeVector.end());
    applyPermutationToVector(loopRanges, permutation);
    applyPermutationToVector(iteratorTypes, permutation);
  }

  // Handle distribution. Create a vector of the same size of loops that are to
  // be tiled.
  SmallVector<linalg::ProcInfo> procInfo;
  if (options.distribution) {
    procInfo.resize(
        iteratorTypes.size(),
        linalg::ProcInfo{nullptr, nullptr, linalg::DistributionMethod::None});
    // Collect loop ranges of tiled loops, loops that are parallel.
    SmallVector<Range> parallelLoopRanges;
    for (const auto &iteratorType : llvm::enumerate(iteratorTypes)) {
      if (!isParallelIterator(iteratorType.value()))
        break;
      parallelLoopRanges.push_back(loopRanges[iteratorType.index()]);
    }
    auto returnedProcInfo =
        options.distribution->procInfo(b, op.getLoc(), parallelLoopRanges);
    unsigned procIdIdx = 0;
    // Update the distribution information for the loops.
    for (const auto &iteratorType : llvm::enumerate(iteratorTypes)) {
      if (!isParallelIterator(iteratorType.value()))
        break;
      procInfo[iteratorType.index()] = returnedProcInfo[procIdIdx++];
    }
  }

  // 2. Create the tiled loops.
  LinalgOp res = op;
  SmallVector<Value, 4> ivs, tensorResults;
  auto tiledLoopBodyBuilder =
      [&](OpBuilder &builder, Location loc, ValueRange localIvs,
          ValueRange operandValuesToUse) -> scf::ValueVector {
    ivs.assign(localIvs.begin(), localIvs.end());

    // When an `interchangeVector` is present, it has been applied to the
    // loop ranges and the iterator types. Apply its inverse to the
    // resulting loop `ivs` to match the op definition.
    SmallVector<Value, 4> interchangedIvs;
    if (!options.interchangeVector.empty()) {
      for (AffineExpr result : invPermutationMap.getResults())
        interchangedIvs.push_back(
            ivs[cast<AffineDimExpr>(result).getPosition()]);
    } else {
      interchangedIvs.assign(ivs.begin(), ivs.end());
    }

    // Tile the `operandValuesToUse` that either match the `op` operands
    // themselves or the tile loop arguments forwarding them.
    assert(operandValuesToUse.size() ==
               static_cast<size_t>(op->getNumOperands()) &&
           "expect the number of operands and inputs and outputs to match");
    SmallVector<Value> valuesToTile = operandValuesToUse;
    SmallVector<OpFoldResult> sizeBounds =
        makeComposedFoldedMultiResultAffineApply(b, loc, shapeSizesToLoopsMap,
                                                 allShapeSizes);
    SmallVector<Value> tiledOperands = makeTiledShapes(
        b, loc, op, valuesToTile, getAsOpFoldResult(interchangedIvs), tileSizes,
        sizeBounds,
        /*omitPartialTileCheck=*/false);

    SmallVector<Type> resultTensorTypes =
        getTensorOutputTypes(op, tiledOperands);
    res = clone(b, op, resultTensorTypes, tiledOperands);
    tensorResults =
        insertSlicesBack(builder, loc, op, tiledOperands, res->getResults());
    return scf::ValueVector(tensorResults.begin(), tensorResults.end());
  };
  GenerateLoopNest<LoopTy>::doit(b, op.getLoc(), loopRanges, op, iteratorTypes,
                                 tiledLoopBodyBuilder, procInfo);

  // 3. Transform IndexOp results w.r.t. the tiling.
  transformIndexOps(b, res, ivs, loopIndexToRangeIndex);

  // 4. Gather the newly created loops and return them with the new op.
  SmallVector<Operation *, 8> loops;
  loops.reserve(ivs.size());
  for (auto iv : ivs) {
    if (isa<BlockArgument>(iv)) {
      loops.push_back(cast<BlockArgument>(iv).getOwner()->getParentOp());
      assert(loops.back() && "no owner found for induction variable!");
    } else {
      // TODO: Instead of doing this, try to recover the ops used instead of the
      // loop.
      loops.push_back(nullptr);
    }
  }

  // 5. Get the tensor results from the outermost loop if available. Otherwise
  // use the previously captured `tensorResults`.
  Operation *outermostLoop = nullptr;
  for (Operation *loop : loops)
    if ((outermostLoop = loop))
      break;

  return TiledLinalgOp{
      res, loops, outermostLoop ? outermostLoop->getResults() : tensorResults};
}

FailureOr<linalg::ForallReductionTilingResult> linalg::tileReductionUsingForall(
    RewriterBase &b, PartialReductionOpInterface op,
    ArrayRef<OpFoldResult> numThreads, ArrayRef<OpFoldResult> tileSizes,
    std::optional<ArrayAttr> mapping) {
  Location loc = op.getLoc();
  OpBuilder::InsertionGuard g(b);

  // Ops implementing PartialReductionOpInterface are expected to implement
  // TilingInterface.
  // TODO: proper core mechanism to tie interfaces together.
  auto tilingInterfaceOp = cast<TilingInterface>(op.getOperation());

  // Ops implementing PartialReductionOpInterface are not necessarily expected
  // to implement TilingInterface.. This cast is unsafe atm.
  // TODO: proper core mechanism to tie interfaces together.
  // TODO: this function requires a pair of interfaces ..
  auto destinationStyleOp =
      dyn_cast<DestinationStyleOpInterface>(op.getOperation());
  if (!destinationStyleOp)
    return b.notifyMatchFailure(op, "not a destination style op");

  // Actually this only work for Linalg ops atm.
  auto linalgOp = dyn_cast<linalg::LinalgOp>(op.getOperation());
  if (!linalgOp)
    return b.notifyMatchFailure(op, "not a linalg op");

  SmallVector<Range> iterationDomain = tilingInterfaceOp.getIterationDomain(b);
  if (op->getNumResults() != 1)
    return b.notifyMatchFailure(
        op, "don't support ops with multiple results for now");

  SmallVector<utils::IteratorType> iterators =
      tilingInterfaceOp.getLoopIteratorTypes();
  SmallVector<unsigned> redDims;
  linalgOp.getReductionDims(redDims);
  if (redDims.size() != 1)
    return b.notifyMatchFailure(
        op, "only support ops with one reduction dimension.");
  if (!tileSizes.empty() && tileSizes.size() != numThreads.size())
    return b.notifyMatchFailure(op, "if tile sizes are present it must have as "
                                    "many elements as number of threads");

  if (redDims.front() >= numThreads.size())
    return b.notifyMatchFailure(
        op, "reduction dimension must be mapped to threads");

  // 1. Create the inital tensor value.
  unsigned reductionDim = redDims.front();
  SetVector<unsigned> reductionDims;
  reductionDims.insert(reductionDim);
  FailureOr<SmallVector<Value>> maybeInitTensors =
      op.generateInitialTensorForPartialReduction(b, loc, numThreads,
                                                  reductionDims);
  if (failed(maybeInitTensors))
    return b.notifyMatchFailure(
        op, "Failed to create inital tensors for partial reduction");
  SmallVector<Value> &initTensors = maybeInitTensors.value();

  // Gather destination tensors.
  SmallVector<Value> dest;
  if (failed(tensor::getOrCreateDestinations(b, loc, op, dest)))
    return b.notifyMatchFailure(op, "failed to get destination tensors");

  Operation *tiledOp = nullptr;

  SmallVector<OpFoldResult> nonZeroNumThreads = llvm::filter_to_vector(
      numThreads, [](OpFoldResult ofr) { return !isZeroInteger(ofr); });
  SmallVector<Value> materializedNonZeroNumThreads =
      getValueOrCreateConstantIndexOp(b, loc, nonZeroNumThreads);

  // 2. Create the ForallOp with an empty region.
  scf::ForallOp forallOp = scf::ForallOp::create(
      b, loc, getAsOpFoldResult(materializedNonZeroNumThreads), initTensors,
      mapping);

  // 3. Calculate the tile offsets and sizes for the subsequent loop that will
  // be nested under `forallOp`.
  SmallVector<OpFoldResult> tiledOffsets, tiledSizes;
  calculateTileOffsetsAndSizes(b, loc, forallOp, numThreads, iterationDomain,
                               /*omitTileOffsetBoundsCheck =*/false,
                               /*nominalTileSizes=*/std::nullopt, tiledOffsets,
                               tiledSizes);

  // 4b. Clone the tileable op and update its destination operands to use the
  // output bbArgs of the ForallOp.
  SmallVector<Value> tilingResults;
  ArrayRef<BlockArgument> destBbArgs = forallOp.getRegionIterArgs();
  {
    // 4.a. RAII guard, inserting within forallOp, before terminator.
    OpBuilder::InsertionGuard g(b);
    b.setInsertionPoint(forallOp.getTerminator());

    SmallVector<Value> tiledDpsInitOperands;
    for (Value initOperand : destinationStyleOp.getDpsInits()) {
      auto *it = llvm::find(dest, initOperand);
      assert(it != dest.end() && "dest operand not found in dest");
      unsigned destNum = std::distance(dest.begin(), it);
      SmallVector<OpFoldResult> strides(numThreads.size(), b.getIndexAttr(1));
      SmallVector<OpFoldResult> outOffsets(numThreads.size(),
                                           b.getIndexAttr(0));
      SmallVector<OpFoldResult> sizes = tiledSizes;
      sizes[reductionDim] = b.getIndexAttr(1);
      outOffsets[reductionDim] = forallOp.getInductionVars()[0];
      // TODO: use SubsetExtractOpInterface once it is available.
      tiledDpsInitOperands.push_back(tensor::ExtractSliceOp::create(
          b, loc, cast<RankedTensorType>(initOperand.getType()),
          destBbArgs[destNum], outOffsets, sizes, strides));
    }

    // 4.b. Clone the op and update init operands.
    // We cannot use a IRMapping here because it can replace
    // different OpOperands with the same value.
    Operation *clonedOp = b.clone(*op.getOperation());
    b.modifyOpInPlace(clonedOp, [&]() {
      for (auto [initOperandPtr, tiledInitValue] : llvm::zip_equal(
               cast<DestinationStyleOpInterface>(clonedOp).getDpsInitsMutable(),
               tiledDpsInitOperands)) {
        initOperandPtr.set(tiledInitValue);
      }
    });

    // 5. Tile the cloned op and delete the clone.
    if (tileSizes.empty()) {
      FailureOr<TilingResult> tilingResult =
          cast<TilingInterface>(clonedOp).getTiledImplementation(
              b, tiledOffsets, tiledSizes);
      if (failed(tilingResult))
        return clonedOp->emitError("Failed to tile op: ");
      if (tilingResult->tiledOps.size() != 1) {
        return clonedOp->emitError("expected a single produced tiled op, got ")
               << tilingResult->tiledOps.size();
      }
      tiledOp = tilingResult->tiledOps.front();
      tilingResults = tilingResult->tiledValues;
    } else {
      LinalgTilingOptions options;
      FailureOr<TiledLinalgOp> maybeTiled = tileLinalgOpImpl<scf::ForOp>(
          b, cast<LinalgOp>(clonedOp), tileSizes, options);
      if (failed(maybeTiled))
        return b.notifyMatchFailure(op, "failed tileLinalgOpImpl");

      SmallVector<Value> ids = forallOp.getInductionVars();
      mapLoopToProcessorIds(cast<scf::ForOp>(maybeTiled->loops.back()), ids,
                            materializedNonZeroNumThreads);
      if (maybeTiled->loops.size() != 1) {
        return clonedOp->emitError("expected a single produced loop");
      }
      tiledOp = maybeTiled->op;
      tilingResults = maybeTiled->loops.front()->getResults();
    }

    b.eraseOp(clonedOp);
  }

  // 6. Insert the partial reductions back into a new tensor.
  for (auto [index, result, bbArg] : llvm::zip(
           llvm::seq<unsigned>(0, dest.size()), tilingResults, destBbArgs)) {
    // 6.a. Partial subset information is inserted just before the terminator.
    OpBuilder::InsertionGuard g(b);
    b.setInsertionPoint(forallOp.getTerminator());

    SmallVector<OpFoldResult> resultOffsets, resultSizes;
    if (failed(tilingInterfaceOp.getResultTilePosition(
            b, index, tiledOffsets, tiledSizes, resultOffsets, resultSizes)))
      return op->emitOpError("output offsets couldn't be calculated");
    SmallVector<OpFoldResult> resultOffsetsRank, resultSizesRank;
    int64_t offIdx = 0;
    int64_t sizeIdx = 0;
    for (int64_t i = 0, e = numThreads.size(); i < e; ++i) {
      if (i == reductionDim) {
        resultOffsetsRank.push_back(forallOp.getInductionVars()[0]);
        resultSizesRank.push_back(b.getIndexAttr(1));
        continue;
      }
      resultOffsetsRank.push_back(resultOffsets[offIdx++]);
      resultSizesRank.push_back(resultSizes[sizeIdx++]);
    }
    SmallVector<OpFoldResult> strides(resultSizesRank.size(),
                                      b.getIndexAttr(1));

    // 6.b. Parallel insertions are inserted at the end of the combining
    // terminator.
    b.setInsertionPointToEnd(forallOp.getTerminator().getBody());
    tensor::ParallelInsertSliceOp::create(
        b, loc, result, bbArg, resultOffsetsRank, resultSizesRank, strides);
  }

  // 7. Merge the partial reductions.
  b.setInsertionPointAfter(forallOp);
  FailureOr<MergeResult> mergeResult =
      op.mergeReductions(b, loc, forallOp->getResults(), reductionDims);
  if (failed(mergeResult)) {
    return failure();
  }
  b.replaceOp(op, mergeResult->replacements);

  // 8. Return.
  ForallReductionTilingResult results;
  results.initialValues = initTensors;
  results.loops = forallOp;
  results.parallelTiledOps.push_back(tiledOp);
  results.mergeOps.append(mergeResult->mergeOps);
  return results;
}

template <typename LoopTy>
FailureOr<TiledLinalgOp> static tileLinalgOpImpl(
    RewriterBase &b, LinalgOp op, const LinalgTilingOptions &options) {
  OpBuilder::InsertionGuard g(b);
  b.setInsertionPoint(op);

  if (!options.tileSizeComputationFunction)
    return failure();

  // Enforce the convention that "tiling by zero" skips tiling a particular
  // dimension. This convention is significantly simpler to handle instead of
  // adjusting affine maps to account for missing dimensions.
  auto nLoops = op.getNumLoops();
  SmallVector<OpFoldResult> tileSizeVector =
      getAsOpFoldResult(options.tileSizeComputationFunction(b, op));
  if (tileSizeVector.size() < nLoops) {
    tileSizeVector.append(nLoops - tileSizeVector.size(), b.getIndexAttr(0));
  }

  return tileLinalgOpImpl<LoopTy>(b, op, tileSizeVector, options);
}

FailureOr<TiledLinalgOp>
mlir::linalg::tileLinalgOp(RewriterBase &b, LinalgOp op,
                           const LinalgTilingOptions &options) {
  switch (options.loopType) {
  case LinalgTilingLoopType::Loops:
    return tileLinalgOpImpl<scf::ForOp>(b, op, options);
  case LinalgTilingLoopType::ParallelLoops:
    return tileLinalgOpImpl<scf::ParallelOp>(b, op, options);
  default:;
  }
  return failure();
}

namespace {
/// Helper classes for type list expansion.
template <typename... OpTypes>
class CanonicalizationPatternList;

template <>
class CanonicalizationPatternList<> {
public:
  static void insert(RewritePatternSet &patterns) {}
};

template <typename OpTy, typename... OpTypes>
class CanonicalizationPatternList<OpTy, OpTypes...> {
public:
  static void insert(RewritePatternSet &patterns) {
    OpTy::getCanonicalizationPatterns(patterns, patterns.getContext());
    CanonicalizationPatternList<OpTypes...>::insert(patterns);
  }
};
} // namespace

RewritePatternSet
mlir::linalg::getLinalgTilingCanonicalizationPatterns(MLIRContext *ctx) {
  RewritePatternSet patterns(ctx);
  populateLinalgTilingCanonicalizationPatterns(patterns);
  return patterns;
}

void mlir::linalg::populateLinalgTilingCanonicalizationPatterns(
    RewritePatternSet &patterns) {
  auto *ctx = patterns.getContext();
  affine::AffineApplyOp::getCanonicalizationPatterns(patterns, ctx);
  affine::AffineForOp::getCanonicalizationPatterns(patterns, ctx);
  affine::AffineMinOp::getCanonicalizationPatterns(patterns, ctx);
  affine::AffineMaxOp::getCanonicalizationPatterns(patterns, ctx);
  arith::ConstantIndexOp::getCanonicalizationPatterns(patterns, ctx);

  memref::SubViewOp::getCanonicalizationPatterns(patterns, ctx);
  memref::ViewOp::getCanonicalizationPatterns(patterns, ctx);

  scf::ForOp::getCanonicalizationPatterns(patterns, ctx);
  scf::ParallelOp::getCanonicalizationPatterns(patterns, ctx);

  tensor::CastOp::getCanonicalizationPatterns(patterns, ctx);
  tensor::EmptyOp::getCanonicalizationPatterns(patterns, ctx);
  tensor::ExtractSliceOp::getCanonicalizationPatterns(patterns, ctx);
  tensor::InsertSliceOp::getCanonicalizationPatterns(patterns, ctx);
  tensor::PadOp::getCanonicalizationPatterns(patterns, ctx);
  ctx->getLoadedDialect<LinalgDialect>()->getCanonicalizationPatterns(patterns);

  CanonicalizationPatternList<
#define GET_OP_LIST
#include "mlir/Dialect/Linalg/IR/LinalgStructuredOps.cpp.inc"
      >::insert(patterns);
}
