; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -O2 -mtriple=riscv64 | FileCheck %s

define i32 @native_i64(i64 %a)  {
; CHECK-LABEL: native_i64:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    li a1, -1
; CHECK-NEXT:    beq a0, a1, .LBB0_3
; CHECK-NEXT:  # %bb.1: # %entry
; CHECK-NEXT:    li a1, 1
; CHECK-NEXT:    bne a0, a1, .LBB0_4
; CHECK-NEXT:  # %bb.2: # %sw.bb0
; CHECK-NEXT:    li a0, 0
; CHECK-NEXT:    ret
; CHECK-NEXT:  .LBB0_3: # %sw.bb1
; CHECK-NEXT:    li a0, 1
; CHECK-NEXT:    ret
; CHECK-NEXT:  .LBB0_4: # %sw.default
; CHECK-NEXT:    li a0, -1
; CHECK-NEXT:    ret
entry:
  switch i64 %a, label %sw.default [
  i64 1, label %sw.bb0
  i64 -1, label %sw.bb1
  ]

sw.bb0:
  br label %return

sw.bb1:
  br label %return

sw.default:
  br label %return

return:
  %retval = phi i32 [ -1, %sw.default ], [ 0, %sw.bb0 ], [ 1, %sw.bb1 ]
  ret i32 %retval
}

define i32 @native_i32(i32 %a)  {
; CHECK-LABEL: native_i32:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    sext.w a0, a0
; CHECK-NEXT:    li a1, -1
; CHECK-NEXT:    beq a0, a1, .LBB1_3
; CHECK-NEXT:  # %bb.1: # %entry
; CHECK-NEXT:    li a1, 1
; CHECK-NEXT:    bne a0, a1, .LBB1_4
; CHECK-NEXT:  # %bb.2: # %sw.bb0
; CHECK-NEXT:    li a0, 0
; CHECK-NEXT:    ret
; CHECK-NEXT:  .LBB1_3: # %sw.bb1
; CHECK-NEXT:    li a0, 1
; CHECK-NEXT:    ret
; CHECK-NEXT:  .LBB1_4: # %sw.default
; CHECK-NEXT:    li a0, -1
; CHECK-NEXT:    ret
entry:
  switch i32 %a, label %sw.default [
  i32 1, label %sw.bb0
  i32 -1, label %sw.bb1
  ]

sw.bb0:
  br label %return

sw.bb1:
  br label %return

sw.default:
  br label %return

return:
  %retval = phi i32 [ -1, %sw.default ], [ 0, %sw.bb0 ], [ 1, %sw.bb1 ]
  ret i32 %retval
}

define i32 @trunc_i32(i64 %a)  {
; CHECK-LABEL: trunc_i32:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    sext.w a0, a0
; CHECK-NEXT:    li a1, -1
; CHECK-NEXT:    beq a0, a1, .LBB2_3
; CHECK-NEXT:  # %bb.1: # %entry
; CHECK-NEXT:    li a1, 1
; CHECK-NEXT:    bne a0, a1, .LBB2_4
; CHECK-NEXT:  # %bb.2: # %sw.bb0
; CHECK-NEXT:    li a0, 0
; CHECK-NEXT:    ret
; CHECK-NEXT:  .LBB2_3: # %sw.bb1
; CHECK-NEXT:    li a0, 1
; CHECK-NEXT:    ret
; CHECK-NEXT:  .LBB2_4: # %sw.default
; CHECK-NEXT:    li a0, -1
; CHECK-NEXT:    ret
entry:
  %trunc = trunc i64 %a to i32
  switch i32 %trunc, label %sw.default [
  i32 1, label %sw.bb0
  i32 -1, label %sw.bb1
  ]

sw.bb0:
  br label %return

sw.bb1:
  br label %return

sw.default:
  br label %return

return:
  %retval = phi i32 [ -1, %sw.default ], [ 0, %sw.bb0 ], [ 1, %sw.bb1 ]
  ret i32 %retval
}

define i32 @trunc_i17(i64 %a)  {
; CHECK-LABEL: trunc_i17:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    lui a1, 32
; CHECK-NEXT:    addi a1, a1, -1
; CHECK-NEXT:    and a0, a0, a1
; CHECK-NEXT:    beq a0, a1, .LBB3_3
; CHECK-NEXT:  # %bb.1: # %entry
; CHECK-NEXT:    li a1, 1
; CHECK-NEXT:    bne a0, a1, .LBB3_4
; CHECK-NEXT:  # %bb.2: # %sw.bb0
; CHECK-NEXT:    li a0, 0
; CHECK-NEXT:    ret
; CHECK-NEXT:  .LBB3_3: # %sw.bb1
; CHECK-NEXT:    li a0, 1
; CHECK-NEXT:    ret
; CHECK-NEXT:  .LBB3_4: # %sw.default
; CHECK-NEXT:    li a0, -1
; CHECK-NEXT:    ret
entry:
  %trunc = trunc i64 %a to i17
  switch i17 %trunc, label %sw.default [
  i17 1, label %sw.bb0
  i17 -1, label %sw.bb1
  ]

sw.bb0:
  br label %return

sw.bb1:
  br label %return

sw.default:
  br label %return

return:
  %retval = phi i32 [ -1, %sw.default ], [ 0, %sw.bb0 ], [ 1, %sw.bb1 ]
  ret i32 %retval
}

define i32 @trunc_i16(i64 %a)  {
; CHECK-LABEL: trunc_i16:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    lui a1, 16
; CHECK-NEXT:    addi a1, a1, -1
; CHECK-NEXT:    and a0, a0, a1
; CHECK-NEXT:    beq a0, a1, .LBB4_3
; CHECK-NEXT:  # %bb.1: # %entry
; CHECK-NEXT:    li a1, 1
; CHECK-NEXT:    bne a0, a1, .LBB4_4
; CHECK-NEXT:  # %bb.2: # %sw.bb0
; CHECK-NEXT:    li a0, 0
; CHECK-NEXT:    ret
; CHECK-NEXT:  .LBB4_3: # %sw.bb1
; CHECK-NEXT:    li a0, 1
; CHECK-NEXT:    ret
; CHECK-NEXT:  .LBB4_4: # %sw.default
; CHECK-NEXT:    li a0, -1
; CHECK-NEXT:    ret
entry:
  %trunc = trunc i64 %a to i16
  switch i16 %trunc, label %sw.default [
  i16 1, label %sw.bb0
  i16 -1, label %sw.bb1
  ]

sw.bb0:
  br label %return

sw.bb1:
  br label %return

sw.default:
  br label %return

return:
  %retval = phi i32 [ -1, %sw.default ], [ 0, %sw.bb0 ], [ 1, %sw.bb1 ]
  ret i32 %retval
}


define i32 @trunc_i12(i64 %a)  {
; CHECK-LABEL: trunc_i12:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    lui a1, 1
; CHECK-NEXT:    addi a1, a1, -1
; CHECK-NEXT:    and a0, a0, a1
; CHECK-NEXT:    beq a0, a1, .LBB5_3
; CHECK-NEXT:  # %bb.1: # %entry
; CHECK-NEXT:    li a1, 1
; CHECK-NEXT:    bne a0, a1, .LBB5_4
; CHECK-NEXT:  # %bb.2: # %sw.bb0
; CHECK-NEXT:    li a0, 0
; CHECK-NEXT:    ret
; CHECK-NEXT:  .LBB5_3: # %sw.bb1
; CHECK-NEXT:    li a0, 1
; CHECK-NEXT:    ret
; CHECK-NEXT:  .LBB5_4: # %sw.default
; CHECK-NEXT:    li a0, -1
; CHECK-NEXT:    ret
entry:
  %trunc = trunc i64 %a to i12
  switch i12 %trunc, label %sw.default [
  i12 1, label %sw.bb0
  i12 -1, label %sw.bb1
  ]

sw.bb0:
  br label %return

sw.bb1:
  br label %return

sw.default:
  br label %return

return:
  %retval = phi i32 [ -1, %sw.default ], [ 0, %sw.bb0 ], [ 1, %sw.bb1 ]
  ret i32 %retval
}

define i32 @trunc_i11(i64 %a)  {
; CHECK-LABEL: trunc_i11:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    andi a0, a0, 2047
; CHECK-NEXT:    li a1, 2047
; CHECK-NEXT:    beq a0, a1, .LBB6_3
; CHECK-NEXT:  # %bb.1: # %entry
; CHECK-NEXT:    li a1, 1
; CHECK-NEXT:    bne a0, a1, .LBB6_4
; CHECK-NEXT:  # %bb.2: # %sw.bb0
; CHECK-NEXT:    li a0, 0
; CHECK-NEXT:    ret
; CHECK-NEXT:  .LBB6_3: # %sw.bb1
; CHECK-NEXT:    li a0, 1
; CHECK-NEXT:    ret
; CHECK-NEXT:  .LBB6_4: # %sw.default
; CHECK-NEXT:    li a0, -1
; CHECK-NEXT:    ret
entry:
  %trunc = trunc i64 %a to i11
  switch i11 %trunc, label %sw.default [
  i11 1, label %sw.bb0
  i11 -1, label %sw.bb1
  ]

sw.bb0:
  br label %return

sw.bb1:
  br label %return

sw.default:
  br label %return

return:
  %retval = phi i32 [ -1, %sw.default ], [ 0, %sw.bb0 ], [ 1, %sw.bb1 ]
  ret i32 %retval
}


define i32 @trunc_i10(i64 %a)  {
; CHECK-LABEL: trunc_i10:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    andi a0, a0, 1023
; CHECK-NEXT:    li a1, 1023
; CHECK-NEXT:    beq a0, a1, .LBB7_3
; CHECK-NEXT:  # %bb.1: # %entry
; CHECK-NEXT:    li a1, 1
; CHECK-NEXT:    bne a0, a1, .LBB7_4
; CHECK-NEXT:  # %bb.2: # %sw.bb0
; CHECK-NEXT:    li a0, 0
; CHECK-NEXT:    ret
; CHECK-NEXT:  .LBB7_3: # %sw.bb1
; CHECK-NEXT:    li a0, 1
; CHECK-NEXT:    ret
; CHECK-NEXT:  .LBB7_4: # %sw.default
; CHECK-NEXT:    li a0, -1
; CHECK-NEXT:    ret
entry:
  %trunc = trunc i64 %a to i10
  switch i10 %trunc, label %sw.default [
  i10 1, label %sw.bb0
  i10 -1, label %sw.bb1
  ]

sw.bb0:
  br label %return

sw.bb1:
  br label %return

sw.default:
  br label %return

return:
  %retval = phi i32 [ -1, %sw.default ], [ 0, %sw.bb0 ], [ 1, %sw.bb1 ]
  ret i32 %retval
}
