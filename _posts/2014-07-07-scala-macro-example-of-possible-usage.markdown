---
layout: post
title:  "Scala Macro: Example of possible usage"
date:   2014-07-07 16:46:00
categories: scala 
comments: true
tags: scala scalamacro 
summary: "Example of generate wrap for case branches" 
---

1. Intro
--------

Scala Macro system provides an ability for generate code - for example create a top level objects, generate new classes, or replace user code with a new generated code. 

Consider an ability for replace user code.

2 Program
-----------

Sometimes i need a wrap case branches into repeating function. Far-fetched example:

```scala
def myMethod(num: Int): Option[String] = num match {
  case num if num > 1 => 
    //...code
    Some("one")
  case num if num == 0 =>
    //...code  
  Some("zero")

  case _ => None
}
```

Here, all result values i wrap into `Some`, but it might be a other function or object.

With scala macro i can wrap all results into `Some` into compile time. Also i can a return `None` without definition, it will be by default.

3. Implementation
-------------------

I will use a annotation (`@wrap`) for marking the code. Annotation will be to work only for `val` or `def`. 

For start, import all necessary packages for work with macros and annotations.

```scala
import scala.reflect.macros.whitebox.Context 
import scala.language.experimental.macros
import scala.annotation.StaticAnnotation
```

After define a class annotation, as

```scala 
class wrap extends StaticAnnotation {
  def macroTransform(annottees: Any*) = macro wrapImpl.wrap
}
```  

Here, i created class with name a `wrap`, which will be using as annotation. 
For transformation code, need define method `macroTransform`. It method used for transform code after annotation to macro method:

```scala
@someAnnotation def method = ...
                ^^^^^^^^^^^^^^^^^^
                this will be transformed with macro method (it's `annottees: Any*`) 
```

Until all simply. But a macro method more complicated. 

```scala
object wrapImpl {
  def wrap(c: Context)(annottees: c.Expr[Any]*): c.Expr[Any] = {
    import c.universe._

    //List(Expr[Nothing](def m(s: String): Option[Int] = .... ))  
    val newExpr = annottees(0).tree.collect {
      case q"$expr match { case ..$cases }" =>

        val newCases = cases.collect {
          case cq"$pat if $cond => $expr" if s"$pat" != "_" => cq"$pat if $cond => Some($expr)"
        }

        val defaultCases = cases.find{ case cq"$pat if $cond => $expr" => s"$pat" == "_" }.orElse(Some(cq"_ => None")).get

        val sumCases = newCases ::: List(defaultCases)

        q"$expr match { case ..$sumCases }"
    }

    if (newExpr.isEmpty) {
      c.abort(c.enclosingPosition, "Expression or method, must contain `match` statement")
    }

    val result = annottees(0).tree match {
      case q"$mods def $tname[..$tparams](...$paramss): $tpt = $expr" =>
        q"$mods def $tname[..$tparams](...$paramss): $tpt = ${newExpr(0)}"

      case q"$mods val $pat = $expr" =>
        q"$mods val $pat = ${newExpr(0)}"
    }


    c.Expr[Any](result)
  }
}
```

In this method, we got a list with any code, but this code must contain a `match`. This might be a method or value definition. But for our need only a `match` definition: `case q"$expr match { case ..$cases }"` with quasiquotes we extract this pattern match definition, and use it for our purposes.

Firstly, collect on `cases` and extract all branches without wildcard, and wrap each into `Some`. 

Secondly, get branch with wildcard (`_`) or define own, which return `None`.

And end, return a new expression definition `q"$expr match { case ..$sumCases }"`.

This return a list with cases, but when list is empty, need a throw error, because need a `match` statement.

As result, we replaced user code, with own, which contain a new expression definition with wrap all branches into specific function, in our example it's `Some`.


4. Usage  
-----------

Some examples of usage:

```scala

  @wrap def method(s: String): Option[Int] = s match {
    case x if x == "1" => 1
    case x if x == "2" => 2
  }

  println(method("1")) // => Some(1)
  println(method("2")) // => Some(2)
  println(method("3")) // => None

  @wrap val myVal = List(2) match {
    case x::xs if x == 1 => x
    case _ => None
  }
  println(myVal) // => None

  @wrap def k = 1 // Error!
```

The same technique i use for create `respondTo` method for [spray-routing-ext](https://github.com/fntzr/spray-routing-ext/issues/7)

References
------------

+ [Annotations](http://docs.scala-lang.org/overviews/macros/annotations.html)
+ [Quasiquotes Syntax](http://docs.scala-lang.org/overviews/quasiquotes/syntax-summary.html)
+ [Macros](http://docs.scala-lang.org/overviews/macros/usecases.html)
+ [Source code](https://gist.github.com/fntzr/9350393a786385733e8a)


