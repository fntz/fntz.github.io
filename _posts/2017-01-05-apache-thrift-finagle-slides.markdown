---
layout: post
title:  "Apache Thrift, Finagle Slides"
date:   2017-01-05 23:25:00
comments: true
categories: scala
tags: thrift finagle 
summary: "My slides from the knowledge sharing lecture" 
---

My slides from the knowledge sharing lecture. 
I told about Apache Thrift Framework, and about Finagle. 

Summary about Thrift: 

1. Code generator from IDL for structures and services

2. Processor - around blocks, which wrap your business logic 

3. Protocol - serialization format (binary, compact, json)

4. Transport - network layer, how to send and receive data over network

5. Server - choose by latency/throughput

6. One service for one port


Summary about Finagle:

1. Built over many protocols: Thrift, Http, Mysql, Memcache...

2. Service it's a Function that will Return `Future`

3. `Future` it's a result of any async operation 

4. Service - just a function 

5. Filter - just a function 

6. Filter separate from application logic 

7. You can apply the same Filter for Client and for Server 

8. Compose Filters (because it's a Function)

9. Enjoy

[Slides](https://github.com/fntz/snippets/blob/master/apache_thrift_finagle.pdf)

[Source Code](https://github.com/fntz/snippets)





