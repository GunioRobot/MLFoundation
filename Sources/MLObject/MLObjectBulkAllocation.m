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

#import <MLFoundation/MLObject/MLObjectBulkAllocation.h>
#import <MLFoundation/MLObject/MLObject.h>
#import <MLFoundation/MLCore/MLReallocationPolicy.h>
#import <MLFoundation/MLCore/MLAssert.h>

@interface NSObject (BulkAllocation)
+ (void)bulkAllocated:(md)obj;
@end

struct BulkAllocationDescriptor {
	Class klass;
	int instanceSize;
	uint32_t linksZoneCapacity;
	uint32_t objectsZoneCapacity;
	uint8_t *objectsZone;
	// А дальше - links zone.
};

md *MLObjectBulkAllocWrapped(Class klass, uint32_t capacity, BOOL instantReify)
{
 	// TODO: check that klass is MLObject.
	
	int linksZoneSize = MLArrayNextCapacity(sizeof(void *), 0, capacity, sizeof(struct BulkAllocationDescriptor));

	struct BulkAllocationDescriptor *linksZone = 
		(struct BulkAllocationDescriptor *)(sizeof(struct BulkAllocationDescriptor) + (uint8_t *)malloc(
			sizeof(struct BulkAllocationDescriptor) + sizeof(void *)*linksZoneSize));
	
	// TODO error checking as in realloc!

	linksZone[-1].klass = klass;
	linksZone[-1].instanceSize = MLObject_instance_size(klass);
	linksZone[-1].linksZoneCapacity = linksZoneSize;
	linksZone[-1].objectsZoneCapacity = MLArrayNextCapacity(linksZone[-1].instanceSize, 0, capacity, 0);

	linksZone[-1].objectsZone = (uint8_t *)malloc(linksZone[-1].objectsZoneCapacity * linksZone[-1].instanceSize);
	memset(linksZone[-1].objectsZone, 0, linksZone[-1].objectsZoneCapacity * linksZone[-1].instanceSize);
	
	md *retval = (md *)linksZone;
	int i;
	for (i=0; i<linksZone[-1].objectsZoneCapacity; i++) {
		retval[i] = (md)(linksZone[-1].objectsZone + (i * linksZone[-1].instanceSize));
		[[klass class] bulkAllocated:retval[i]];
		if (instantReify) [retval[i] reify];
	}

	return retval;
}

uint32_t MLObjectBulkCapacity(md *objects)
{
	struct BulkAllocationDescriptor *linksZone = (struct BulkAllocationDescriptor *)objects; 
	return linksZone[-1].objectsZoneCapacity;
}

md *MLObjectBulkReallocWrapped(md *bulkAllocatedObjects, uint32_t newCapacity, BOOL instantReify)
{
	int i;
	struct BulkAllocationDescriptor *linksZone = (struct BulkAllocationDescriptor *)bulkAllocatedObjects; 
	
	// 1) Сначала перемещаем и переразмечаем зону объектов, чтобы вывалиться раньше.
	int oldObjectsZoneSize = linksZone[-1].objectsZoneCapacity;
	int newObjectsZoneSize = MLArrayNextCapacity(linksZone[-1].instanceSize,
		oldObjectsZoneSize, newCapacity, 0);
	
	// 2) Избавляемся здесь от старых объектов, если нужно. В случае фейла
	// реаллокации зоны мы их проебём, но куда же деваться?
	// newCapacity может быть меньше чем newObjectsZoneSize. Это правильно: лучше 
	// перефинализировать, чем недофинализировать.
	if (newCapacity < oldObjectsZoneSize) {
		for (i=newObjectsZoneSize; i< oldObjectsZoneSize; i++) {
			if ([bulkAllocatedObjects[i] isReified]) [bulkAllocatedObjects[i] finalize];
		}
	}

	// 3) Наконец, реаллоцируем зону объектов. Если сфейлили - возвращаем nil:
	// ничего кроме финализированых объектов не потерялось. Но фейл реаллока при
	// уменьшении размера сомнителен.
	uint8_t *oldObjectsZone = linksZone[-1].objectsZone;
	uint8_t *newObjectsZone;
	if (oldObjectsZoneSize != newObjectsZoneSize) {
		newObjectsZone = realloc(linksZone[-1].objectsZone, newObjectsZoneSize * linksZone[-1].instanceSize);
		if (!newObjectsZone) return NULL;

		linksZone[-1].objectsZone = newObjectsZone;
		linksZone[-1].objectsZoneCapacity = newObjectsZoneSize;

		if (newObjectsZoneSize > oldObjectsZoneSize) {
			memset(linksZone[-1].objectsZone + (oldObjectsZoneSize * linksZone[-1].instanceSize),
			0, (newObjectsZoneSize - oldObjectsZoneSize) * linksZone[-1].instanceSize);
		}
	}

	// 4) Зона объектов перемещена. нужно теперь поменять ссылки в зоне ссылок,
	// чтобы если сфейлит реаллокация зоны ссылок, мы ничего не потеряли.
	int objectsAfterObjectsRealloc = MIN(linksZone[-1].objectsZoneCapacity, 
							 linksZone[-1].linksZoneCapacity);
	bulkAllocatedObjects = (md *)linksZone;
	if (oldObjectsZone != newObjectsZone) {
		for (i=0; i<objectsAfterObjectsRealloc; i++) {
			bulkAllocatedObjects[i] = (md)(linksZone[-1].objectsZone + (i * linksZone[-1].instanceSize));
		}
	}

	// 5) Теперь мы готовы к реаллокации зоны ссылок. Если сфейлили - возвращаем nil.
	// Мы снова ничего не потеряли кроме, возможно, финализированых объектов.
	int oldLinksZoneSize = linksZone[-1].linksZoneCapacity;
	int newLinksZoneSize = MLArrayNextCapacity(sizeof(void *), 
		oldLinksZoneSize, newCapacity, 
		sizeof(struct BulkAllocationDescriptor));
	
	if (oldLinksZoneSize != newLinksZoneSize) {
		struct BulkAllocationDescriptor *newLinksZone;
		newLinksZone = (struct BulkAllocationDescriptor *)realloc(&linksZone[-1], sizeof(struct BulkAllocationDescriptor) + newLinksZoneSize * (sizeof(void *)));
		if (!newLinksZone) return NULL;
		newLinksZone = (struct BulkAllocationDescriptor *)((uint8_t *)newLinksZone + sizeof(struct BulkAllocationDescriptor));

		newLinksZone[-1].linksZoneCapacity = newLinksZoneSize;
		linksZone = newLinksZone;
	}

	// 6) Зона ссылок успешно перемещена. Нужно теперь переразметить её.
	int objectsAfterLinksRealloc = MIN(linksZone[-1].objectsZoneCapacity, 
								 linksZone[-1].linksZoneCapacity);

	bulkAllocatedObjects = (md *)linksZone;

	if (objectsAfterLinksRealloc > objectsAfterObjectsRealloc) {
		for (i=objectsAfterObjectsRealloc; i<objectsAfterLinksRealloc; i++) {
			bulkAllocatedObjects[i] = (md)(linksZone[-1].objectsZone + (i * linksZone[-1].instanceSize));
			[[linksZone[-1].klass class] bulkAllocated:bulkAllocatedObjects[i]];
		}

	}

	// 7) И, наконец, если у нас просили reification - делаем это.
	// TODO: запоминать отдельно size и реифицировать только то что нужно
	if (instantReify) {
		for (i=0; i<newCapacity; i++) {
			if (![bulkAllocatedObjects[i] isReified]) [bulkAllocatedObjects[i] reify];
		}
	}

	return bulkAllocatedObjects;
}

void MLObjectBulkFree(md *objects)
{
	struct BulkAllocationDescriptor *linksZone = (struct BulkAllocationDescriptor *)objects; 
	int i;

	if (!objects) return;

	for (i=0; i<linksZone[-1].objectsZoneCapacity; i++) {
		[objects[i] finalize];
	}

	free(linksZone[-1].objectsZone);
	free(&linksZone[-1]);
}

