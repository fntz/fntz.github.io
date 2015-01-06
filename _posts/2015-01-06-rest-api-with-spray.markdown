---
layout: post
title:  "Rest API with Spray.IO"
date:   2015-01-06 19:12:00
comments: true
categories: scala
tags: scala sprayio api rest
summary: "Create a Simple Rest API for manage posts." 
---


Common task for developer is create API for manage resources - posts, comments, todo tasks and similary. The most easy way to manage resources it's use REST API. 

In terms of Rest we have Http verbs for communicate with rest service. Another part of manage resources is their protection. We must ensure that user have permissions for read, write or delete resources.

As result of operations we might return status code, for example when we get all posts, we must return `200` status code, and body with all posts. When user not have permissions for delete post we must return `406 Not Acceptable` for example.

If we want to focus on API frameworks, i think the best choice this `spray.io`. Which asynchronous and modular this helps to build restful application without any troubles.

My goal is not to show how to create a complex application with spray, my goal is to show how to create a simple application but with Rest API, with token based authentication, and custom output instead of common html.

Base
---------

Any scala application must extend a `App` trait. `Spray.IO` build top on `Akka`, therefore we need create a some actors for manage request-response cycle.


```scala
import akka.io.IO
import akka.actor.{ActorSystem, Props}

import spray.can.Http

object Boot extends App {
  implicit val system = ActorSystem("rest")

  val restService = system.actorOf(Props[RestApiService], "rest-api")

  IO(Http) ! Http.Bind(restService, interface = "localhost", port = 8000)
}

```

As you see we create an `ActorSystem` this main actor of application, which need for manage other actors in system.

Then we create the child actor - `RestApiService`, this service need for handle requests for our API. And then we listen `localhost:8000` for handle requests.

Rest Api Service
-----------------

`RestApiService` must be actor, in this actor, we have one main method - `receive`, this method receives a some message, and processing it.

```scala
import akka.actor.Actor

class RestApiService extends Actor with RestRoute {
  def actorRefFactory = context
  def receive = runRoute(route)
}
```

`runRoute` method from `RestRoute` trait, which need for manage http requests. 

`route` - this our routes, let's see on `RestRoute` trait:

```scala
import com.github.fntzr.spray.routing.ext.Routable

trait RestRoute extends Routable {
  val route =
    scope("api") {
      scope("v1") {
        resource[PostController, Post](exclude("new", "edit", "update", "create"), {
          post0[PostController]("create")
        }, IntNumber) ~
        post0[AuthController]("login")
      }
    }
}
```

For routes i use `spray-routing-ext` library as dsl for description of the route, because spray dsl more verbose.

Now our URL start with `api/v1/` and then any method for manage resource. As resource i use `Post`, this is a simple case class:

```scala
case class Post(text: String)
```

In routing i describe `resource` and exclude some method, which i did not write, also as you see i describe `create` method in inner block, because standard `create` method work with form, not with json, but for Rest API i want to use json for create a new posts.

Also in routing i write a `login` method, this method need for authorize user in application.

And then i was able to work with next http urls:

```
GET api/v1/post/index - get all posts
GET api/v1/post/1     - get 1st post
DELETE api/v1/post/1  - delete 1st post
POST api/v1/post      - create new post
POST api/v1/login     - authorize
```

Controllers
---------------

Obviously, `delete` and `create` methods in controller must be protected, if not protect it then any guest might drop you posts or create new.

Spray routing it's only directives, which might compbine without any troubles and create new with necessary behavior.

For protect actions i create new directive. But before some words about token based authentication.

When you create a single page app (SPA), then page not reload many times as in common application, therefore with any ajax request we need pass special token header with key, if key exist in some storage (for example in redis) then user authorized, if header not present we need return http request with error for example `401 Unauthorized`.

My trait with header name: 

```scala
trait AuthValues {
  val authToken = "authToken"
  val authTokenHeader = "X-AUTH-TOKEN"
}
```  

Then create `protect` directive:

```scala
trait SecurityHelper extends AuthValues {
  import HttpService._

  def protect: Directive[User::HNil] = {
    optionalHeaderValueByName(authTokenHeader).flatMap {
      case Some(token) =>
        Db.authTokenList.find(t => t._1 == token) match {
          case Some(t) => provide(t._2)
          case None => complete(NotAcceptable, s"Token $token not found")
        }
      case None => complete(Unauthorized, s"$authTokenHeader is empty")
    }
  }
}
```

How it work? First we extract header name `X-AUTH-TOKEN`, and then if token found in database, all ok, otherwise return http error, if token broken this is NotAcceptable, if token not present this is Unauthorized. It's easy.

Because API work only with json i create a helper method for manage response:

```scala
trait RespondHelper {
  import HttpService._

  def r(result: ToResponseMarshallable) = respondWithMediaType(`application/json`) {
    complete(result)
  }
}
```

And now PostController, are you not forget that we protect `delete` and `create` methods?

```scala
trait PostController extends BaseController with SecurityHelper with RespondHelper {

  import HttpService._
  import MyJsonProtocol._

  def index = r(Db.postList.toList)


  def show(id: Int) = r {
    Db.postList.lift(id) match {
      case Some(post) => post
      case None => (NotFound, s"Post with $id not found.")
    }
  }


  def create = protect { user =>
    entity(as[Post]) { post =>
      Db.postList append post
      r("""  { "result": "ok"  }  """)
    }
  }

  def delete(id: Int) = protect { user =>
     Db.postList.lift(id) match {
       case Some(post) =>
         r(""" { "result": "ok" } """)
       case None => r(NotFound, s"Post with ${id} not found")
     }
  }

}
```

As you see we compose directives and protect `delete` and `create` method. As result all actions return json.

And `LoginController`:

```scala
trait AuthController extends BaseController with SecurityHelper with RespondHelper {

  import HttpService._
  import MyJsonProtocol._

  def login = {
    entity(as[User]) { user =>
      Db.userList.find(u => u == user) match {
        case Some(user) =>
          val token = UUID.randomUUID().toString
          Db.authTokenList append ((token, user))
          r(s"""{ "$authToken": "${token}" }""")

        case None =>
          r(Unauthorized, "Check name")
      }
    }
  }
}
```

When user authorized we create a new token and write to db.


As you can see create a spray Rest Api simple, and spray have a many features for manage routes as you want.


References
------------

+ [Source Code](https://gist.github.com/fntzr/4554bafb9b3cb4ed034c)
+ [Spray.IO](http://spray.io/)
+ [Akka](http://akka.io/)
+ [spray-routing-ext](https://github.com/fntzr/spray-routing-ext)
+ [Composing Directives](http://spray.io/documentation/1.1-SNAPSHOT/spray-routing/key-concepts/directives/#composing-directives)
+ [Custom directives](http://spray.io/documentation/1.1-SNAPSHOT/spray-routing/advanced-topics/custom-directives/)
+ [Spray Directives: Creating Your Own, Simple Directive](http://blog.michaelhamrah.com/2014/05/spray-directives-creating-your-own-simple-directive/)
+ [Spray Directives: Custom Directives, Part Two: flatMap](http://blog.michaelhamrah.com/2014/05/spray-directives-custom-directives-part-two-flatmap/)
+ [Token Based Auth for Play](https://github.com/jamesward/play-rest-security/)



