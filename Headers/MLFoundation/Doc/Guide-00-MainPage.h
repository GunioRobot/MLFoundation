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

/** @mainpage MLFoundation Guide.
 *
 * \section mp_intro Introduction
 *  MLFoundation - библиотека для разработки сетевых приложений первоначально
 *  разработанная для внутренних проектов компании undev.
 *	Язык - Objective-C + Foundation.
 *
 * \section mp_toc Table of Contents
 * 
 * -# \ref page1
 * -# \ref page2
 * -# \ref page3
 * -# Основные концепции
 *   -# MLActivity // \ref page4
 *   -# \ref page5
 * -# libev bindings 
 *   -# EVLoop
 *   -# EVWatcher
 *   -# EVIoWatcher
 *   -# EVTimerWatcher
 *   -# EVSignalWatcher
 *   -# EVChildWatcher
 *   -# EVAsyncWatcher
 *
 * \section mp_networking [Переписать] Networking classes
 *
 * Во-первых, это низкоуровневые биндинги к встроенной libev. Классы EVLoop, EVWatcher и его
 * наследники напрямую сбриджены с соответствующими структурами libev. В event loops автомагическим
 * образом внедрены autorelease pools, очищающиеся примерно в те моменты, когда бы сработали коллбэки idle.
 *
 * Во-вторых, это MLBufferedEvent, сделанная по образу и подобию libevent-овских
 * buffered events, но чище и быстрее. 
 *
 * В-третьих, это "высокоуровневые" классы. MLTCPAcceptor , MLTCPClientConnection, MLHTTPClient, MLHTTPServerConnection.
 *
 * \section mp_logger [Переписать] Logger & other
 * 
 * - MLApplication
 * - MLLogger
 * - MLSessionSet 
 *
 * Copyright 2009 undev
 */

#error "This file is for documentation only!"

