/*
 Copyright (c) 2010, Stig Brautaset.
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are
 met:
 
   Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
  
   Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
 
   Neither the name of the the author nor the names of its contributors
   may be used to endorse or promote products derived from this software
   without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SBJsonStreamWriter.h"
#import "SBProxyForJson.h"

@interface SBJsonStreamWriter ()
@property(readonly) NSObject **states;
@property(readonly) NSUInteger depth;
@property(readonly) NSOutputStream *stream;
- (BOOL)writeValue:(id)v;
- (void)write:(char const *)utf8 len:(NSUInteger)len;
@end

@interface SBJsonStreamWriterStateMachine : NSObject
- (void)writeSeparator:(SBJsonStreamWriter*)writer;
- (BOOL)needKey:(SBJsonStreamWriter*)writer;
- (void)appendedAtom:(SBJsonStreamWriter*)writer;
- (void)writeWhitespace:(SBJsonStreamWriter*)writer;
@end

@interface ObjectOpen : SBJsonStreamWriterStateMachine
@end

@interface ObjectKey : ObjectOpen
@end

@interface ObjectValue : SBJsonStreamWriterStateMachine
@end

@interface ObjectClose : SBJsonStreamWriterStateMachine
@end

@interface ArrayOpen : SBJsonStreamWriterStateMachine
@end

@interface InArray : SBJsonStreamWriterStateMachine
@end

@interface Open : SBJsonStreamWriterStateMachine
@end

@interface Close : SBJsonStreamWriterStateMachine
@end

@interface Error : SBJsonStreamWriterStateMachine
@end

static NSMutableDictionary *stringCache;
static NSDecimalNumber *notANumber;

// States
static Open *openState;
static Close *closeState;
static Error *error;
static ObjectOpen *objectOpen;
static ObjectKey *objectKey;
static ObjectValue *objectValue;
static ArrayOpen *arrayOpen;
static InArray *inArray;


@implementation SBJsonStreamWriterStateMachine
- (void)writeSeparator:(SBJsonStreamWriter*)writer {}
- (BOOL)needKey:(SBJsonStreamWriter*)writer { return NO; }
- (void)appendedAtom:(SBJsonStreamWriter *)writer {}
- (void)writeWhitespace:(SBJsonStreamWriter*)writer {
	for (int i = 0; i < writer.depth; i++)
	    [writer write:"  " len: 2];
}
@end

@implementation ObjectOpen
- (void)appendedAtom:(SBJsonStreamWriter *)writer {
	writer.states[writer.depth] = objectValue;
}
- (BOOL)needKey:(SBJsonStreamWriter *)writer {
	[writer addErrorWithCode:EUNSUPPORTED description: @"JSON object key must be string"];
	return YES;
}
@end

@implementation ObjectKey
- (void)writeSeparator:(SBJsonStreamWriter *)writer {
	[writer write:",\n" len:writer.humanReadable ? 2 : 1];
}
@end

@implementation ObjectValue
- (void)writeSeparator:(SBJsonStreamWriter *)writer {
	[writer write:":" len:1];
}
- (void)appendedAtom:(SBJsonStreamWriter *)writer {
	writer.states[writer.depth] = objectKey;
}
- (void)writeWhitespace:(SBJsonStreamWriter *)writer {
	[writer write:" " len:1];
}
@end

@implementation ObjectClose
@end

@implementation ArrayOpen
- (void)appendedAtom:(SBJsonStreamWriter *)writer {
	writer.states[writer.depth] = inArray;
}
@end

@implementation InArray
- (void)writeSeparator:(SBJsonStreamWriter *)writer {
	[writer write:",\n" len:writer.humanReadable ? 2 : 1];
}
@end

@implementation Open
- (void)appendedAtom:(SBJsonStreamWriter *)writer {
	writer.states[writer.depth] = closeState;
	[writer.stream close];
}
- (void)writeSeparator:(SBJsonStreamWriter *)writer {
	[writer.stream open];
}
@end

@implementation Close
@end

@implementation Error
@end

@implementation SBJsonStreamWriter

@dynamic depth;
@synthesize states;
@synthesize stream;
@synthesize humanReadable;
@synthesize sortKeys;

+ (void)initialize {
	notANumber = [NSDecimalNumber notANumber];
	stringCache = [NSMutableDictionary new];

	openState = [Open new];
	closeState = [Close new];
	error = [Error new];
	objectOpen = [ObjectOpen new];
	objectKey = [ObjectKey new];
	objectValue = [ObjectValue new];
	arrayOpen = [ArrayOpen new];
	inArray = [InArray new];
}

#pragma mark Housekeeping

- (id)initWithStream:(NSOutputStream*)stream_ {
	self = [super init];
	if (self) {
		stream = [stream_ retain];
		states = calloc(self.maxDepth, sizeof(NSObject *));
		if (states == NULL) {
			[self release];
			return nil;
		}
		states[0] = openState;
	}
	return self;
}

- (void)dealloc {
	free(states);
	[stream release];
	[super dealloc];
}

#pragma mark Meta Methods

- (BOOL)write:(id)object {
	if ([object isKindOfClass:[NSDictionary class]] || [object isKindOfClass:[NSArray class]])
		return [self writeValue:object];

	else if ([object respondsToSelector:@selector(proxyForJson)])
		return [self write:[object proxyForJson]];

	[self addErrorWithCode:EUNSUPPORTED description:@"Not valid type for JSON"];
	return NO;
}

#pragma mark Methods

- (BOOL)writeObject:(NSDictionary *)dict {
	if (![self writeObjectOpen])
		return NO;
	
	NSArray *keys = [dict allKeys];
	if (sortKeys)
		keys = [keys sortedArrayUsingSelector:@selector(compare:)];
	
	for (id k in keys) {
		if (![k isKindOfClass:[NSString class]]) {
			[self addErrorWithCode:EUNSUPPORTED description: @"JSON object key must be string"];
			return NO;
		}

		[self writeString:k];
		if (![self writeValue:[dict objectForKey:k]])
			return NO;
	}
	
	[self writeObjectClose];
	return YES;
}

- (BOOL)writeArray:(NSArray*)array {
	if (![self writeArrayOpen])
		return NO;
	for (id v in array)
		if (![self writeValue:v])
			return NO;
	[self writeArrayClose];
	return YES;
}


- (BOOL)writeObjectOpen {
	SBJsonStreamWriterStateMachine *s = states[depth];
	if ([s needKey:self]) return NO;
	[s writeSeparator:self];
	if (humanReadable) [s writeWhitespace:self];
	
	if (maxDepth && ++depth > maxDepth) {
		[self addErrorWithCode:EDEPTH description:@"Nested too deep"];
		return NO;
	}

	states[depth] = objectOpen;
	[self write:"{\n" len:humanReadable ? 2 : 1];
	return YES;
}

- (void)writeObjectClose {
	SBJsonStreamWriterStateMachine *state = states[depth--];
	if (humanReadable) {
		if ([state isKindOfClass:[ObjectKey class]])
			[self write:"\n" len:1];
		[state writeWhitespace:self];
	}
	[self write:"}" len:1];
	[states[depth] appendedAtom:self];
}

- (BOOL)writeArrayOpen {
	SBJsonStreamWriterStateMachine *s = states[depth];
	if ([s needKey:self]) return NO;
	[s writeSeparator:self];
	if (humanReadable) [s writeWhitespace:self];
	
	if (maxDepth && ++depth > maxDepth) {
		[self addErrorWithCode:EDEPTH description:@"Nested too deep"];
		return NO;
	}

	states[depth] = arrayOpen;
	[self write:"[\n" len:humanReadable ? 2 : 1];
	return YES;
}

- (void)writeArrayClose {
	SBJsonStreamWriterStateMachine *state = states[depth--];
	if (humanReadable) {
		if ([state isKindOfClass:[InArray class]])
			[self write:"\n" len:1];
		[state writeWhitespace:self];
	}
	
	[self write:"]" len:1];
	[states[depth] appendedAtom:self];
}

- (BOOL)writeNull {
	SBJsonStreamWriterStateMachine *s = states[depth];
	if ([s needKey:self]) return NO;
	[s writeSeparator:self];
	if (humanReadable) [s writeWhitespace:self];

	[self write:"null" len:4];
	[s appendedAtom:self];
	return YES;
}

- (BOOL)writeBool:(BOOL)x {
	SBJsonStreamWriterStateMachine *s = states[depth];
	if ([s needKey:self]) return NO;
	[s writeSeparator:self];
	if (humanReadable) [s writeWhitespace:self];
	
	if (x)
		[self write:"true" len:4];
	else
		[self write:"false" len:5];
	[s appendedAtom:self];
	return YES;
}


- (BOOL)writeValue:(id)o {
	if ([o isKindOfClass:[NSDictionary class]]) {
		return [self writeObject:o];

	} else if ([o isKindOfClass:[NSArray class]]) {
		return [self writeArray:o];

	} else if ([o isKindOfClass:[NSString class]]) {
		[self writeString:o];
		return YES;

	} else if ([o isKindOfClass:[NSNumber class]]) {
		return [self writeNumber:o];

	} else if ([o isKindOfClass:[NSNull class]]) {
		return [self writeNull];
		
	} else if ([o respondsToSelector:@selector(proxyForJson)]) {
		return [self writeValue:[o proxyForJson]];

	}	
	
	[self addErrorWithCode:EUNSUPPORTED
			   description:[NSString stringWithFormat:@"JSON serialisation not supported for @%", [o class]]];
	return NO;
}

static const char *strForChar(int c) {	
	switch (c) {
		case 0: return "\\u0000"; break;
		case 1: return "\\u0001"; break;
		case 2: return "\\u0002"; break;
		case 3: return "\\u0003"; break;
		case 4: return "\\u0004"; break;
		case 5: return "\\u0005"; break;
		case 6: return "\\u0006"; break;
		case 7: return "\\u0007"; break;
		case 8: return "\\b"; break;
		case 9: return "\\t"; break;
		case 10: return "\\n"; break;
		case 11: return "\\u000b"; break;
		case 12: return "\\f"; break;
		case 13: return "\\r"; break;
		case 14: return "\\u000e"; break;
		case 15: return "\\u000f"; break;
		case 16: return "\\u0010"; break;
		case 17: return "\\u0011"; break;
		case 18: return "\\u0012"; break;
		case 19: return "\\u0013"; break;
		case 20: return "\\u0014"; break;
		case 21: return "\\u0015"; break;
		case 22: return "\\u0016"; break;
		case 23: return "\\u0017"; break;
		case 24: return "\\u0018"; break;
		case 25: return "\\u0019"; break;
		case 26: return "\\u001a"; break;
		case 27: return "\\u001b"; break;
		case 28: return "\\u001c"; break;
		case 29: return "\\u001d"; break;
		case 30: return "\\u001e"; break;
		case 31: return "\\u001f"; break;
		case 34: return "\\\""; break;
		case 92: return "\\\\"; break;
	}
	NSLog(@"FUTFUTFUT: -->'%c'<---", c);
	return "FUTFUTFUT";
}

- (void)writeString:(NSString*)string {	
	SBJsonStreamWriterStateMachine *s = states[depth];
	[s writeSeparator:self];
	if (humanReadable) [s writeWhitespace:self];
	
	NSMutableData *data = [stringCache objectForKey:string];
	if (data) {
		[self write:[data bytes] len:[data length]];
		[s appendedAtom:self];
		return;
	}
	
	NSUInteger len = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	const char *utf8 = [string UTF8String];
	NSUInteger written = 0, i = 0;
		
	data = [NSMutableData dataWithCapacity:len * 1.1];
	[data appendBytes:"\"" length:1];
	
	for (i = 0; i < len; i++) {
		int c = utf8[i];
		if (c >= 0 && c < 32 || c == '"' || c == '\\') {
			if (i - written)
				[data appendBytes:utf8 + written length:i - written];
			written = i + 1;

			const char *t = strForChar(c);
			[data appendBytes:t length:strlen(t)];
		}
	}

	if (i - written)
		[data appendBytes:utf8 + written length:i - written];

	[data appendBytes:"\"" length:1];
	[self write:[data bytes] len:[data length]];
	[stringCache setObject:data forKey:string];
	[s appendedAtom:self];
}

- (BOOL)writeNumber:(NSNumber*)number {
	if ((CFBooleanRef)number == kCFBooleanTrue || (CFBooleanRef)number == kCFBooleanFalse)
		return [self writeBool:[number boolValue]];
	
	SBJsonStreamWriterStateMachine *s = states[depth];
	if ([s needKey:self]) return NO;
	[s writeSeparator:self];
	if (humanReadable) [s writeWhitespace:self];
		
	if ((CFNumberRef)number == kCFNumberPositiveInfinity) {
		[self addErrorWithCode:EUNSUPPORTED description:@"+Infinity is not a valid number in JSON"];
		return NO;

	} else if ((CFNumberRef)number == kCFNumberNegativeInfinity) {
		[self addErrorWithCode:EUNSUPPORTED description:@"-Infinity is not a valid number in JSON"];
		return NO;

	} else if ((CFNumberRef)number == kCFNumberNaN) {
		[self addErrorWithCode:EUNSUPPORTED description:@"NaN is not a valid number in JSON"];
		return NO;
		
	} else if (number == notANumber) {
		[self addErrorWithCode:EUNSUPPORTED description:@"NaN is not a valid number in JSON"];
		return NO;
	}
	
	const char *objcType = [number objCType];
	char num[64];
	size_t len;
	
	switch (objcType[0]) {
		case 'c': case 'i': case 's': case 'l': case 'q':
			len = sprintf(num, "%lld", [number longLongValue]);
			break;
		case 'C': case 'I': case 'S': case 'L': case 'Q':
			len = sprintf(num, "%llu", [number unsignedLongLongValue]);
			break;
		case 'f': case 'd': default:
			if ([number isKindOfClass:[NSDecimalNumber class]]) {
				char const *utf8 = [[number stringValue] UTF8String];
				[self write:utf8 len: strlen(utf8)];
				[s appendedAtom:self];
				return YES;
			}
			len = sprintf(num, "%g", [number doubleValue]);
			break;
	}
	[self write:num len: len];
	[s appendedAtom:self];
	return YES;
}

#pragma mark Private methods

- (NSUInteger)depth {
	return depth;
}

- (void)write:(char const *)utf8 len:(NSUInteger)len {
    NSUInteger written = 0;
    do {
        NSInteger w = [stream write:(const uint8_t *)utf8 maxLength:len - written];	
	    if (w > 0)																	
		   	written += w;															
	} while (written < len);													
}

- (void)setMaxDepth:(NSUInteger)x {
	maxDepth = x;
	states = realloc(states, x);
	NSAssert(states, @"Failed to reallocate more memory for states");
}	

@end
