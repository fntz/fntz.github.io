---
layout: post
title:  "Akka patterns and anti patterns"
date:   2017-06-29 22:37:00
comments: true
categories: scala
tags: akka 
summary: "Post about Akka, and how to write more akka-idiomatic code" 
---

## Reminder

1. Akka — asynchronous message passing

2. Akka — fault-tolerance

3. Akka — actors do not share state

4. Akka — actor have lifecycle 


### A few rules how to work with `Future` inside Actor:

- move heavy job (heavy computation/IO blocking operations) inside `Future` — without it you may get thread starvation.

- do not use `context.dispatcher` for Futures:

```scala
// inside actor


// wrong 

import context.dispatcher

def receive = {
  case msg =>
    Furure {
      runBlockingOperaiontOrHeavyComputation()
    }
}


// ok 

implicit val ec = context.system.dispatchers.lookup("my-executor")


```

It's related to previous point. 


- do not block via `Await.result`, return result from `Future` with `pipe` pattern

```scala

// wrong

def receive = {
  case msg =>
    sender ! Await.result(computation(), 10 seconds)     
}

// ok


def receive = {
  case msg =>
    computation() pipeTo sender      
}


```

- do not change state inside `Future` block

```scala
 // inside actor

 var state: Int = 0 

 def receive = {
    case msg =>
      state = state + 1 
      Future {
         computation()
      }.foreach { _ =>
        state = state + 1 
      }

 } 


```

When we run this block of code, we can get:

```
actor thread: 617, state=1
actor thread: 617, state=3   !!! oops
future thread: 616, state=3  !!! oops
```

As you can see, 2 different threads see the same `state = 3`, there is race condition.


### Long initialization

This is one from akka base pattens, a few rules for this patten:

1. do not initialize actor via message, because if you actor is restarted, then you get unexpected behaviour of actor

2. initialize what you need in `preStart` block
 
3. use `stash` and `become` while an actor is not initialized

Implementations: 

```scala

// you may think about this class as about db/cache/network connection or something like this 
class MyClass { 
   Thread.sleep(1000)

   def calc(x: Int) = x + 1 
}



class MyActor {
   
  var deps: MyClass = null 

  // 1   
  override def preStart(): Unit = {
    Future { new MyClass } pipeTo self
  }

  // 2
  def uninitialized: Receive = {
    case md: MyClass =>
      deps = md
      self ! LongInitialize.Done
    case LongInitialize.Done =>
    // 3
      unstashAll()
      become(initialized)

    // 4  
    case _ => stash()
  }
  
  // 5
  def initialized: Receive = {
    case x: Int => sender ! deps.calc(x + 1)
  }
  
  // 6
  override def receive = uninitialized
}

```

1. As you can see, I initialize `MyClass` inside `Future`, in `preStart` method. 
Result of an operation I will pass with `pipe` to `uninitialized` block.

2. `uninitialized` block, that in case of `MyClass` change state of `deps` `var`iable

3. when `deps` is changed, I will change state of actor via `become` block, 
and I will resend all messages with `unstashAll` to normal state (`initialized` block) 
 
4. `stash`, that save all messages while the actor is unitialized

5. normal state of actor

6. start actor in `uninitialized` state

This is pattern you should use, when you actor is gateway between 
actor system and between another world: 
db connection, cache initialization, or network connection.



## A few rules for Actors

1. Do not use one actor to the rule them all 

2. Do not mix all business logic in one actor (the same as previous point)

3. split application on supervisor zones

4. use `Escalate` for differentiate one of actor level failures from application level failures

5. Do not use `ask` - use tell


### Don't `ask`, `tell`

1. what about supervisor strategy for ask? (how to retry (yep, i know how to create `retry` block :) ))

2. broken actor model with `?` (communication only with messages fire and forgot)

3. timeout hell, how to manage timeout in application? 

4. class cast exceptions


Small example of `ask` refactoring. Let's create a sample: 


```scala

// PicturesActor


def receive = {
  case msg @ GetUserPictures(userId, resize) =>
    (dbActor ? GetUserPicturesFromDB(userId))
      .mapTo[Vector[Picture]].flatMap { pictures =>
         resizeActor ? ZoomPictures(resize).mapTo[Resize].map { xs => 
            Response(xs)
         } 
      } pipeTo sender 
  case msg @ SavePicture(userId, pictureUrl) =>
    (imageDownloader ? Download(pictureUrl)).mapTo[Vector[Byte]].flatMap { raw =>
       (dbActor ? SavePicture(userId, raw)).mapTo[Picture].map { picture =>
         Response(picture)
       }
    }  pipeTo sender  
}
  

```

#### refactoring, part one


1. add supervisor strategy

2. move all logic in child actor

3. forward message to child

```scala

// 1
override val supervisorStrategy = OneForOneStrategy() {
  case _: Throwable =>
    Restart
}

def receive = {
  case msg: GetUserPictures =>
    // 2, 3
    context.actorOf(GetUserPicturesActor.props) forward msg
}

```

#### part two

```scala
// GetUserPicturesActor

var originalSender = context.system.deadLetters   

var resize: Int = 1

def receive = {
  case GetUserPictures(userId, userResize) =>
    originalSender = sender 
    resize = userResize
    dbActor ! GetUserPicturesFromDB(userId)
  
  case dbResponse: UserPictures(pictures) => 
    resizeActor ! ZoomPictures(resize)
  
  case resizeResponse: Resize => 
    originalSender ! Response(resizeResponse)      
}

```

#### done

As a result, we have an one actor (`PicturesActor`) with failure zone: all throubles in `GetUserPicturesActor` will be handled by `supervisorStrategy` block, 
and we create one actor for each request, it's normal for actor based application.


### Retry 

1. Retry is only combination of `preRestart` block and `Restart` supervisor strategy

```scala

// supervisor actor, for example PicturesActor, from previous example

override val supervisorStrategy = OneForOneStrategy() {
  case _: Throwable =>
    // on every throwable we will restart child
    Restart
}


// and child actor, GetUserPicturesActor

// one more attempt
// sender is original sender of message, not parent, not dead letters
// as you know, we have an actor per request => then it's will be original sender of message
override def preRestart(reason: Throwable, message: Option[Any]): Unit = {
  message.foreach { m => self.tell(m, sender) }
}


// or return 500 for web based applications
// yep, without Restart, just for example, how to use preRestart block
override def preRestart(reason: Throwable, message: Option[Any]): Unit = {
   sender ! InternalServerError("oops")
}

```  
  

### Circuit breaker


1. Proxy between our actor based application (ActorSystem) and another world

2. have 3 states: Closed (normal state), Open (remote system is not available), Half-Open (maybe remote system is avaiable) 

```scala
// external service
if (x == 0) {
  sender ! akka.actor.Status.Failure(new RuntimeException("boom!"))
} else {
  sender ! Result(x + 1)
}
```

#### for ask pattern

```scala

val breaker = CircuitBreaker(
  scheduler = context.system.scheduler,
  maxFailures = 1,
  callTimeout = 1 second,
  resetTimeout = 3 seconds
)
  .onOpen(whenOpen)
  .onHalfOpen(whenHalfOpen)
  .onClose(whenClose)


def receive = {
  case x: Int =>
    breaker
        .withCircuitBreaker(externalService ? x) 
            pipeTo sender  
}

```

and example for it

```scala

myActor ! 0
myActor ! 0
Thread.sleep(4000) // timeout for reset
myActor ! 4

// will be generete the next events:

- Failure(java.lang.RuntimeException: boom!)
- open CB
- Failure(CBOE: Circuit Breaker is open; calls are failing fast)
- wait 
- half-open
- close
- Result(5)


```

#### Circuit Breaker for tell pattern

It's more complicated, but it's work the same as for ask

```scala


def receive = {
  case x: Int if breaker.isClosed =>
    originalSender = sender
    externalService ! x

  case x: Int if breaker.isHalfOpen =>
    originalSender = sender
    externalService ! x
  
  case _: Int =>
    sender ! Status.Failure(new RuntimeException("breaker fail fast"))
  
  case r: Result =>
    originalSender ! r

    breaker.succeed()           // call explicitly 
  
  case t =>
    breaker.fail()              // call explicitly
}

```

Instead of `withCircuitBreaker` I handle the state of circuit breaker manually  



### Prepare work

Problem: actor A and actor B need the same before main logic

```scala
// actor A

def receive {
  case Message1 => 
    originalSender = sender 
    someActorRef ! Message1
  case Result1 =>
     someActorRef ! Message2
  case Result2 =>
     // actor logic
     originalSender ! ResultFromA 
}


// actor B

def receive {
  case Message1 => 
    originalSender = sender 
    someActorRef ! Message1
  case Result1 =>
     someActorRef ! Message2
  case Result2 =>
     // actor logic
     originalSender ! ResultFromB 
}


```

For solution I use the next sample:

```scala

// pass construct function for results

class PrepareActor(f: (Result1, Result2) => Props) extends Actor {
  
  val someActorRef = context.actorOf(Props[SomeActor])
  
  // save original info about message and sender
  var originalMessage: Any = null
  var originalSender: ActorRef = null
  var result1: Result1 = null
  
  def receive = {
    case r: Result1 =>
      result1 = r
      someActorRef ! Message2(2)
  
    case result2: Result2 =>
      // construct Actor and pass message with original sender 
      context.actorOf(f(result1, result2))
        .tell(originalMessage, originalSender)
  
    case m: Any =>
      originalMessage = m
      originalSender = sender
      someActorRef ! Message1(1)
  }
}

```

And then 

```scala
// actor A
class A(r1: Result1, r2: Result2) extends Actor {
  def receive = {
    case Start =>
      sender ! Result(r1.x + r2.x)
  }
}

// actor B 
class A(r1: Result1, r2: Result2) extends Actor {
  def receive = {
    case Start =>
      sender ! Result(r1.x * r2.x)
  }
}
```

Of course it's not the best solution, but sometimes it's enough


# References

[letitcrash](http://letitcrash.com/)

[blog.akka.io](http://blog.akka.io/)

[akka-patterns](https://github.com/sksamuel/akka-patterns)

[source code](https://github.com/fntz/akka-pattens)







