---
layout: post
title:  "spray-routing-ext: Extend spray-routing"
date:   2014-04-20 15:00:00
categories: scala 
comments: true
tags: scala spray spray-routing rails-routing
summary: "spray-routing-ext package to create rails like routes in spray framework" 
---

1. Intro
--------

Spray is a toolkit to create http applications top on akka. It's an actor-based, lightweight, 
modular framework. Spray contains several modules. 
And spray include a `spray-routing` to create dsl to building RESTful web services. 

It is interesting.

It is a full dsl, you able to create a high-level routes. 
But it's so verbose. 
When we create a MVC application, we have a controller, that take request and 
transform it into response. 
If we have verbose dsl, we might be confused, when change a small part, or forget something. 

I worked with Rails, that contains a small dsl for routes. 
Where you have a few primitives: http-method and Controller#action part, and dsl methods. 

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
  resources :models
```

Spray dsl more verbose.

So, I have a specification, spray route dsl and scala macro system:
`spray dsl + scala-macro = rails-like routes` :)

2. Basic
---------

`spray-routing-ext` have a few http methods for wrapping `plain http-method` and 
combine it with controller method call.

```scala
  get0[YourController](("foo" / IntNumber) ~> "foo")
```

in `YourController` you have a `foo` method:

```scala
def foo(param: Int) = { ... }
```

For wrap routes into one part I made `scope`:

```scala
  scope("part") {
    //....
  }
```

If you want to call controller method for several http-methods, use `match0`:

```scala
  match0[YourController]("baz", List(GET, PUT))
```

Now, a `#baz` can call for `get` and `put` http methods.

When we create a web services, we should return information, 
It's posts, comments, or something like this. 
It a database Model. For work with `controller`s and `model`s we can use `resource`. 

```scala
resource[YourController, Model](exclude("index"))
```

And now, all requests with `/model/` will be redirected to `YourController` methods: 
`index`, `show`, `delete`, `update`, `create`, `edit` and `fresh`.

Controllers is only trait that extend a `BaseController`. 
The `BaseController` is a trait with one field - `request` that contains current request.

With `spray-routing-ext` we divide dsl for routing: `get0`, `match0`, `root`. 
For controllers we should use a `spray-routing` dsl to return response:

```scala
  //in your controller:
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

But if our controllers is only traits, 
how me pass into trait db connection, or other resources, variables? 
I create the next solution:


```scala
//main 

object Main extends App {
  implicit val system = ActorSystem("system")
  val db = //connect with db
  val otherVal = 
  //I will pass into actor contructor all values, which need for work
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
    //I can use `db` or `myVal` + `request`
  }
}
```

Underhood is:

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

Define main system, where I create a db connection and an actor service, 
that transform requests into response:

```scala
object Blog extends App {
  implicit val system = ActorSystem("blog")
  val db = system.actorOf(Props[DBActor], "db")
  val service = system.actorOf(Props(classOf[ServiceActor], db), "blog-service")
  IO(Http) ! Http.Bind(service, "localhost", port = 8080)
}
```

Instead of `database` I use a simple actor with `HashMap`, which contain all posts. 

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

My db satisfies all criteria: 
return all posts, or one post, and delete, update and create post. 
For communication with `db` I define messages:

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

For `Vies`, I define trait that contains a method 
for view information in my browser, a small part: 

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

`HtmlView` contains methods for all actions, that we use into controller.

I have a database and a view. 
And I should extend my controller with these values, that contains a `db` and a `view`:

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
    respond {
      (db ? Index).mapTo[HashMap[Int, Post]].map { posts =>
        render.indexView(posts)
      }
    }
  }

  def show(id: Int) = {
    respond {
      (db ? Show(id)).mapTo[Option[Post]].map { post =>
        render.showView(post)
      }
    }
  }

  //other methods

  //where respond is 
  def respond(t: ToResponseMarshallable) = respondWithMediaType(`text/html`) & complete(t)
}

```

In controller, I can use the `db` for db connection and `render` for return response.

And now my route service:

```scala
//db is a database connection, do you remember?
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
    resource[PostController, Post](exclude("create"), {
      post0[PostController]("create")
    }) ~ root[PostController]("index")
  }
}
```

I excluded a `create` method and define himself, 
because in a form, I do not use an `id` field. 
And I defined `/` is a redirect to `index` method from `PostController`.

That's all. I created a blog in five minutes.


References
------------

+ [Spray](http://spray.io/)
+ [Rails Routing](http://guides.rubyonrails.org/routing.html)
+ [spray-routing-ext](https://github.com/fntz/spray-routing-ext)
+ [blog example sources](https://github.com/fntz/spray-routing-ext/blob/master/sample/src/main/scala/example.scala)
+ [Akka](http://akka.io/)
+ [scala macros](http://scalamacros.org/)

