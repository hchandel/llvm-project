; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --check-globals none --version 5
; RUN: opt -p loop-vectorize -force-vector-width=2 -S %s | FileCheck %s

declare void @llvm.assume(i1)

; %a is known dereferenceable via assume for the whole loop.
define void @deref_assumption_in_preheader_non_constant_trip_count_access_i8(ptr noalias noundef %a, ptr noalias %b, ptr noalias %c, i64 %n) nofree nosync {
; CHECK-LABEL: define void @deref_assumption_in_preheader_non_constant_trip_count_access_i8(
; CHECK-SAME: ptr noalias noundef [[A:%.*]], ptr noalias [[B:%.*]], ptr noalias [[C:%.*]], i64 [[N:%.*]]) #[[ATTR1:[0-9]+]] {
; CHECK-NEXT:  [[ENTRY:.*]]:
; CHECK-NEXT:    call void @llvm.assume(i1 true) [ "align"(ptr [[A]], i64 4), "dereferenceable"(ptr [[A]], i64 [[N]]) ]
; CHECK-NEXT:    [[MIN_ITERS_CHECK:%.*]] = icmp ult i64 [[N]], 2
; CHECK-NEXT:    br i1 [[MIN_ITERS_CHECK]], label %[[SCALAR_PH:.*]], label %[[VECTOR_PH:.*]]
; CHECK:       [[VECTOR_PH]]:
; CHECK-NEXT:    [[N_MOD_VF:%.*]] = urem i64 [[N]], 2
; CHECK-NEXT:    [[N_VEC:%.*]] = sub i64 [[N]], [[N_MOD_VF]]
; CHECK-NEXT:    br label %[[VECTOR_BODY:.*]]
; CHECK:       [[VECTOR_BODY]]:
; CHECK-NEXT:    [[TMP0:%.*]] = phi i64 [ 0, %[[VECTOR_PH]] ], [ [[INDEX_NEXT:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[TMP1:%.*]] = getelementptr i8, ptr [[A]], i64 [[TMP0]]
; CHECK-NEXT:    [[TMP2:%.*]] = getelementptr inbounds i8, ptr [[B]], i64 [[TMP0]]
; CHECK-NEXT:    [[WIDE_LOAD:%.*]] = load <2 x i8>, ptr [[TMP2]], align 1
; CHECK-NEXT:    [[TMP4:%.*]] = icmp sge <2 x i8> [[WIDE_LOAD]], zeroinitializer
; CHECK-NEXT:    [[WIDE_LOAD1:%.*]] = load <2 x i8>, ptr [[TMP1]], align 1
; CHECK-NEXT:    [[PREDPHI:%.*]] = select <2 x i1> [[TMP4]], <2 x i8> [[WIDE_LOAD]], <2 x i8> [[WIDE_LOAD1]]
; CHECK-NEXT:    [[TMP6:%.*]] = getelementptr inbounds i8, ptr [[C]], i64 [[TMP0]]
; CHECK-NEXT:    store <2 x i8> [[PREDPHI]], ptr [[TMP6]], align 1
; CHECK-NEXT:    [[INDEX_NEXT]] = add nuw i64 [[TMP0]], 2
; CHECK-NEXT:    [[TMP8:%.*]] = icmp eq i64 [[INDEX_NEXT]], [[N_VEC]]
; CHECK-NEXT:    br i1 [[TMP8]], label %[[MIDDLE_BLOCK:.*]], label %[[VECTOR_BODY]], !llvm.loop [[LOOP0:![0-9]+]]
; CHECK:       [[MIDDLE_BLOCK]]:
; CHECK-NEXT:    [[CMP_N:%.*]] = icmp eq i64 [[N]], [[N_VEC]]
; CHECK-NEXT:    br i1 [[CMP_N]], label %[[EXIT:.*]], label %[[SCALAR_PH]]
; CHECK:       [[SCALAR_PH]]:
; CHECK-NEXT:    [[BC_RESUME_VAL:%.*]] = phi i64 [ [[N_VEC]], %[[MIDDLE_BLOCK]] ], [ 0, %[[ENTRY]] ]
; CHECK-NEXT:    br label %[[LOOP_HEADER:.*]]
; CHECK:       [[LOOP_HEADER]]:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[BC_RESUME_VAL]], %[[SCALAR_PH]] ], [ [[IV_NEXT:%.*]], %[[LOOP_LATCH:.*]] ]
; CHECK-NEXT:    [[GEP_A:%.*]] = getelementptr inbounds i8, ptr [[A]], i64 [[IV]]
; CHECK-NEXT:    [[GEP_B:%.*]] = getelementptr inbounds i8, ptr [[B]], i64 [[IV]]
; CHECK-NEXT:    [[L_B:%.*]] = load i8, ptr [[GEP_B]], align 1
; CHECK-NEXT:    [[C_1:%.*]] = icmp sge i8 [[L_B]], 0
; CHECK-NEXT:    br i1 [[C_1]], label %[[LOOP_LATCH]], label %[[LOOP_THEN:.*]]
; CHECK:       [[LOOP_THEN]]:
; CHECK-NEXT:    [[L_A:%.*]] = load i8, ptr [[GEP_A]], align 1
; CHECK-NEXT:    br label %[[LOOP_LATCH]]
; CHECK:       [[LOOP_LATCH]]:
; CHECK-NEXT:    [[MERGE:%.*]] = phi i8 [ [[L_A]], %[[LOOP_THEN]] ], [ [[L_B]], %[[LOOP_HEADER]] ]
; CHECK-NEXT:    [[GEP_C:%.*]] = getelementptr inbounds i8, ptr [[C]], i64 [[IV]]
; CHECK-NEXT:    store i8 [[MERGE]], ptr [[GEP_C]], align 1
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[EC:%.*]] = icmp eq i64 [[IV_NEXT]], [[N]]
; CHECK-NEXT:    br i1 [[EC]], label %[[EXIT]], label %[[LOOP_HEADER]], !llvm.loop [[LOOP3:![0-9]+]]
; CHECK:       [[EXIT]]:
; CHECK-NEXT:    ret void
;
entry:
  call void @llvm.assume(i1 true) [ "align"(ptr %a, i64 4), "dereferenceable"(ptr %a, i64 %n) ]
  br label %loop.header

loop.header:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop.latch ]
  %gep.a = getelementptr inbounds i8, ptr %a, i64 %iv
  %gep.b = getelementptr inbounds i8, ptr %b, i64 %iv
  %l.b = load i8, ptr %gep.b, align 1
  %c.1 = icmp sge i8 %l.b, 0
  br i1 %c.1, label %loop.latch, label %loop.then

loop.then:
  %l.a = load i8, ptr %gep.a, align 1
  br label %loop.latch

loop.latch:
  %merge = phi i8 [ %l.a, %loop.then ], [ %l.b, %loop.header ]
  %gep.c = getelementptr inbounds i8, ptr %c, i64 %iv
  store i8 %merge, ptr %gep.c, align 1
  %iv.next = add nuw nsw i64 %iv, 1
  %ec = icmp eq i64 %iv.next, %n
  br i1 %ec, label %exit, label %loop.header

exit:
  ret void
}

; %a is known dereferenceable via assume for the whole loop.
define void @deref_assumption_in_preheader_non_constant_trip_count_access_i32(ptr noalias noundef %a, ptr noalias %b, ptr noalias %c, i64 %n) nofree nosync {
; CHECK-LABEL: define void @deref_assumption_in_preheader_non_constant_trip_count_access_i32(
; CHECK-SAME: ptr noalias noundef [[A:%.*]], ptr noalias [[B:%.*]], ptr noalias [[C:%.*]], i64 [[N:%.*]]) #[[ATTR1]] {
; CHECK-NEXT:  [[ENTRY:.*]]:
; CHECK-NEXT:    [[MUL:%.*]] = mul nuw nsw i64 [[N]], 4
; CHECK-NEXT:    call void @llvm.assume(i1 true) [ "align"(ptr [[A]], i64 4), "dereferenceable"(ptr [[A]], i64 [[MUL]]) ]
; CHECK-NEXT:    [[MIN_ITERS_CHECK:%.*]] = icmp ult i64 [[N]], 2
; CHECK-NEXT:    br i1 [[MIN_ITERS_CHECK]], label %[[SCALAR_PH:.*]], label %[[VECTOR_PH:.*]]
; CHECK:       [[VECTOR_PH]]:
; CHECK-NEXT:    [[N_MOD_VF:%.*]] = urem i64 [[N]], 2
; CHECK-NEXT:    [[N_VEC:%.*]] = sub i64 [[N]], [[N_MOD_VF]]
; CHECK-NEXT:    br label %[[VECTOR_BODY:.*]]
; CHECK:       [[VECTOR_BODY]]:
; CHECK-NEXT:    [[TMP0:%.*]] = phi i64 [ 0, %[[VECTOR_PH]] ], [ [[INDEX_NEXT:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[TMP1:%.*]] = getelementptr i32, ptr [[A]], i64 [[TMP0]]
; CHECK-NEXT:    [[TMP2:%.*]] = getelementptr inbounds i32, ptr [[B]], i64 [[TMP0]]
; CHECK-NEXT:    [[WIDE_LOAD:%.*]] = load <2 x i32>, ptr [[TMP2]], align 1
; CHECK-NEXT:    [[TMP4:%.*]] = icmp sge <2 x i32> [[WIDE_LOAD]], zeroinitializer
; CHECK-NEXT:    [[WIDE_LOAD1:%.*]] = load <2 x i32>, ptr [[TMP1]], align 1
; CHECK-NEXT:    [[PREDPHI:%.*]] = select <2 x i1> [[TMP4]], <2 x i32> [[WIDE_LOAD]], <2 x i32> [[WIDE_LOAD1]]
; CHECK-NEXT:    [[TMP6:%.*]] = getelementptr inbounds i32, ptr [[C]], i64 [[TMP0]]
; CHECK-NEXT:    store <2 x i32> [[PREDPHI]], ptr [[TMP6]], align 1
; CHECK-NEXT:    [[INDEX_NEXT]] = add nuw i64 [[TMP0]], 2
; CHECK-NEXT:    [[TMP8:%.*]] = icmp eq i64 [[INDEX_NEXT]], [[N_VEC]]
; CHECK-NEXT:    br i1 [[TMP8]], label %[[MIDDLE_BLOCK:.*]], label %[[VECTOR_BODY]], !llvm.loop [[LOOP4:![0-9]+]]
; CHECK:       [[MIDDLE_BLOCK]]:
; CHECK-NEXT:    [[CMP_N:%.*]] = icmp eq i64 [[N]], [[N_VEC]]
; CHECK-NEXT:    br i1 [[CMP_N]], label %[[EXIT:.*]], label %[[SCALAR_PH]]
; CHECK:       [[SCALAR_PH]]:
; CHECK-NEXT:    [[BC_RESUME_VAL:%.*]] = phi i64 [ [[N_VEC]], %[[MIDDLE_BLOCK]] ], [ 0, %[[ENTRY]] ]
; CHECK-NEXT:    br label %[[LOOP_HEADER:.*]]
; CHECK:       [[LOOP_HEADER]]:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[BC_RESUME_VAL]], %[[SCALAR_PH]] ], [ [[IV_NEXT:%.*]], %[[LOOP_LATCH:.*]] ]
; CHECK-NEXT:    [[GEP_A:%.*]] = getelementptr inbounds i32, ptr [[A]], i64 [[IV]]
; CHECK-NEXT:    [[GEP_B:%.*]] = getelementptr inbounds i32, ptr [[B]], i64 [[IV]]
; CHECK-NEXT:    [[L_B:%.*]] = load i32, ptr [[GEP_B]], align 1
; CHECK-NEXT:    [[C_1:%.*]] = icmp sge i32 [[L_B]], 0
; CHECK-NEXT:    br i1 [[C_1]], label %[[LOOP_LATCH]], label %[[LOOP_THEN:.*]]
; CHECK:       [[LOOP_THEN]]:
; CHECK-NEXT:    [[L_A:%.*]] = load i32, ptr [[GEP_A]], align 1
; CHECK-NEXT:    br label %[[LOOP_LATCH]]
; CHECK:       [[LOOP_LATCH]]:
; CHECK-NEXT:    [[MERGE:%.*]] = phi i32 [ [[L_A]], %[[LOOP_THEN]] ], [ [[L_B]], %[[LOOP_HEADER]] ]
; CHECK-NEXT:    [[GEP_C:%.*]] = getelementptr inbounds i32, ptr [[C]], i64 [[IV]]
; CHECK-NEXT:    store i32 [[MERGE]], ptr [[GEP_C]], align 1
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[EC:%.*]] = icmp eq i64 [[IV_NEXT]], [[N]]
; CHECK-NEXT:    br i1 [[EC]], label %[[EXIT]], label %[[LOOP_HEADER]], !llvm.loop [[LOOP5:![0-9]+]]
; CHECK:       [[EXIT]]:
; CHECK-NEXT:    ret void
;
entry:
  %mul = mul nsw nuw i64 %n, 4
  call void @llvm.assume(i1 true) [ "align"(ptr %a, i64 4), "dereferenceable"(ptr %a, i64 %mul) ]
  br label %loop.header

loop.header:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop.latch ]
  %gep.a = getelementptr inbounds i32, ptr %a, i64 %iv
  %gep.b = getelementptr inbounds i32, ptr %b, i64 %iv
  %l.b = load i32, ptr %gep.b, align 1
  %c.1 = icmp sge i32 %l.b, 0
  br i1 %c.1, label %loop.latch, label %loop.then

loop.then:
  %l.a = load i32, ptr %gep.a, align 1
  br label %loop.latch

loop.latch:
  %merge = phi i32 [ %l.a, %loop.then ], [ %l.b, %loop.header ]
  %gep.c = getelementptr inbounds i32, ptr %c, i64 %iv
  store i32 %merge, ptr %gep.c, align 1
  %iv.next = add nuw nsw i64 %iv, 1
  %ec = icmp eq i64 %iv.next, %n
  br i1 %ec, label %exit, label %loop.header

exit:
  ret void
}


; %a is NOT known dereferenceable via assume for the whole loop.
define void @deref_assumption_in_preheader_too_small_non_constant_trip_count_access_i32(ptr noalias noundef %a, ptr noalias %b, ptr noalias %c, i64 %n) nofree nosync {
; CHECK-LABEL: define void @deref_assumption_in_preheader_too_small_non_constant_trip_count_access_i32(
; CHECK-SAME: ptr noalias noundef [[A:%.*]], ptr noalias [[B:%.*]], ptr noalias [[C:%.*]], i64 [[N:%.*]]) #[[ATTR1]] {
; CHECK-NEXT:  [[ENTRY:.*]]:
; CHECK-NEXT:    call void @llvm.assume(i1 true) [ "align"(ptr [[A]], i64 4), "dereferenceable"(ptr [[A]], i64 [[N]]) ]
; CHECK-NEXT:    [[MIN_ITERS_CHECK:%.*]] = icmp ult i64 [[N]], 2
; CHECK-NEXT:    br i1 [[MIN_ITERS_CHECK]], label %[[SCALAR_PH:.*]], label %[[VECTOR_PH:.*]]
; CHECK:       [[VECTOR_PH]]:
; CHECK-NEXT:    [[N_MOD_VF:%.*]] = urem i64 [[N]], 2
; CHECK-NEXT:    [[N_VEC:%.*]] = sub i64 [[N]], [[N_MOD_VF]]
; CHECK-NEXT:    br label %[[VECTOR_BODY:.*]]
; CHECK:       [[VECTOR_BODY]]:
; CHECK-NEXT:    [[TMP0:%.*]] = phi i64 [ 0, %[[VECTOR_PH]] ], [ [[INDEX_NEXT:%.*]], %[[PRED_LOAD_CONTINUE2:.*]] ]
; CHECK-NEXT:    [[TMP2:%.*]] = getelementptr inbounds i32, ptr [[B]], i64 [[TMP0]]
; CHECK-NEXT:    [[WIDE_LOAD:%.*]] = load <2 x i32>, ptr [[TMP2]], align 1
; CHECK-NEXT:    [[TMP4:%.*]] = icmp sge <2 x i32> [[WIDE_LOAD]], zeroinitializer
; CHECK-NEXT:    [[TMP15:%.*]] = xor <2 x i1> [[TMP4]], splat (i1 true)
; CHECK-NEXT:    [[TMP5:%.*]] = extractelement <2 x i1> [[TMP15]], i32 0
; CHECK-NEXT:    br i1 [[TMP5]], label %[[PRED_LOAD_IF:.*]], label %[[PRED_LOAD_CONTINUE:.*]]
; CHECK:       [[PRED_LOAD_IF]]:
; CHECK-NEXT:    [[TMP19:%.*]] = add i64 [[TMP0]], 0
; CHECK-NEXT:    [[TMP16:%.*]] = getelementptr inbounds i32, ptr [[A]], i64 [[TMP19]]
; CHECK-NEXT:    [[TMP17:%.*]] = load i32, ptr [[TMP16]], align 1
; CHECK-NEXT:    [[TMP18:%.*]] = insertelement <2 x i32> poison, i32 [[TMP17]], i32 0
; CHECK-NEXT:    br label %[[PRED_LOAD_CONTINUE]]
; CHECK:       [[PRED_LOAD_CONTINUE]]:
; CHECK-NEXT:    [[TMP9:%.*]] = phi <2 x i32> [ poison, %[[VECTOR_BODY]] ], [ [[TMP18]], %[[PRED_LOAD_IF]] ]
; CHECK-NEXT:    [[TMP10:%.*]] = extractelement <2 x i1> [[TMP15]], i32 1
; CHECK-NEXT:    br i1 [[TMP10]], label %[[PRED_LOAD_IF1:.*]], label %[[PRED_LOAD_CONTINUE2]]
; CHECK:       [[PRED_LOAD_IF1]]:
; CHECK-NEXT:    [[TMP11:%.*]] = add i64 [[TMP0]], 1
; CHECK-NEXT:    [[TMP12:%.*]] = getelementptr inbounds i32, ptr [[A]], i64 [[TMP11]]
; CHECK-NEXT:    [[TMP13:%.*]] = load i32, ptr [[TMP12]], align 1
; CHECK-NEXT:    [[TMP14:%.*]] = insertelement <2 x i32> [[TMP9]], i32 [[TMP13]], i32 1
; CHECK-NEXT:    br label %[[PRED_LOAD_CONTINUE2]]
; CHECK:       [[PRED_LOAD_CONTINUE2]]:
; CHECK-NEXT:    [[WIDE_LOAD1:%.*]] = phi <2 x i32> [ [[TMP9]], %[[PRED_LOAD_CONTINUE]] ], [ [[TMP14]], %[[PRED_LOAD_IF1]] ]
; CHECK-NEXT:    [[PREDPHI:%.*]] = select <2 x i1> [[TMP4]], <2 x i32> [[WIDE_LOAD]], <2 x i32> [[WIDE_LOAD1]]
; CHECK-NEXT:    [[TMP6:%.*]] = getelementptr inbounds i32, ptr [[C]], i64 [[TMP0]]
; CHECK-NEXT:    store <2 x i32> [[PREDPHI]], ptr [[TMP6]], align 1
; CHECK-NEXT:    [[INDEX_NEXT]] = add nuw i64 [[TMP0]], 2
; CHECK-NEXT:    [[TMP8:%.*]] = icmp eq i64 [[INDEX_NEXT]], [[N_VEC]]
; CHECK-NEXT:    br i1 [[TMP8]], label %[[MIDDLE_BLOCK:.*]], label %[[VECTOR_BODY]], !llvm.loop [[LOOP6:![0-9]+]]
; CHECK:       [[MIDDLE_BLOCK]]:
; CHECK-NEXT:    [[CMP_N:%.*]] = icmp eq i64 [[N]], [[N_VEC]]
; CHECK-NEXT:    br i1 [[CMP_N]], label %[[EXIT:.*]], label %[[SCALAR_PH]]
; CHECK:       [[SCALAR_PH]]:
; CHECK-NEXT:    [[BC_RESUME_VAL:%.*]] = phi i64 [ [[N_VEC]], %[[MIDDLE_BLOCK]] ], [ 0, %[[ENTRY]] ]
; CHECK-NEXT:    br label %[[LOOP_HEADER:.*]]
; CHECK:       [[LOOP_HEADER]]:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[BC_RESUME_VAL]], %[[SCALAR_PH]] ], [ [[IV_NEXT:%.*]], %[[LOOP_LATCH:.*]] ]
; CHECK-NEXT:    [[GEP_A:%.*]] = getelementptr inbounds i32, ptr [[A]], i64 [[IV]]
; CHECK-NEXT:    [[GEP_B:%.*]] = getelementptr inbounds i32, ptr [[B]], i64 [[IV]]
; CHECK-NEXT:    [[L_B:%.*]] = load i32, ptr [[GEP_B]], align 1
; CHECK-NEXT:    [[C_1:%.*]] = icmp sge i32 [[L_B]], 0
; CHECK-NEXT:    br i1 [[C_1]], label %[[LOOP_LATCH]], label %[[LOOP_THEN:.*]]
; CHECK:       [[LOOP_THEN]]:
; CHECK-NEXT:    [[L_A:%.*]] = load i32, ptr [[GEP_A]], align 1
; CHECK-NEXT:    br label %[[LOOP_LATCH]]
; CHECK:       [[LOOP_LATCH]]:
; CHECK-NEXT:    [[MERGE:%.*]] = phi i32 [ [[L_A]], %[[LOOP_THEN]] ], [ [[L_B]], %[[LOOP_HEADER]] ]
; CHECK-NEXT:    [[GEP_C:%.*]] = getelementptr inbounds i32, ptr [[C]], i64 [[IV]]
; CHECK-NEXT:    store i32 [[MERGE]], ptr [[GEP_C]], align 1
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[EC:%.*]] = icmp eq i64 [[IV_NEXT]], [[N]]
; CHECK-NEXT:    br i1 [[EC]], label %[[EXIT]], label %[[LOOP_HEADER]], !llvm.loop [[LOOP7:![0-9]+]]
; CHECK:       [[EXIT]]:
; CHECK-NEXT:    ret void
;
entry:
  call void @llvm.assume(i1 true) [ "align"(ptr %a, i64 4), "dereferenceable"(ptr %a, i64 %n) ]
  br label %loop.header

loop.header:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop.latch ]
  %gep.a = getelementptr inbounds i32, ptr %a, i64 %iv
  %gep.b = getelementptr inbounds i32, ptr %b, i64 %iv
  %l.b = load i32, ptr %gep.b, align 1
  %c.1 = icmp sge i32 %l.b, 0
  br i1 %c.1, label %loop.latch, label %loop.then

loop.then:
  %l.a = load i32, ptr %gep.a, align 1
  br label %loop.latch

loop.latch:
  %merge = phi i32 [ %l.a, %loop.then ], [ %l.b, %loop.header ]
  %gep.c = getelementptr inbounds i32, ptr %c, i64 %iv
  store i32 %merge, ptr %gep.c, align 1
  %iv.next = add nuw nsw i64 %iv, 1
  %ec = icmp eq i64 %iv.next, %n
  br i1 %ec, label %exit, label %loop.header

exit:
  ret void
}

; %a is NOT known dereferenceable via assume for the whole loop.
define void @deref_assumption_in_preheader_too_small2_non_constant_trip_count_access_i32(ptr noalias noundef %a, ptr noalias %b, ptr noalias %c, i64 %n) nofree nosync {
; CHECK-LABEL: define void @deref_assumption_in_preheader_too_small2_non_constant_trip_count_access_i32(
; CHECK-SAME: ptr noalias noundef [[A:%.*]], ptr noalias [[B:%.*]], ptr noalias [[C:%.*]], i64 [[N:%.*]]) #[[ATTR1]] {
; CHECK-NEXT:  [[ENTRY:.*]]:
; CHECK-NEXT:    call void @llvm.assume(i1 true) [ "align"(ptr [[A]], i64 4), "dereferenceable"(ptr [[A]], i64 100) ]
; CHECK-NEXT:    [[MIN_ITERS_CHECK:%.*]] = icmp ult i64 [[N]], 2
; CHECK-NEXT:    br i1 [[MIN_ITERS_CHECK]], label %[[SCALAR_PH:.*]], label %[[VECTOR_PH:.*]]
; CHECK:       [[VECTOR_PH]]:
; CHECK-NEXT:    [[N_MOD_VF:%.*]] = urem i64 [[N]], 2
; CHECK-NEXT:    [[N_VEC:%.*]] = sub i64 [[N]], [[N_MOD_VF]]
; CHECK-NEXT:    br label %[[VECTOR_BODY:.*]]
; CHECK:       [[VECTOR_BODY]]:
; CHECK-NEXT:    [[TMP0:%.*]] = phi i64 [ 0, %[[VECTOR_PH]] ], [ [[INDEX_NEXT:%.*]], %[[PRED_LOAD_CONTINUE2:.*]] ]
; CHECK-NEXT:    [[TMP2:%.*]] = getelementptr inbounds i32, ptr [[B]], i64 [[TMP0]]
; CHECK-NEXT:    [[WIDE_LOAD:%.*]] = load <2 x i32>, ptr [[TMP2]], align 1
; CHECK-NEXT:    [[TMP4:%.*]] = icmp sge <2 x i32> [[WIDE_LOAD]], zeroinitializer
; CHECK-NEXT:    [[TMP15:%.*]] = xor <2 x i1> [[TMP4]], splat (i1 true)
; CHECK-NEXT:    [[TMP5:%.*]] = extractelement <2 x i1> [[TMP15]], i32 0
; CHECK-NEXT:    br i1 [[TMP5]], label %[[PRED_LOAD_IF:.*]], label %[[PRED_LOAD_CONTINUE:.*]]
; CHECK:       [[PRED_LOAD_IF]]:
; CHECK-NEXT:    [[TMP19:%.*]] = add i64 [[TMP0]], 0
; CHECK-NEXT:    [[TMP16:%.*]] = getelementptr inbounds i32, ptr [[A]], i64 [[TMP19]]
; CHECK-NEXT:    [[TMP17:%.*]] = load i32, ptr [[TMP16]], align 1
; CHECK-NEXT:    [[TMP18:%.*]] = insertelement <2 x i32> poison, i32 [[TMP17]], i32 0
; CHECK-NEXT:    br label %[[PRED_LOAD_CONTINUE]]
; CHECK:       [[PRED_LOAD_CONTINUE]]:
; CHECK-NEXT:    [[TMP9:%.*]] = phi <2 x i32> [ poison, %[[VECTOR_BODY]] ], [ [[TMP18]], %[[PRED_LOAD_IF]] ]
; CHECK-NEXT:    [[TMP10:%.*]] = extractelement <2 x i1> [[TMP15]], i32 1
; CHECK-NEXT:    br i1 [[TMP10]], label %[[PRED_LOAD_IF1:.*]], label %[[PRED_LOAD_CONTINUE2]]
; CHECK:       [[PRED_LOAD_IF1]]:
; CHECK-NEXT:    [[TMP11:%.*]] = add i64 [[TMP0]], 1
; CHECK-NEXT:    [[TMP12:%.*]] = getelementptr inbounds i32, ptr [[A]], i64 [[TMP11]]
; CHECK-NEXT:    [[TMP13:%.*]] = load i32, ptr [[TMP12]], align 1
; CHECK-NEXT:    [[TMP14:%.*]] = insertelement <2 x i32> [[TMP9]], i32 [[TMP13]], i32 1
; CHECK-NEXT:    br label %[[PRED_LOAD_CONTINUE2]]
; CHECK:       [[PRED_LOAD_CONTINUE2]]:
; CHECK-NEXT:    [[WIDE_LOAD1:%.*]] = phi <2 x i32> [ [[TMP9]], %[[PRED_LOAD_CONTINUE]] ], [ [[TMP14]], %[[PRED_LOAD_IF1]] ]
; CHECK-NEXT:    [[PREDPHI:%.*]] = select <2 x i1> [[TMP4]], <2 x i32> [[WIDE_LOAD]], <2 x i32> [[WIDE_LOAD1]]
; CHECK-NEXT:    [[TMP6:%.*]] = getelementptr inbounds i32, ptr [[C]], i64 [[TMP0]]
; CHECK-NEXT:    store <2 x i32> [[PREDPHI]], ptr [[TMP6]], align 1
; CHECK-NEXT:    [[INDEX_NEXT]] = add nuw i64 [[TMP0]], 2
; CHECK-NEXT:    [[TMP8:%.*]] = icmp eq i64 [[INDEX_NEXT]], [[N_VEC]]
; CHECK-NEXT:    br i1 [[TMP8]], label %[[MIDDLE_BLOCK:.*]], label %[[VECTOR_BODY]], !llvm.loop [[LOOP8:![0-9]+]]
; CHECK:       [[MIDDLE_BLOCK]]:
; CHECK-NEXT:    [[CMP_N:%.*]] = icmp eq i64 [[N]], [[N_VEC]]
; CHECK-NEXT:    br i1 [[CMP_N]], label %[[EXIT:.*]], label %[[SCALAR_PH]]
; CHECK:       [[SCALAR_PH]]:
; CHECK-NEXT:    [[BC_RESUME_VAL:%.*]] = phi i64 [ [[N_VEC]], %[[MIDDLE_BLOCK]] ], [ 0, %[[ENTRY]] ]
; CHECK-NEXT:    br label %[[LOOP_HEADER:.*]]
; CHECK:       [[LOOP_HEADER]]:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[BC_RESUME_VAL]], %[[SCALAR_PH]] ], [ [[IV_NEXT:%.*]], %[[LOOP_LATCH:.*]] ]
; CHECK-NEXT:    [[GEP_A:%.*]] = getelementptr inbounds i32, ptr [[A]], i64 [[IV]]
; CHECK-NEXT:    [[GEP_B:%.*]] = getelementptr inbounds i32, ptr [[B]], i64 [[IV]]
; CHECK-NEXT:    [[L_B:%.*]] = load i32, ptr [[GEP_B]], align 1
; CHECK-NEXT:    [[C_1:%.*]] = icmp sge i32 [[L_B]], 0
; CHECK-NEXT:    br i1 [[C_1]], label %[[LOOP_LATCH]], label %[[LOOP_THEN:.*]]
; CHECK:       [[LOOP_THEN]]:
; CHECK-NEXT:    [[L_A:%.*]] = load i32, ptr [[GEP_A]], align 1
; CHECK-NEXT:    br label %[[LOOP_LATCH]]
; CHECK:       [[LOOP_LATCH]]:
; CHECK-NEXT:    [[MERGE:%.*]] = phi i32 [ [[L_A]], %[[LOOP_THEN]] ], [ [[L_B]], %[[LOOP_HEADER]] ]
; CHECK-NEXT:    [[GEP_C:%.*]] = getelementptr inbounds i32, ptr [[C]], i64 [[IV]]
; CHECK-NEXT:    store i32 [[MERGE]], ptr [[GEP_C]], align 1
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[EC:%.*]] = icmp eq i64 [[IV_NEXT]], [[N]]
; CHECK-NEXT:    br i1 [[EC]], label %[[EXIT]], label %[[LOOP_HEADER]], !llvm.loop [[LOOP9:![0-9]+]]
; CHECK:       [[EXIT]]:
; CHECK-NEXT:    ret void
;
entry:
  call void @llvm.assume(i1 true) [ "align"(ptr %a, i64 4), "dereferenceable"(ptr %a, i64 100) ]
  br label %loop.header

loop.header:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop.latch ]
  %gep.a = getelementptr inbounds i32, ptr %a, i64 %iv
  %gep.b = getelementptr inbounds i32, ptr %b, i64 %iv
  %l.b = load i32, ptr %gep.b, align 1
  %c.1 = icmp sge i32 %l.b, 0
  br i1 %c.1, label %loop.latch, label %loop.then

loop.then:
  %l.a = load i32, ptr %gep.a, align 1
  br label %loop.latch

loop.latch:
  %merge = phi i32 [ %l.a, %loop.then ], [ %l.b, %loop.header ]
  %gep.c = getelementptr inbounds i32, ptr %c, i64 %iv
  store i32 %merge, ptr %gep.c, align 1
  %iv.next = add nuw nsw i64 %iv, 1
  %ec = icmp eq i64 %iv.next, %n
  br i1 %ec, label %exit, label %loop.header

exit:
  ret void
}

; %a is known dereferenceable via assume for the whole loop, alignment is known via function attribute.
define void @deref_assumption_in_preheader_non_constant_trip_count_access_i32_align_attribute(ptr noalias noundef align 4 %a, ptr noalias %b, ptr noalias %c, i64 %n) nofree nosync {
; CHECK-LABEL: define void @deref_assumption_in_preheader_non_constant_trip_count_access_i32_align_attribute(
; CHECK-SAME: ptr noalias noundef align 4 [[A:%.*]], ptr noalias [[B:%.*]], ptr noalias [[C:%.*]], i64 [[N:%.*]]) #[[ATTR1]] {
; CHECK-NEXT:  [[ENTRY:.*]]:
; CHECK-NEXT:    [[MUL:%.*]] = mul nuw nsw i64 [[N]], 4
; CHECK-NEXT:    call void @llvm.assume(i1 true) [ "dereferenceable"(ptr [[A]], i64 [[MUL]]) ]
; CHECK-NEXT:    [[MIN_ITERS_CHECK:%.*]] = icmp ult i64 [[N]], 2
; CHECK-NEXT:    br i1 [[MIN_ITERS_CHECK]], label %[[SCALAR_PH:.*]], label %[[VECTOR_PH:.*]]
; CHECK:       [[VECTOR_PH]]:
; CHECK-NEXT:    [[N_MOD_VF:%.*]] = urem i64 [[N]], 2
; CHECK-NEXT:    [[N_VEC:%.*]] = sub i64 [[N]], [[N_MOD_VF]]
; CHECK-NEXT:    br label %[[VECTOR_BODY:.*]]
; CHECK:       [[VECTOR_BODY]]:
; CHECK-NEXT:    [[INDEX:%.*]] = phi i64 [ 0, %[[VECTOR_PH]] ], [ [[INDEX_NEXT:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[TMP0:%.*]] = getelementptr i32, ptr [[A]], i64 [[INDEX]]
; CHECK-NEXT:    [[TMP1:%.*]] = getelementptr inbounds i32, ptr [[B]], i64 [[INDEX]]
; CHECK-NEXT:    [[WIDE_LOAD:%.*]] = load <2 x i32>, ptr [[TMP1]], align 4
; CHECK-NEXT:    [[TMP3:%.*]] = icmp sge <2 x i32> [[WIDE_LOAD]], zeroinitializer
; CHECK-NEXT:    [[WIDE_LOAD1:%.*]] = load <2 x i32>, ptr [[TMP0]], align 4
; CHECK-NEXT:    [[PREDPHI:%.*]] = select <2 x i1> [[TMP3]], <2 x i32> [[WIDE_LOAD]], <2 x i32> [[WIDE_LOAD1]]
; CHECK-NEXT:    [[TMP5:%.*]] = getelementptr inbounds i32, ptr [[C]], i64 [[INDEX]]
; CHECK-NEXT:    store <2 x i32> [[PREDPHI]], ptr [[TMP5]], align 1
; CHECK-NEXT:    [[INDEX_NEXT]] = add nuw i64 [[INDEX]], 2
; CHECK-NEXT:    [[TMP7:%.*]] = icmp eq i64 [[INDEX_NEXT]], [[N_VEC]]
; CHECK-NEXT:    br i1 [[TMP7]], label %[[MIDDLE_BLOCK:.*]], label %[[VECTOR_BODY]], !llvm.loop [[LOOP10:![0-9]+]]
; CHECK:       [[MIDDLE_BLOCK]]:
; CHECK-NEXT:    [[CMP_N:%.*]] = icmp eq i64 [[N]], [[N_VEC]]
; CHECK-NEXT:    br i1 [[CMP_N]], label %[[EXIT:.*]], label %[[SCALAR_PH]]
; CHECK:       [[SCALAR_PH]]:
; CHECK-NEXT:    [[BC_RESUME_VAL:%.*]] = phi i64 [ [[N_VEC]], %[[MIDDLE_BLOCK]] ], [ 0, %[[ENTRY]] ]
; CHECK-NEXT:    br label %[[LOOP_HEADER:.*]]
; CHECK:       [[LOOP_HEADER]]:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[BC_RESUME_VAL]], %[[SCALAR_PH]] ], [ [[IV_NEXT:%.*]], %[[LOOP_LATCH:.*]] ]
; CHECK-NEXT:    [[GEP_A:%.*]] = getelementptr inbounds i32, ptr [[A]], i64 [[IV]]
; CHECK-NEXT:    [[GEP_B:%.*]] = getelementptr inbounds i32, ptr [[B]], i64 [[IV]]
; CHECK-NEXT:    [[L_B:%.*]] = load i32, ptr [[GEP_B]], align 4
; CHECK-NEXT:    [[C_1:%.*]] = icmp sge i32 [[L_B]], 0
; CHECK-NEXT:    br i1 [[C_1]], label %[[LOOP_LATCH]], label %[[LOOP_THEN:.*]]
; CHECK:       [[LOOP_THEN]]:
; CHECK-NEXT:    [[L_A:%.*]] = load i32, ptr [[GEP_A]], align 4
; CHECK-NEXT:    br label %[[LOOP_LATCH]]
; CHECK:       [[LOOP_LATCH]]:
; CHECK-NEXT:    [[MERGE:%.*]] = phi i32 [ [[L_A]], %[[LOOP_THEN]] ], [ [[L_B]], %[[LOOP_HEADER]] ]
; CHECK-NEXT:    [[GEP_C:%.*]] = getelementptr inbounds i32, ptr [[C]], i64 [[IV]]
; CHECK-NEXT:    store i32 [[MERGE]], ptr [[GEP_C]], align 1
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[EC:%.*]] = icmp eq i64 [[IV_NEXT]], [[N]]
; CHECK-NEXT:    br i1 [[EC]], label %[[EXIT]], label %[[LOOP_HEADER]], !llvm.loop [[LOOP11:![0-9]+]]
; CHECK:       [[EXIT]]:
; CHECK-NEXT:    ret void
;
entry:
  %mul = mul nsw nuw i64 %n, 4
  call void @llvm.assume(i1 true) [ "dereferenceable"(ptr %a, i64 %mul) ]
  br label %loop.header

loop.header:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop.latch ]
  %gep.a = getelementptr inbounds i32, ptr %a, i64 %iv
  %gep.b = getelementptr inbounds i32, ptr %b, i64 %iv
  %l.b = load i32, ptr %gep.b, align 4
  %c.1 = icmp sge i32 %l.b, 0
  br i1 %c.1, label %loop.latch, label %loop.then

loop.then:
  %l.a = load i32, ptr %gep.a, align 4
  br label %loop.latch

loop.latch:
  %merge = phi i32 [ %l.a, %loop.then ], [ %l.b, %loop.header ]
  %gep.c = getelementptr inbounds i32, ptr %c, i64 %iv
  store i32 %merge, ptr %gep.c, align 1
  %iv.next = add nuw nsw i64 %iv, 1
  %ec = icmp eq i64 %iv.next, %n
  br i1 %ec, label %exit, label %loop.header

exit:
  ret void
}

; Alignment via argument attribute is too small (1 but needs 4).
define void @deref_assumption_in_preheader_non_constant_trip_count_access_i32_align_attribute_too_small(ptr noalias noundef align 1 %a, ptr noalias %b, ptr noalias %c, i64 %n) nofree nosync {
; CHECK-LABEL: define void @deref_assumption_in_preheader_non_constant_trip_count_access_i32_align_attribute_too_small(
; CHECK-SAME: ptr noalias noundef align 1 [[A:%.*]], ptr noalias [[B:%.*]], ptr noalias [[C:%.*]], i64 [[N:%.*]]) #[[ATTR1]] {
; CHECK-NEXT:  [[ENTRY:.*]]:
; CHECK-NEXT:    [[MUL:%.*]] = mul nuw nsw i64 [[N]], 4
; CHECK-NEXT:    call void @llvm.assume(i1 true) [ "dereferenceable"(ptr [[A]], i64 [[MUL]]) ]
; CHECK-NEXT:    [[MIN_ITERS_CHECK:%.*]] = icmp ult i64 [[N]], 2
; CHECK-NEXT:    br i1 [[MIN_ITERS_CHECK]], label %[[SCALAR_PH:.*]], label %[[VECTOR_PH:.*]]
; CHECK:       [[VECTOR_PH]]:
; CHECK-NEXT:    [[N_MOD_VF:%.*]] = urem i64 [[N]], 2
; CHECK-NEXT:    [[N_VEC:%.*]] = sub i64 [[N]], [[N_MOD_VF]]
; CHECK-NEXT:    br label %[[VECTOR_BODY:.*]]
; CHECK:       [[VECTOR_BODY]]:
; CHECK-NEXT:    [[INDEX:%.*]] = phi i64 [ 0, %[[VECTOR_PH]] ], [ [[INDEX_NEXT:%.*]], %[[PRED_LOAD_CONTINUE2:.*]] ]
; CHECK-NEXT:    [[TMP0:%.*]] = getelementptr inbounds i32, ptr [[B]], i64 [[INDEX]]
; CHECK-NEXT:    [[WIDE_LOAD:%.*]] = load <2 x i32>, ptr [[TMP0]], align 4
; CHECK-NEXT:    [[TMP2:%.*]] = icmp sge <2 x i32> [[WIDE_LOAD]], zeroinitializer
; CHECK-NEXT:    [[TMP3:%.*]] = xor <2 x i1> [[TMP2]], splat (i1 true)
; CHECK-NEXT:    [[TMP4:%.*]] = extractelement <2 x i1> [[TMP3]], i32 0
; CHECK-NEXT:    br i1 [[TMP4]], label %[[PRED_LOAD_IF:.*]], label %[[PRED_LOAD_CONTINUE:.*]]
; CHECK:       [[PRED_LOAD_IF]]:
; CHECK-NEXT:    [[TMP5:%.*]] = add i64 [[INDEX]], 0
; CHECK-NEXT:    [[TMP6:%.*]] = getelementptr inbounds i32, ptr [[A]], i64 [[TMP5]]
; CHECK-NEXT:    [[TMP7:%.*]] = load i32, ptr [[TMP6]], align 4
; CHECK-NEXT:    [[TMP8:%.*]] = insertelement <2 x i32> poison, i32 [[TMP7]], i32 0
; CHECK-NEXT:    br label %[[PRED_LOAD_CONTINUE]]
; CHECK:       [[PRED_LOAD_CONTINUE]]:
; CHECK-NEXT:    [[TMP9:%.*]] = phi <2 x i32> [ poison, %[[VECTOR_BODY]] ], [ [[TMP8]], %[[PRED_LOAD_IF]] ]
; CHECK-NEXT:    [[TMP10:%.*]] = extractelement <2 x i1> [[TMP3]], i32 1
; CHECK-NEXT:    br i1 [[TMP10]], label %[[PRED_LOAD_IF1:.*]], label %[[PRED_LOAD_CONTINUE2]]
; CHECK:       [[PRED_LOAD_IF1]]:
; CHECK-NEXT:    [[TMP11:%.*]] = add i64 [[INDEX]], 1
; CHECK-NEXT:    [[TMP12:%.*]] = getelementptr inbounds i32, ptr [[A]], i64 [[TMP11]]
; CHECK-NEXT:    [[TMP13:%.*]] = load i32, ptr [[TMP12]], align 4
; CHECK-NEXT:    [[TMP14:%.*]] = insertelement <2 x i32> [[TMP9]], i32 [[TMP13]], i32 1
; CHECK-NEXT:    br label %[[PRED_LOAD_CONTINUE2]]
; CHECK:       [[PRED_LOAD_CONTINUE2]]:
; CHECK-NEXT:    [[TMP15:%.*]] = phi <2 x i32> [ [[TMP9]], %[[PRED_LOAD_CONTINUE]] ], [ [[TMP14]], %[[PRED_LOAD_IF1]] ]
; CHECK-NEXT:    [[PREDPHI:%.*]] = select <2 x i1> [[TMP2]], <2 x i32> [[WIDE_LOAD]], <2 x i32> [[TMP15]]
; CHECK-NEXT:    [[TMP16:%.*]] = getelementptr inbounds i32, ptr [[C]], i64 [[INDEX]]
; CHECK-NEXT:    store <2 x i32> [[PREDPHI]], ptr [[TMP16]], align 1
; CHECK-NEXT:    [[INDEX_NEXT]] = add nuw i64 [[INDEX]], 2
; CHECK-NEXT:    [[TMP18:%.*]] = icmp eq i64 [[INDEX_NEXT]], [[N_VEC]]
; CHECK-NEXT:    br i1 [[TMP18]], label %[[MIDDLE_BLOCK:.*]], label %[[VECTOR_BODY]], !llvm.loop [[LOOP12:![0-9]+]]
; CHECK:       [[MIDDLE_BLOCK]]:
; CHECK-NEXT:    [[CMP_N:%.*]] = icmp eq i64 [[N]], [[N_VEC]]
; CHECK-NEXT:    br i1 [[CMP_N]], label %[[EXIT:.*]], label %[[SCALAR_PH]]
; CHECK:       [[SCALAR_PH]]:
; CHECK-NEXT:    [[BC_RESUME_VAL:%.*]] = phi i64 [ [[N_VEC]], %[[MIDDLE_BLOCK]] ], [ 0, %[[ENTRY]] ]
; CHECK-NEXT:    br label %[[LOOP_HEADER:.*]]
; CHECK:       [[LOOP_HEADER]]:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[BC_RESUME_VAL]], %[[SCALAR_PH]] ], [ [[IV_NEXT:%.*]], %[[LOOP_LATCH:.*]] ]
; CHECK-NEXT:    [[GEP_A:%.*]] = getelementptr inbounds i32, ptr [[A]], i64 [[IV]]
; CHECK-NEXT:    [[GEP_B:%.*]] = getelementptr inbounds i32, ptr [[B]], i64 [[IV]]
; CHECK-NEXT:    [[L_B:%.*]] = load i32, ptr [[GEP_B]], align 4
; CHECK-NEXT:    [[C_1:%.*]] = icmp sge i32 [[L_B]], 0
; CHECK-NEXT:    br i1 [[C_1]], label %[[LOOP_LATCH]], label %[[LOOP_THEN:.*]]
; CHECK:       [[LOOP_THEN]]:
; CHECK-NEXT:    [[L_A:%.*]] = load i32, ptr [[GEP_A]], align 4
; CHECK-NEXT:    br label %[[LOOP_LATCH]]
; CHECK:       [[LOOP_LATCH]]:
; CHECK-NEXT:    [[MERGE:%.*]] = phi i32 [ [[L_A]], %[[LOOP_THEN]] ], [ [[L_B]], %[[LOOP_HEADER]] ]
; CHECK-NEXT:    [[GEP_C:%.*]] = getelementptr inbounds i32, ptr [[C]], i64 [[IV]]
; CHECK-NEXT:    store i32 [[MERGE]], ptr [[GEP_C]], align 1
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[EC:%.*]] = icmp eq i64 [[IV_NEXT]], [[N]]
; CHECK-NEXT:    br i1 [[EC]], label %[[EXIT]], label %[[LOOP_HEADER]], !llvm.loop [[LOOP13:![0-9]+]]
; CHECK:       [[EXIT]]:
; CHECK-NEXT:    ret void
;
entry:
  %mul = mul nsw nuw i64 %n, 4
  call void @llvm.assume(i1 true) [ "dereferenceable"(ptr %a, i64 %mul) ]
  br label %loop.header

loop.header:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop.latch ]
  %gep.a = getelementptr inbounds i32, ptr %a, i64 %iv
  %gep.b = getelementptr inbounds i32, ptr %b, i64 %iv
  %l.b = load i32, ptr %gep.b, align 4
  %c.1 = icmp sge i32 %l.b, 0
  br i1 %c.1, label %loop.latch, label %loop.then

loop.then:
  %l.a = load i32, ptr %gep.a, align 4
  br label %loop.latch

loop.latch:
  %merge = phi i32 [ %l.a, %loop.then ], [ %l.b, %loop.header ]
  %gep.c = getelementptr inbounds i32, ptr %c, i64 %iv
  store i32 %merge, ptr %gep.c, align 1
  %iv.next = add nuw nsw i64 %iv, 1
  %ec = icmp eq i64 %iv.next, %n
  br i1 %ec, label %exit, label %loop.header

exit:
  ret void
}
