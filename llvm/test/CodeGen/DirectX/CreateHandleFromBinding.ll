; RUN: opt -S -passes=dxil-translate-metadata,dxil-op-lower %s | FileCheck %s
; RUN: opt -S -passes=dxil-pretty-printer %s 2>&1 >/dev/null | FileCheck --check-prefix=CHECK-PRETTY %s

; CHECK-PRETTY:       Type  Format         Dim      ID      HLSL Bind     Count
; CHECK-PRETTY: ---------- ------- ----------- ------- -------------- ---------
; CHECK-PRETTY:    texture     f32         buf      T0      t7        unbounded
; CHECK-PRETTY:    texture    byte         r/o      T1      t8,space1         1
; CHECK-PRETTY:    texture  struct         r/o      T2      t2,space4         1
; CHECK-PRETTY:    texture     u32         buf      T3      t3,space5        24
; CHECK-PRETTY:        UAV     i32         buf      U0      u7,space2         1
; CHECK-PRETTY:        UAV     f32         buf      U1      u5,space3         1
; CHECK-PRETTY:    cbuffer      NA          NA     CB0            cb0         1

target triple = "dxil-pc-shadermodel6.6-compute"

declare i32 @some_val();

define void @test_bindings() {
  ; RWBuffer<float4> Buf : register(u5, space3)
  %typed0 = call target("dx.TypedBuffer", <4 x float>, 1, 0, 0)
              @llvm.dx.resource.handlefrombinding.tdx.TypedBuffer_v4f32_1_0_0(
                  i32 3, i32 5, i32 1, i32 0, i1 false)
  ; CHECK: [[BUF0:%.*]] = call %dx.types.Handle @dx.op.createHandleFromBinding(i32 217, %dx.types.ResBind { i32 5, i32 5, i32 3, i8 1 }, i32 5, i1 false) #[[#ATTR:]]
  ; CHECK: call %dx.types.Handle @dx.op.annotateHandle(i32 216, %dx.types.Handle [[BUF0]], %dx.types.ResourceProperties { i32 4106, i32 1033 }) #[[#ATTR]]

  ; RWBuffer<int> Buf : register(u7, space2)
  %typed1 = call target("dx.TypedBuffer", i32, 1, 0, 1)
      @llvm.dx.resource.handlefrombinding.tdx.TypedBuffer_i32_1_0_0t(
          i32 2, i32 7, i32 1, i32 0, i1 false)
  ; CHECK: [[BUF1:%.*]] = call %dx.types.Handle @dx.op.createHandleFromBinding(i32 217, %dx.types.ResBind { i32 7, i32 7, i32 2, i8 1 }, i32 7, i1 false) #[[#ATTR]]
  ; CHECK: call %dx.types.Handle @dx.op.annotateHandle(i32 216, %dx.types.Handle [[BUF1]], %dx.types.ResourceProperties { i32 4106, i32 260 }) #[[#ATTR]]

  ; Buffer<uint4> Buf[24] : register(t3, space5)
  ; Buffer<uint4> typed2 = Buf[4]
  ; Note that the index below is 3 + 4 = 7
  %typed2 = call target("dx.TypedBuffer", <4 x i32>, 0, 0, 0)
      @llvm.dx.resource.handlefrombinding.tdx.TypedBuffer_i32_0_0_0t(
          i32 5, i32 3, i32 24, i32 4, i1 false)
  ; CHECK: [[BUF2:%.*]] = call %dx.types.Handle @dx.op.createHandleFromBinding(i32 217, %dx.types.ResBind { i32 3, i32 26, i32 5, i8 0 }, i32 7, i1 false) #[[#ATTR]]
  ; CHECK: call %dx.types.Handle @dx.op.annotateHandle(i32 216, %dx.types.Handle [[BUF2]], %dx.types.ResourceProperties { i32 10, i32 1029 }) #[[#ATTR]]

  ; struct S { float4 a; uint4 b; };
  ; StructuredBuffer<S> Buf : register(t2, space4)
  %struct0 = call target("dx.RawBuffer", {<4 x float>, <4 x i32>}, 0, 0)
      @llvm.dx.resource.handlefrombinding.tdx.RawBuffer_sl_v4f32v4i32s_0_0t(
          i32 4, i32 2, i32 1, i32 0, i1 true)
  ; CHECK: [[BUF3:%.*]] = call %dx.types.Handle @dx.op.createHandleFromBinding(i32 217, %dx.types.ResBind { i32 2, i32 2, i32 4, i8 0 }, i32 2, i1 true) #[[#ATTR]]
  ; CHECK: = call %dx.types.Handle @dx.op.annotateHandle(i32 216, %dx.types.Handle [[BUF3]], %dx.types.ResourceProperties { i32 1036, i32 32 }) #[[#ATTR]]

  ; ByteAddressBuffer Buf : register(t8, space1)
  %byteaddr0 = call target("dx.RawBuffer", i8, 0, 0)
      @llvm.dx.resource.handlefrombinding.tdx.RawBuffer_i8_0_0t(
          i32 1, i32 8, i32 1, i32 0, i1 false)
  ; CHECK: [[BUF4:%.*]] = call %dx.types.Handle @dx.op.createHandleFromBinding(i32 217, %dx.types.ResBind { i32 8, i32 8, i32 1, i8 0 }, i32 8, i1 false) #[[#ATTR]]
  ; CHECK: call %dx.types.Handle @dx.op.annotateHandle(i32 216, %dx.types.Handle [[BUF4]], %dx.types.ResourceProperties { i32 11, i32 0 }) #[[#ATTR]]

  ; Buffer<float4> Buf[] : register(t7)
  ; Buffer<float4> typed3 = Buf[ix]
  %typed3_ix = call i32 @some_val()
  %typed3 = call target("dx.TypedBuffer", <4 x float>, 0, 0, 0)
      @llvm.dx.resource.handlefrombinding.tdx.TypedBuffer_v4f32_0_0_0t(
          i32 0, i32 7, i32 -1, i32 %typed3_ix, i1 false)
  ; CHECK: %[[IX:.*]] = add i32 %typed3_ix, 7
  ; CHECK: [[BUF5:%.*]] = call %dx.types.Handle @dx.op.createHandleFromBinding(i32 217, %dx.types.ResBind { i32 7, i32 -1, i32 0, i8 0 }, i32 %[[IX]], i1 false) #[[#ATTR]]
  ; CHECK: call %dx.types.Handle @dx.op.annotateHandle(i32 216, %dx.types.Handle [[BUF5]], %dx.types.ResourceProperties { i32 10, i32 1033 }) #[[#ATTR]]

  ; cbuffer cb0 : register(b0) { int4 i; float4 f; }
  %cb0 = call target("dx.CBuffer", target("dx.Layout", {<4 x i32>, <4 x float>}, 32, 0, 16))
      @llvm.dx.resource.handlefrombinding(i32 0, i32 0, i32 1, i32 0, i1 false)
  ; CHECK: [[BUF6:%.*]] = call %dx.types.Handle @dx.op.createHandleFromBinding(i32 217, %dx.types.ResBind { i32 0, i32 0, i32 0, i8 2 }, i32 0, i1 false) #[[#ATTR]]
  ; CHECK: call %dx.types.Handle @dx.op.annotateHandle(i32 216, %dx.types.Handle [[BUF6]], %dx.types.ResourceProperties { i32 13, i32 32 }) #[[#ATTR]]

  ret void
}

; CHECK: attributes #[[#ATTR]] = {{{.*}} memory(none) {{.*}}}

; Just check that we have the right types and number of metadata nodes, the
; contents of the metadata are tested elsewhere.
;
; CHECK: !dx.resources = !{[[RESMD:![0-9]+]]}
; CHECK: [[RESMD]] = !{[[SRVMD:![0-9]+]], [[UAVMD:![0-9]+]], [[CBUFMD:![0-9]+]], null}
; CHECK-DAG: [[SRVMD]] = !{!{{[0-9]+}}, !{{[0-9]+}}, !{{[0-9]+}}, !{{[0-9]+}}}
; CHECK-DAG: [[UAVMD]] = !{!{{[0-9]+}}, !{{[0-9]+}}}
; CHECK-DAG: [[CBUFMD]] = !{!{{[0-9]+}}}

attributes #0 = { nocallback nofree nosync nounwind willreturn memory(none) }
