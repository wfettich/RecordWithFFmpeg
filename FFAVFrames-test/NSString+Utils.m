
#import "NSString+Utils.h"

@implementation NSString (Utils)

#define SECOND          1
#define MINUTE          (60 * SECOND)
#define HOUR            (60 * MINUTE)
#define DAY             (24 * HOUR)
#define MONTH           (30 * DAY)

-(BOOL)isEmail
{
    NSString *emailRegEx =
    @"(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"
    @"~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"
    @"x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"
    @"z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"
    @"]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"
    @"9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"
    @"-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])";
    
    NSPredicate *regExPredicate =
    [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegEx];
    BOOL myStringMatchesRegEx = [regExPredicate evaluateWithObject:self];
    return myStringMatchesRegEx;
}

- (BOOL) hasSubString:(NSString *) str
{
	return [self rangeOfString:str].location != NSNotFound;
}

- (NSString *)urlEncodeUsingEncoding:(NSStringEncoding)encoding
{
    NSString *result = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                           (CFStringRef)self,
                                                                           NULL,
                                                                           (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                                           CFStringConvertNSStringEncodingToEncoding(encoding));
	return [result autorelease];
}

+ (NSString *)formattedDateFromTimestamp:(NSString *)timestamp
{
    NSDate* date = [NSDate dateWithTimeIntervalSince1970:[timestamp intValue]];
    return [NSString formattedDateFromDate:date];
}

+ (NSString *)formattedDateFromDate:(NSDate*)date
{
    //Calculate the delta in seconds between the two dates
    NSTimeInterval delta =  ABS([date timeIntervalSinceNow]);
    
    if (delta < 1 * MINUTE)
    {
        return delta == 1 ? @"Just now" : [NSString stringWithFormat:@"%d seconds ago", (int)delta];
    }
    if (delta < 2 * MINUTE)
    {
        return @"A minute ago";
    }
    if (delta < 45 * MINUTE)
    {
        int minutes = floor((double)delta/MINUTE);
        return [NSString stringWithFormat:@"%d minutes ago", minutes];
    }
    if (delta < 90 * MINUTE)
    {
        return @"An hour ago";
    }
    if (delta < 24 * HOUR)
    {
        int hours = floor((double)delta/HOUR);
        return hours <= 1 ? @"An hour ago" : [NSString stringWithFormat:@"%d hours ago", hours];
    }
    if (delta < 48 * HOUR)
    {
        return @"Yesterday";
    }
    if (delta < 30 * DAY)
    {
        int days = floor((double)delta/DAY);
        return days <= 1 ? @"One day ago" : [NSString stringWithFormat:@"%d days ago", days];
    }
    if (delta < 12 * MONTH)
    {
        int months = floor((double)delta/MONTH);
        return months <= 1 ? @"One month ago" : [NSString stringWithFormat:@"%d months ago", months];
    }
    else
    {
        int years = floor((double)delta/MONTH/12.0);
        return years <= 1 ? @"One year ago" : [NSString stringWithFormat:@"%d years ago", years];
    }
}

+ (NSString *)shortDateFromDate:(NSDate *)date
{
    //Calculate the delta in seconds between the two dates
    NSTimeInterval delta =  ABS([date timeIntervalSinceNow]);
    if (delta < 1 * MINUTE) {
        return @"now";
    }
    if (delta < 60 * MINUTE) {
        int minutes = floor((double)delta/MINUTE);
        return [NSString stringWithFormat:@"%d min", minutes];
    }
    if (delta < 24 * HOUR) {
        int hours = floor((double)delta/HOUR);
        return [NSString stringWithFormat:@"%d h", hours];
    }
    if (delta < 30 * DAY) {
        int days = floor((double)delta/DAY);
        return [NSString stringWithFormat:@"%d d", days];
    }
    if (delta < 12 * MONTH) {
        int months = floor((double)delta/MONTH);
        return [NSString stringWithFormat:@"%d mo", months];
    }
    int years = floor((double)delta/MONTH/12.0);
    return [NSString stringWithFormat:@"%d y", years];
}

+ (NSString *)shortDateFromTimestamp:(NSString *)timestamp {
    NSDate* date = [NSDate dateWithTimeIntervalSince1970:[timestamp intValue]];
    
    return [self shortDateFromDate:date];
}


extern NSString* NSStringF (NSString *format, ...)
{
    va_list argList;
	va_start(argList, format);
    
    NSString* s = [[[NSString alloc] initWithFormat:format arguments:argList] autorelease];
    return s;
    
}

-(NSString*)trim {
	return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

-(BOOL) isEmpty
{
    return [[self trim] isEqualToString:@""];
}




- (BOOL)containsString:(NSString *)string
               options:(NSStringCompareOptions)options {
    NSRange rng = [self rangeOfString:string options:options];
    return rng.location != NSNotFound;
}

- (BOOL)containsString:(NSString *)string {
    return [self containsString:string options:0];
}


@end
