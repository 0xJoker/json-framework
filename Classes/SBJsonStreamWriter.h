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

#import <Foundation/Foundation.h>
#import "SBJsonBase.h"


@interface SBJsonStreamWriter : SBJsonBase {
	NSMutableArray *states;
	
@private
	NSOutputStream *stream;
    BOOL sortKeys, humanReadable;
}

@property BOOL humanReadable;
@property BOOL sortKeys;

- (id)initWithStream:(NSOutputStream*)stream;

// You must call open on the writer before writing any element
- (void)open;

// You must call close on the writer after writing all elements
- (void)close;

// Very high level
- (BOOL)write:(id)value;

// High-level methods
- (BOOL)writeObject:(NSDictionary*)dict;
- (BOOL)writeArray:(NSArray *)array;

// Mid-level methods
- (BOOL)writeObjectOpen;
- (void)writeObjectClose;
- (BOOL)writeArrayOpen;
- (void)writeArrayClose;

// Low-level methods
- (BOOL)writeNull;
- (BOOL)writeBool:(BOOL)x;
//- (BOOL)writeInteger:(long)l;
//- (BOOL)writeDouble:(double)d;
- (BOOL)writeNumber:(NSNumber*)n;
- (void)writeString:(NSString*)s;

@end
