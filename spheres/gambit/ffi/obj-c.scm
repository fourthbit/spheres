;;!!! Interface with Objective-C.
;; .author Marc Feeley, 2011-2015
;;
;; Copyright (c) 2011-2015 by Marc Feeley, All Rights Reserved.

(c-declare #<<c-declare-end

#include <objc/objc.h>

const char *class_getName(Class cls);
id objc_getClass(const char *name);
id objc_msgSend(id self, SEL op, ...);

#if !__has_feature(objc_arc)
#define __bridge
#define __bridge_transfer
#endif

id retain_id(id x)
{
//  NSLog(@"retain_id of %p", ___CAST(void*,x));
#if !__has_feature(objc_arc)
  if (x != nil) [x retain];
  return x;
#else
  if (x != nil) CFBridgingRetain(x);
  return x;
#endif
}

___SCMOBJ release_id(void *ptr)
{
//  NSLog(@"release_id of %p", ptr);
#if !__has_feature(objc_arc)
  if (ptr != nil) [___CAST(id,ptr) release];
#else
  if (ptr != nil) CFBridgingRelease(ptr);
#endif

  return ___FIX(___NO_ERR);
}

Class retain_Class(Class x)
{
//  NSLog(@"retain_Class of %p", ___CAST(void*,x));
#if !__has_feature(objc_arc)
  if (x != nil) [x retain];
  return x;
#else
  if (x != nil) CFBridgingRetain(x);
  return x;
#endif
}

___SCMOBJ release_Class(void *ptr)
{
//  NSLog(@"release_Class of %p", ptr);
#if !__has_feature(objc_arc)
  if (ptr != nil) [___CAST(Class,ptr) release];
#else
  if (ptr != nil) CFBridgingRelease(ptr);
#endif

  return ___FIX(___NO_ERR);
}

c-declare-end
)

(c-define-type id (pointer (struct "objc_object") (id Class) "release_id"))
(c-define-type Class (pointer (struct "objc_class") (Class id) "release_Class"))
(c-define-type SEL (pointer (struct "objc_selector") (SEL)))

(define string->Class
  (c-lambda (nonnull-char-string) Class
            "___result = ___CAST(__bridge struct objc_class*,retain_Class(objc_getClass(___arg1)));"))

(define Class->string
  (c-lambda (Class) nonnull-char-string
            "___result = ___CAST(char*,class_getName(___CAST(__bridge Class,___arg1)));")) ;;;TODO: remove cast

(define string->SEL
  (c-lambda (nonnull-UTF-8-string) SEL
            ;;    "___result = ___CAST(struct objc_selector*,sel_registerName(___arg1));"
            ;; this avoids the warning generated by Xcode:
            "___result = ___CAST(void*,sel_registerName(___arg1));"
            ))

(define SEL->string
  (c-lambda (SEL) nonnull-UTF-8-string
    "___result = ___CAST(char*,sel_getName(___CAST(SEL,___arg1)));")) ;;;TODO: remove cast

;; Message sending (with 0, 1 and 2 parameters).

(define send0
  (c-lambda (id SEL) id
    "___result = ___CAST(__bridge struct objc_object*,retain_id(___CAST(id (*)(id, SEL),objc_msgSend)(___CAST(__bridge id,___arg1), ___CAST(SEL,___arg2))));"))

(define send1
  (c-lambda (id SEL id) id
    "___result = ___CAST(__bridge struct objc_object*,retain_id(___CAST(id (*)(id, SEL, id),objc_msgSend)(___CAST(__bridge id,___arg1), ___CAST(SEL,___arg2), ___CAST(__bridge id,___arg3))));"))

(define send2
  (c-lambda (id SEL id id) id
    "___result = ___CAST(__bridge struct objc_object*,retain_id(___CAST(id (*)(id, SEL, id, id),objc_msgSend)(___CAST(__bridge id,___arg1), ___CAST(SEL,___arg2), ___CAST(__bridge id,___arg3), ___CAST(__bridge id,___arg4))));"))

;; Type conversions.

;; (define id->string
;;   (c-lambda (id) nonnull-UTF-8-string
;;     "___result = ___CAST(char*,[___CAST(__bridge NSString*,___arg1) UTF8String]);")) ;;;TODO: remove cast

;; (define string->id
;;   (c-lambda (nonnull-UTF-8-string) id
;;     "___result = ___CAST(__bridge struct objc_object*,retain_id([NSString stringWithUTF8String: ___arg1]));"))

;; (define id->bool
;;   (c-lambda (id) bool
;;     "___result = [___CAST(__bridge NSNumber*,___arg1) boolValue];"))

;; (define bool->id
;;   (c-lambda (bool) id
;;     "___result = ___CAST(__bridge struct objc_object*,retain_id([NSNumber numberWithBool:___arg1]));"))

;; (define id->int
;;   (c-lambda (id) int
;;     "___result = [___CAST(__bridge NSNumber*,___arg1) intValue];"))

;; (define int->id
;;   (c-lambda (int) id
;;     "___result = ___CAST(__bridge struct objc_object*,retain_id([NSNumber numberWithInt:___arg1]));"))

;; (define id->float
;;   (c-lambda (id) float
;;     "___result = [___CAST(__bridge NSNumber*,___arg1) floatValue];"))

;; (define float->id
;;   (c-lambda (float) id
;;     "___result = ___CAST(__bridge struct objc_object*,retain_id([NSNumber numberWithFloat:___arg1]));"))

;; (define id->double
;;   (c-lambda (id) double
;;     "___result = [___CAST(__bridge NSNumber*,___arg1) doubleValue];"))

;; (define double->id
;;   (c-lambda (double) id
;;     "___result = ___CAST(__bridge struct objc_object*,retain_id([NSNumber numberWithDouble:___arg1]));"))


;;----------------------------------------------------------------------------
;; Implement conversions between NSString* and Scheme strings.

(c-declare #<<c-declare-end

#include <Foundation/NSString.h>

___SCMOBJ SCMOBJ_to_NSStringSTAR(___PSD ___SCMOBJ src, NSString **dst, int arg_num)
{
  /*
   * Convert a Scheme string to NSString* .
   */

  NSString *result;
  ___SCMOBJ ___temp;

  if (src == ___FAL)
    result = nil;
  else if (!___STRINGP(src))
    return ___FIX(___STOC_WCHARSTRING_ERR+arg_num);
  else
    {
      int i;
      int len = ___INT(___STRINGLENGTH(src));
      unichar *buf = ___alloc_mem(sizeof(unichar)*len);

      if (buf == 0)
        return ___FIX(___STOC_HEAP_OVERFLOW_ERR+arg_num);

      for (i=0; i<len; i++)
        {
          ___UCS_4 c = ___INT(___STRINGREF(src,___FIX(i)));
          buf[i] = c;
        }

      result = [NSString stringWithCharacters:buf length:len];

#if !__has_feature(objc_arc)
//      [result retain];
#endif

      ___free_mem(buf);
    }

  *dst = result;

  return ___FIX(___NO_ERR);
}

___SCMOBJ NSStringSTAR_to_SCMOBJ(___processor_state ___ps, NSString *src, ___SCMOBJ *dst, int arg_num)
{
  ___SCMOBJ result;

  if (src == nil)
    result = ___FAL;
  else
    {
      int i;
      int len = [src length];

      result = ___alloc_scmobj(___ps, ___sSTRING, len<<___LCS);

      if (___FIXNUMP(result))
        return ___FIX(___CTOS_HEAP_OVERFLOW_ERR+arg_num);

      for (i=0; i<len; i++)
        {
          ___UCS_4 c = [src characterAtIndex:i];
          ___STRINGSET(result,___FIX(i),___CHR(c))
        }
    }

  *dst = result;

  return ___FIX(___NO_ERR);
}

#define ___BEGIN_CFUN_SCMOBJ_to_NSStringSTAR(src,dst,i) \
if ((___err = SCMOBJ_to_NSStringSTAR(___PSP src, &dst, i)) == ___FIX(___NO_ERR)) {
#define ___END_CFUN_SCMOBJ_to_NSStringSTAR(src,dst,i) }

#define ___BEGIN_CFUN_NSStringSTAR_to_SCMOBJ(src,dst) \
if ((___err = NSStringSTAR_to_SCMOBJ(___ps, src, &dst, ___RETURN_POS)) == ___FIX(___NO_ERR)) {
#define ___END_CFUN_NSStringSTAR_to_SCMOBJ(src,dst) \
___EXT(___release_scmobj)(dst); }

#define ___BEGIN_SFUN_NSStringSTAR_to_SCMOBJ(src,dst,i) \
if ((___err = NSStringSTAR_to_SCMOBJ(___ps, src, &dst, i)) == ___FIX(___NO_ERR)) {
#define ___END_SFUN_NSStringSTAR_to_SCMOBJ(src,dst,i) \
___EXT(___release_scmobj)(dst); }

#define ___BEGIN_SFUN_SCMOBJ_to_NSStringSTAR(src,dst) \
{ ___err = SCMOBJ_to_NSStringSTAR(___PSP src, &dst, ___RETURN_POS);
#define ___END_SFUN_SCMOBJ_to_NSStringSTAR(src,dst) }

c-declare-end
)

(c-define-type NSString* "NSString*"
               "NSStringSTAR_to_SCMOBJ"
               "SCMOBJ_to_NSStringSTAR"
               #t)
