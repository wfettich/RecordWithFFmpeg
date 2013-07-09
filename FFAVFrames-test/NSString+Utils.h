
#import <Foundation/Foundation.h>

@interface NSString (Utils)
- (BOOL)isEmail;
- (BOOL) hasSubString:(NSString *) str;
- (NSString *)urlEncodeUsingEncoding:(NSStringEncoding)encoding;
+ (NSString *)formattedDateFromTimestamp:(NSString *)timestamp;
+ (NSString *)formattedDateFromDate:(NSDate*)date;
+ (NSString *)shortDateFromDate:(NSDate *)date;
+ (NSString *)shortDateFromTimestamp:(NSString *)timestamp;
- (BOOL)containsString:(NSString *)string;
- (BOOL)containsString:(NSString *)string
               options:(NSStringCompareOptions) options;
NSString* NSStringF (NSString *format, ...);
-(NSString*)trim;
-(BOOL) isEmpty;
@end
