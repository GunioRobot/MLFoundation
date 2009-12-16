/*

 Copyright 2009 undev
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

extern NSString* const MLFoundationErrorDomain;

extern NSString* const MLHTTPErrorKey;

/** NSError code values для MLFoundationErrorDomain. */
enum {
	MLSocketOpenError = 1,
	MLSocketBindError = 2,
	MLSocketListenError = 3,
	MLSocketAcceptError = 4,
	MLSocketConnectError = 5,
	MLSocketReadError = 6,
	MLSocketWriteError = 7,
	MLSocketEOFError = 8,
	MLSocketBufferOverflowError = 9,
	MLSocketTimeoutError = 10,
	MLSocketHTTPError = 11,
	MLApplicationStartError = 20,
	MLStreamBufferOverflowError = 30,	// MLStreamReserve вернул NULL
	MLStreamBufferFormatError = 31,		// При десериализации в буфере вместо ожидаемого типа данных оказалось что-то другое

	MLSerializableNotEnoughBytes = 41, // При десериализации по протоколу MLSerializable не хватило байтов.
	MLUnableToAllocate = 51 			// alloc вернул nil
};
