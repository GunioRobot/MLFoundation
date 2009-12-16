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

#import <MLFoundation/MLStreamFunctions.h>

uint64_t MLStreamPeekLine(id<MLStream> buf)
{
	uint8_t *data = MLStreamData(buf);
	uint64_t len = MLStreamLength(buf);
	uint64_t i;

	for (i=0; i<len; i++) {
		if (data[i] == '\r' || data[i] == '\n') break;
	}

	if (i == len) return 0;
	if (i < len-1) {	
		char sch = data[i], nch = data[i+1];
		if ((nch == '\r' || nch == '\n') && sch != nch) i++;
	}

	i++; // 'index' vs length

	return i;
}

char *MLStreamReadLine(id<MLStream> buf)
{
	uint8_t *data = MLStreamData(buf);
	uint64_t len = MLStreamPeekLine(buf);

	if (!len) return NULL;

	data[len-1] = '\0';
	if (len > 1) {
		if (data[len-2] == '\r' || data[len-2] == '\n') data[len-2] = '\0';
	}

	return (char *)data;
}

void MLStreamDrainLine(id<MLStream> buf)
{
	uint8_t *data = MLStreamData(buf);
	uint64_t buflen = MLStreamLength(buf);
	uint64_t len = 1 + strlen((char *)data);

	if (len < buflen && data[len] == '\0') len ++;

	MLStreamDrain(buf, len);
}

BOOL MLStreamAppendByte(id<MLStream> buf, uint8_t byte)
{
	uint8_t *place = MLStreamReserve(buf, 1);
	if (!place) return NO;
	*place = byte;
	return MLStreamWritten(buf,1);
}

BOOL MLStreamAppendBytes(id<MLStream> buf, uint8_t *bytes, uint64_t m)
{
	uint8_t *place = MLStreamReserve(buf, m);
	if (!place) return NO;
	memcpy(place, bytes, m);
	return MLStreamWritten(buf,m);
}

BOOL MLStreamAppendStream(id<MLStream> buf, id<MLStream> buf2)
{
	return MLStreamAppendBytes(buf, MLStreamData(buf2), MLStreamLength(buf2));
}

BOOL MLStreamAppendString(id<MLStream> buf, char *s)
{
	return MLStreamAppendBytes(buf, (uint8_t *)s, strlen(s));
}
