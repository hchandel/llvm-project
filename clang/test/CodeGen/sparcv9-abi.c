// RUN: %clang_cc1 -triple sparcv9-unknown-unknown -emit-llvm %s -o - | FileCheck %s
#include <stdarg.h>

// CHECK-LABEL: define{{.*}} void @f_void()
void f_void(void) {}

// Arguments and return values smaller than the word size are extended.

// CHECK-LABEL: define{{.*}} signext i32 @f_int_1(i32 noundef signext %x)
int f_int_1(int x) { return x; }

// CHECK-LABEL: define{{.*}} zeroext i32 @f_int_2(i32 noundef zeroext %x)
unsigned f_int_2(unsigned x) { return x; }

// CHECK-LABEL: define{{.*}} i64 @f_int_3(i64 noundef %x)
long long f_int_3(long long x) { return x; }

// CHECK-LABEL: define{{.*}} signext i8 @f_int_4(i8 noundef signext %x)
char f_int_4(char x) { return x; }

// CHECK-LABEL: define{{.*}} fp128 @f_ld(fp128 noundef %x)
long double f_ld(long double x) { return x; }

// Zero-sized structs reserves an argument register slot if passed directly.
struct empty {};
struct emptyarr { struct empty a[10]; };

// CHECK-LABEL: define{{.*}} i64 @f_empty(i64 %x.coerce)
struct empty f_empty(struct empty x) { return x; }

// CHECK-LABEL: define{{.*}} i64 @f_emptyarr(i64 %x.coerce)
struct empty f_emptyarr(struct emptyarr x) { return x.a[0]; }

// CHECK-LABEL: define{{.*}} i64 @f_emptyvar(i32 noundef zeroext %count, ...)
long f_emptyvar(unsigned count, ...) {
    long ret;
    va_list args;
    va_start(args, count);

// CHECK: %[[CUR:[^ ]+]] = load ptr, ptr %args
// CHECK-DAG: %[[NXT:[^ ]+]] = getelementptr inbounds i8, ptr %[[CUR]], i64 8
// CHECK-DAG: store ptr %[[NXT]], ptr %args
    va_arg(args, struct empty);

// CHECK: %[[CUR:[^ ]+]] = load ptr, ptr %args
// CHECK-DAG: %[[NXT:[^ ]+]] = getelementptr inbounds i8, ptr %[[CUR]], i64 8
// CHECK-DAG: store ptr %[[NXT]], ptr %args
// CHECK-DAG: load i64, ptr %[[CUR]]
    ret = va_arg(args, long);
    va_end(args);
    return ret;
}

// If the zero-sized struct is contained in a non-zero-sized struct,
// though, it doesn't reserve any registers.
struct emptymixed { struct empty a; long b; };
struct emptyflex { unsigned count; struct empty data[10]; };

// CHECK-LABEL: define{{.*}} i64 @f_emptymixed(i64 %x.coerce)
long f_emptymixed(struct emptymixed x) { return x.b; }

// CHECK-LABEL: define{{.*}} i64 @f_emptyflex(i64 %x.coerce, i64 noundef %y)
long f_emptyflex(struct emptyflex x, long y) { return y; }

// Small structs are passed in registers.
struct small {
  int *a, *b;
};

// CHECK-LABEL: define{{.*}} %struct.small @f_small(ptr %x.coerce0, ptr %x.coerce1)
struct small f_small(struct small x) {
  x.a += *x.b;
  x.b = 0;
  return x;
}

// Medium-sized structs are passed indirectly, but can be returned in registers.
struct medium {
  int *a, *b;
  int *c, *d;
};

// CHECK-LABEL: define{{.*}} %struct.medium @f_medium(ptr dead_on_return noundef %x)
struct medium f_medium(struct medium x) {
  x.a += *x.b;
  x.b = 0;
  return x;
}

// Large structs are also returned indirectly.
struct large {
  int *a, *b;
  int *c, *d;
  int x;
};

// CHECK-LABEL: define{{.*}} void @f_large(ptr dead_on_unwind noalias writable sret(%struct.large) align 8 %agg.result, ptr dead_on_return noundef %x)
struct large f_large(struct large x) {
  x.a += *x.b;
  x.b = 0;
  return x;
}

// A 64-bit struct fits in a register.
struct reg {
  int a, b;
};

// CHECK-LABEL: define{{.*}} i64 @f_reg(i64 %x.coerce)
struct reg f_reg(struct reg x) {
  x.a += x.b;
  return x;
}

// Structs with mixed int and float parts require the inreg attribute.
struct mixed {
  int a;
  float b;
};

// CHECK-LABEL: define{{.*}} inreg %struct.mixed @f_mixed(i32 inreg %x.coerce0, float inreg %x.coerce1)
struct mixed f_mixed(struct mixed x) {
  x.a += 1;
  return x;
}

// Struct with padding.
struct mixed2 {
  int a;
  double b;
};

// CHECK: define{{.*}} { i64, double } @f_mixed2(i64 %x.coerce0, double %x.coerce1)
// CHECK: store i64 %x.coerce0
// CHECK: store double %x.coerce1
struct mixed2 f_mixed2(struct mixed2 x) {
  x.a += 1;
  return x;
}

// Struct with single element and padding in passed in the high bits of a
// register.
struct tiny {
  char a;
};

// CHECK-LABEL: define{{.*}} i64 @f_tiny(i64 %x.coerce)
// CHECK: %[[HB:[^ ]+]] = lshr i64 %x.coerce, 56
// CHECK: = trunc i64 %[[HB]] to i8
struct tiny f_tiny(struct tiny x) {
  x.a += 1;
  return x;
}

// CHECK-LABEL: define{{.*}} void @call_tiny()
// CHECK: %[[XV:[^ ]+]] = zext i8 %{{[^ ]+}} to i64
// CHECK: %[[HB:[^ ]+]] = shl i64 %[[XV]], 56
// CHECK: = call i64 @f_tiny(i64 %[[HB]])
void call_tiny(void) {
  struct tiny x = { 1 };
  f_tiny(x);
}

// CHECK-LABEL: define{{.*}} signext i32 @f_variable(ptr noundef %f, ...)
// CHECK: %ap = alloca ptr
// CHECK: call void @llvm.va_start
//
int f_variable(char *f, ...) {
  int s = 0;
  char c;
  va_list ap;
  va_start(ap, f);
  while ((c = *f++)) switch (c) {

// CHECK: %[[CUR:[^ ]+]] = load ptr, ptr %ap
// CHECK-DAG: %[[NXT:[^ ]+]] = getelementptr inbounds i8, ptr %[[CUR]], i64 8
// CHECK-DAG: store ptr %[[NXT]], ptr %ap
// CHECK-DAG: %[[EXT:[^ ]+]] = getelementptr inbounds i8, ptr %[[CUR]], i64 4
// CHECK-DAG: load i32, ptr %[[EXT]]
// CHECK: br
  case 'i':
    s += va_arg(ap, int);
    break;

// CHECK: %[[CUR:[^ ]+]] = load ptr, ptr %ap
// CHECK-DAG: %[[NXT:[^ ]+]] = getelementptr inbounds i8, ptr %[[CUR]], i64 8
// CHECK-DAG: store ptr %[[NXT]], ptr %ap
// CHECK-DAG: load i64, ptr %[[CUR]]
// CHECK: br
  case 'l':
    s += va_arg(ap, long);
    break;

// CHECK: %[[CUR:[^ ]+]] = load ptr, ptr %ap
// CHECK-DAG: %[[NXT:[^ ]+]] = getelementptr inbounds i8, ptr %[[CUR]], i64 8
// CHECK-DAG: store ptr %[[NXT]], ptr %ap
// CHECK: br
  case 't':
    s += va_arg(ap, struct tiny).a;
    break;

// CHECK: %[[CUR:[^ ]+]] = load ptr, ptr %ap
// CHECK-DAG: %[[NXT:[^ ]+]] = getelementptr inbounds i8, ptr %[[CUR]], i64 16
// CHECK-DAG: store ptr %[[NXT]], ptr %ap
// CHECK: br
  case 's':
    s += *va_arg(ap, struct small).a;
    break;

// CHECK: %[[CUR:[^ ]+]] = load ptr, ptr %ap
// CHECK-DAG: %[[NXT:[^ ]+]] = getelementptr inbounds i8, ptr %[[CUR]], i64 8
// CHECK-DAG: store ptr %[[NXT]], ptr %ap
// CHECK-DAG: %[[ADR:[^ ]+]] = load ptr, ptr %[[CUR]]
// CHECK: br
  case 'm':
    s += *va_arg(ap, struct medium).a;
    break;
  }
  return s;
}
