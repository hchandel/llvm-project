// NOTE: Assertions have been autogenerated by utils/update_cc_test_checks.py
// RUN: %clang_cc1 -triple thumbv8.1m.main-none-none-eabi -target-feature +mve.fp -mfloat-abi hard -disable-O0-optnone -emit-llvm -o - %s | opt -S -passes=mem2reg | FileCheck %s
// RUN: %clang_cc1 -triple thumbv8.1m.main-none-none-eabi -target-feature +mve.fp -mfloat-abi hard -disable-O0-optnone -DPOLYMORPHIC -emit-llvm -o - %s | opt -S -passes=mem2reg | FileCheck %s

// REQUIRES: aarch64-registered-target || arm-registered-target

#include <arm_mve.h>

// CHECK-LABEL: @_Z16test_vbicq_n_s1617__simd128_int16_t(
// CHECK-NEXT:  entry:
// CHECK-NEXT:    [[TMP0:%.*]] = and <8 x i16> [[A:%.*]], splat (i16 11007)
// CHECK-NEXT:    ret <8 x i16> [[TMP0]]
//
int16x8_t test_vbicq_n_s16(int16x8_t a)
{
#ifdef POLYMORPHIC
    return vbicq(a, 0xd500);
#else /* POLYMORPHIC */
    return vbicq_n_s16(a, 0xd500);
#endif /* POLYMORPHIC */
}

// CHECK-LABEL: @_Z16test_vbicq_n_u3218__simd128_uint32_t(
// CHECK-NEXT:  entry:
// CHECK-NEXT:    [[TMP0:%.*]] = and <4 x i32> [[A:%.*]], splat (i32 -8193)
// CHECK-NEXT:    ret <4 x i32> [[TMP0]]
//
uint32x4_t test_vbicq_n_u32(uint32x4_t a)
{
#ifdef POLYMORPHIC
    return vbicq(a, 0x2000);
#else /* POLYMORPHIC */
    return vbicq_n_u32(a, 0x2000);
#endif /* POLYMORPHIC */
}

// CHECK-LABEL: @_Z16test_vorrq_n_s3217__simd128_int32_t(
// CHECK-NEXT:  entry:
// CHECK-NEXT:    [[TMP0:%.*]] = or <4 x i32> [[A:%.*]], splat (i32 65536)
// CHECK-NEXT:    ret <4 x i32> [[TMP0]]
//
int32x4_t test_vorrq_n_s32(int32x4_t a)
{
#ifdef POLYMORPHIC
    return vorrq(a, 0x10000);
#else /* POLYMORPHIC */
    return vorrq_n_s32(a, 0x10000);
#endif /* POLYMORPHIC */
}

// CHECK-LABEL: @_Z16test_vorrq_n_u1618__simd128_uint16_t(
// CHECK-NEXT:  entry:
// CHECK-NEXT:    [[TMP0:%.*]] = or <8 x i16> [[A:%.*]], splat (i16 -4096)
// CHECK-NEXT:    ret <8 x i16> [[TMP0]]
//
uint16x8_t test_vorrq_n_u16(uint16x8_t a)
{
#ifdef POLYMORPHIC
    return vorrq(a, 0xf000);
#else /* POLYMORPHIC */
    return vorrq_n_u16(a, 0xf000);
#endif /* POLYMORPHIC */
}

// CHECK-LABEL: @_Z16test_vcmpeqq_f1619__simd128_float16_tS_(
// CHECK-NEXT:  entry:
// CHECK-NEXT:    [[TMP0:%.*]] = fcmp oeq <8 x half> [[A:%.*]], [[B:%.*]]
// CHECK-NEXT:    [[TMP1:%.*]] = call i32 @llvm.arm.mve.pred.v2i.v8i1(<8 x i1> [[TMP0]])
// CHECK-NEXT:    [[TMP2:%.*]] = trunc i32 [[TMP1]] to i16
// CHECK-NEXT:    ret i16 [[TMP2]]
//
mve_pred16_t test_vcmpeqq_f16(float16x8_t a, float16x8_t b)
{
#ifdef POLYMORPHIC
    return vcmpeqq(a, b);
#else /* POLYMORPHIC */
    return vcmpeqq_f16(a, b);
#endif /* POLYMORPHIC */
}

// CHECK-LABEL: @_Z18test_vcmpeqq_n_f1619__simd128_float16_tDh(
// CHECK-NEXT:  entry:
// CHECK-NEXT:    [[DOTSPLATINSERT:%.*]] = insertelement <8 x half> poison, half [[B:%.*]], i64 0
// CHECK-NEXT:    [[DOTSPLAT:%.*]] = shufflevector <8 x half> [[DOTSPLATINSERT]], <8 x half> poison, <8 x i32> zeroinitializer
// CHECK-NEXT:    [[TMP0:%.*]] = fcmp oeq <8 x half> [[A:%.*]], [[DOTSPLAT]]
// CHECK-NEXT:    [[TMP1:%.*]] = call i32 @llvm.arm.mve.pred.v2i.v8i1(<8 x i1> [[TMP0]])
// CHECK-NEXT:    [[TMP2:%.*]] = trunc i32 [[TMP1]] to i16
// CHECK-NEXT:    ret i16 [[TMP2]]
//
mve_pred16_t test_vcmpeqq_n_f16(float16x8_t a, float16_t b)
{
#ifdef POLYMORPHIC
    return vcmpeqq(a, b);
#else /* POLYMORPHIC */
    return vcmpeqq_n_f16(a, b);
#endif /* POLYMORPHIC */
}

// CHECK-LABEL: @_Z14test_vld1q_u16PKt(
// CHECK-NEXT:  entry:
// CHECK-NEXT:    [[TMP0:%.*]] = load <8 x i16>, ptr [[BASE:%.*]], align 2
// CHECK-NEXT:    ret <8 x i16> [[TMP0]]
//
uint16x8_t test_vld1q_u16(const uint16_t *base)
{
#ifdef POLYMORPHIC
    return vld1q(base);
#else /* POLYMORPHIC */
    return vld1q_u16(base);
#endif /* POLYMORPHIC */
}

// CHECK-LABEL: @_Z16test_vst1q_p_s32Pi17__simd128_int32_tt(
// CHECK-NEXT:  entry:
// CHECK-NEXT:    [[TMP0:%.*]] = zext i16 [[P:%.*]] to i32
// CHECK-NEXT:    [[TMP1:%.*]] = call <4 x i1> @llvm.arm.mve.pred.i2v.v4i1(i32 [[TMP0]])
// CHECK-NEXT:    call void @llvm.masked.store.v4i32.p0(<4 x i32> [[VALUE:%.*]], ptr [[BASE:%.*]], i32 4, <4 x i1> [[TMP1]])
// CHECK-NEXT:    ret void
//
void test_vst1q_p_s32(int32_t *base, int32x4_t value, mve_pred16_t p)
{
#ifdef POLYMORPHIC
    vst1q_p(base, value, p);
#else /* POLYMORPHIC */
    vst1q_p_s32(base, value, p);
#endif /* POLYMORPHIC */
}

// CHECK-LABEL: @_Z30test_vldrdq_gather_base_wb_s64P18__simd128_uint64_t(
// CHECK-NEXT:  entry:
// CHECK-NEXT:    [[TMP0:%.*]] = load <2 x i64>, ptr [[ADDR:%.*]], align 8
// CHECK-NEXT:    [[TMP1:%.*]] = call { <2 x i64>, <2 x i64> } @llvm.arm.mve.vldr.gather.base.wb.v2i64.v2i64(<2 x i64> [[TMP0]], i32 576)
// CHECK-NEXT:    [[TMP2:%.*]] = extractvalue { <2 x i64>, <2 x i64> } [[TMP1]], 1
// CHECK-NEXT:    store <2 x i64> [[TMP2]], ptr [[ADDR]], align 8
// CHECK-NEXT:    [[TMP3:%.*]] = extractvalue { <2 x i64>, <2 x i64> } [[TMP1]], 0
// CHECK-NEXT:    ret <2 x i64> [[TMP3]]
//
int64x2_t test_vldrdq_gather_base_wb_s64(uint64x2_t *addr)
{
    return vldrdq_gather_base_wb_s64(addr, 0x240);
}

// CHECK-LABEL: @_Z31test_vstrwq_scatter_base_wb_u32P18__simd128_uint32_tS_(
// CHECK-NEXT:  entry:
// CHECK-NEXT:    [[TMP0:%.*]] = load <4 x i32>, ptr [[ADDR:%.*]], align 8
// CHECK-NEXT:    [[TMP1:%.*]] = call <4 x i32> @llvm.arm.mve.vstr.scatter.base.wb.v4i32.v4i32(<4 x i32> [[TMP0]], i32 64, <4 x i32> [[VALUE:%.*]])
// CHECK-NEXT:    store <4 x i32> [[TMP1]], ptr [[ADDR]], align 8
// CHECK-NEXT:    ret void
//
void test_vstrwq_scatter_base_wb_u32(uint32x4_t *addr, uint32x4_t value)
{
#ifdef POLYMORPHIC
    vstrwq_scatter_base_wb(addr, 0x40, value);
#else /* POLYMORPHIC */
    vstrwq_scatter_base_wb_u32(addr, 0x40, value);
#endif /* POLYMORPHIC */
}
