---
layout: post
title:  "spray-routing-ext: Extend spray-routing"
date:   2014-04-20 15:00:00
categories: scala 
comments: true
tags: scala spray spray-routing rails-routing
summary: "spray-routing-ext package for create rails like routes in spray" 
---

1. Intro
--------

spray is a toolkit for create http application top on akka. It's an actor-based, lightweight, modular framework. Spray contains several modules. 
And it include a `spray-routing` for create dsl for building RESTfil web servises. 

it was very interesting.

It a full dsl, you might create a high-level routes. But it's very verbose. When we create a MVC application, we have a controller, which a take request and transform it into response. If we have a verbose dsl, we might confused, when change a small part, or forget something. 

I worked with rails web framework, it contain a small dsl for routes. Where you have a few primitives: http-method and Controller#action part, and dsl methods. 

For example:

spray-routing dsl:

```scala
  pathPrefix("model") {
    pathPrefix("index") {
      get {
        val models = Model.get_all_models //extract from database
        complete{models}
      }
    } ~
    pathPrefix(IntNumber) { num =>
      get {
        //show
      } ~ delete {
        //delete
      }
    } //and so on
  }
```   

in rails the same:

```ruby
  resourses :models
```

Spray dsl more verbose.

And so, i have a specification, spray route dsl and scala macro system:
`spray dsl + scala-macro = rails-like routes` :)

2. Basic
---------

`spray-routing-ext` have a few http methods for wrapping `plain http-method` and combine it with controller method call.

```scala
  get0[YouController](("foo" / IntNumber) ~> "foo")
```  

in `YouController` you have a `foo` method:

```scala
def foo(param: Int) = { ... }
```

For wrap something routes into one part use `scope`:

```scala
  scope("part") {
    //....
  }
```

If you want a call controller method for several http-methods, use `match0`:

```scala
  match0[YouController]("baz", List(GET, PUT))
```

And now, `#baz` can call for `get` and `put` http methods.

When we create a web servises, we should return something information, it's a posts, comments, or something like this. It a database Model. For work with `controller`s and `model`s we can use `resourse`. 

```scala
resourse[YouCotnroller, Model](exclude("index"))
```

And now, all requests with `/model/` will be redirected for `YouController` methods: `index`, `show`, `delete`, `update`, `create`, `edit` and `fresh`.

Controllers it only trait which extend `BaseController`. `BaseController` a trait with one field - `request` whitch contain current request.

With `spray-routing-ext` we divide dsl for routing: `get0`, `match0`, `root`. For controllers we use a `spray-routing` dsl for return response:

```scala
  //in you controller:
  def method(id: Int) = {
    //manipulation with id
    respondWithMediaType(`text/html`) {
      complete {
        {response}
      }
    }
  }
```

Also in controller you have access `request` - current request.

But if our controllers it only traits, how me pass into trait db connection, or other resourses, variables. I create the next solution:


```scala
//main 

object Main extends App {
  implicit val system = ActorSystem("system")
  val db = //connect with db
  val otherVal = 
  //i pass into actor contructor all values, which need for work
  val service = system.actorOf(Props(classOf[MyActor], db, otherVal), "my-service")
  IO(Http) ! Http.Bind(service, "localhost", port = 8080)
}

//my-actor:
class MyActor(db: DBConnection, myVal: OtherValType) extends Actor with MyRouteService {
  def actorRefFactory = context
  def receive = runRoute(route(db, myVal)) //and pass it into route
}

//my-route-servise
trait MyRouteService extends Routable {
  def route(db: DBConnection, myVal: OtherValType) =  {
    //routes here
  }
}

//injection:
trait MyInj {
  val db: DBConnection
  val myVal: OtherValType
}

//controller with injection
trait Controller extends BaseController with MyInj {
  def foo = {
    //i can use `db` or `myVal` + `request`
  }
}
```

Underhood it:

```scala
  //sum is a `request` + outer method params.
  //When you in Inj define value: myVal
  //But in method pass myVal0, in controller action, you got a 
  //undefined variable error, when will be use myVal instead myVal0 
  
  case class AnonClassController(..$sum) extends ${c.weakTypeOf[C]}
  val controller = new AnonClassController(..$names)
  $complete
  
```


3. Create blog in 5 minutes :)
--------------------------------  

It's mandatory part of all frameworks.

I have a `Post` model:

```scala
case class Post(id: Int, title: String, description: String)
```
As you can see it's just `id\title\description` fields.

Define main system, which create a db connection and actor service, which transform requests into response:

```scala
object Blog extends App {
  implicit val system = ActorSystem("blog")
  val db = system.actorOf(Props[DBActor], "db")
  val service = system.actorOf(Props(classOf[ServiceActor], db), "blog-service")
  IO(Http) ! Http.Bind(service, "localhost", port = 8080)
}
```

Instead of `database` i use a simple actor with `HashMap`, which contain all my posts. 

```scala
class DBActor extends Actor {
  import Messages._
  val posts = new HashMap[Int, Post]
  posts += (1 -> Post(1, "new post", "description")) //first post

  def receive = {
    case Index => sender ! posts
    case Show(id: Int) => sender ! posts.get(id)
    case Update(post: Post) =>
      posts += (post.id -> post)
      sender ! true
    case Delete(id: Int) =>
      posts.get(id) match {
        case Some(x) =>
          posts -= id
          sender ! true
        case None => sender ! false
      }
    case Create(title: String, description: String) =>
      val id = if (posts.size == 0) {
        1
      } else {
        posts.map{ case p @ (id, post) => id }.max + 1
      }
      posts += (id -> Post(id, title, description))
      sender ! id
  }
}

```

My db satisfies all specifications: return all posts, or one post, and delete, update and create post. For communication with `db` i define messages:

```scala
object Messages {
  case object Index
  case class Show(id: Int)
  case class Update(post: Post)
  case class Delete(id: Int)
  case class Create(title: String, description: String)
}
```

And now we create `M` from `MVC`.

For `Vies`, i define trait which contatin a method for view information in my browser, a small part: 

```scala
trait HtmlView {
  def indexView(posts: HashMap[Int, Post]) = {
    html(
      <div>
        {
          posts.collect {
            case p @ (_, Post(id: Int, title: String, description: String)) =>
              val href = s"/post/${id}/"
              <div>
                <h3><a href={href}>{id}: {title}</a></h3>
                <p>{description}</p>
              </div>
          }
        }
        <a href="/post/new">create new post</a>
      </div>
    )
  }
}
```

`HtmlView` contain methods for all actions, which we use into controller.

And so, i have a database and a view. And i should extends my controller with this values, which contain `db` and `view`:

```scala
trait DBInj {
  val db: ActorRef
}

trait HtmlViewInj {
  val render: HtmlView
}

//controller:
trait PostController extends BaseController with DBInj with HtmlViewInj {
  import Messages._ //for communication with database
  import HttpService._ //for use directives from spray-routing

  implicit val timeout = Timeout(3 seconds)

  def index = {
    val posts = Await.result(db ? Index, timeout.duration).asInstanceOf[HashMap[Int, Post]]
    respond(render.indexView(posts))
  }

  //other methods
}

```

In controller, i can use `db` for db connection and `render` for return response.

And now my route servise:

```scala
//db: is a database connection, do you remember?
class ServiceActor(db: ActorRef) extends Actor with ApplicationRouteService {
  def actorRefFactory = context
  //pass in runRoute db connection and HtmlView instance which map into `render` value
  def receive = runRoute(route(db, new HtmlView {}))
}
```

Routing:

```scala
trait ApplicationRouteService extends Routable {
  import Blog._

  //db connection
  //and view
  def route(db: ActorRef, render: HtmlView) =  {
    resourse[PostController, Post](exclude("create"), {
      post0[PostController]("create")
    }) ~ root[PostController]("index")
  }
}
```

Now, i exclude `create` method and define himself, because in form, i not use a `id` field. And i define that `/` is a redirect in `index` method from `PostController`.

That's all. I created a blog in five minutes.

4. TODO:
---------

* create method for form extraction: postForm\[Controller, Model\]("route" ~> "method")


References
------------

+ [Spray](http://spray.io/)
+ [Rails Routing](http://guides.rubyonrails.org/routing.html)
+ [spray-routing-ext](https://github.com/fntzr/spray-routing-ext)
+ [blog example sources](https://github.com/fntzr/spray-routing-ext/blob/master/sample/src/main/scala/example.scala)
+ [Akka](http://akka.io/)
+ [scala macros](http://scalamacros.org/)

