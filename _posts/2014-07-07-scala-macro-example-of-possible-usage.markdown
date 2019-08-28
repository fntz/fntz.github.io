---
layout: post
title:  "Scala Macro: Codegeneration"
date:   2014-07-07 16:46:00
categories: scala 
comments: true
tags: scala scalamacro 
summary: "How to generate wrapper for case branches" 
---

1 Intro
--------

Scala Macro system provides an ability for generate code - 
for example create a top level objects, 
generate new classes, or replace user code with a new generated code. 

Consider an ability for replace user code.

2 Program
-----------

I need to wrap case branches into repeating function. Far-fetched example:

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

Here, all result values I wrap into `Some`, but it might be a other function/object.

I can wrap all results into `Some` into compile time with scala macro. 
Also, I can a return `None` without definition, it will be by default.

3 Implementation
-------------------

I will use an annotation (`@wrap`) for mark such a code. 
Annotation will be work only for `val` or `def`. 

First of all, import all necessary packages for work with macros and annotations:

```scala
import scala.reflect.macros.whitebox.Context 
import scala.language.experimental.macros
import scala.annotation.StaticAnnotation
```

Then let's define a class annotation:

```scala 
class wrap extends StaticAnnotation {
  def macroTransform(annottees: Any*) = macro wrapImpl.wrap
}
```  

Here, I created a class with a name `wrap`, that will be using as annotation. 
For transformation of the code, 
I need to define method `macroTransform`. 
This method will be used to transform code after annotation to macro method:

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

In the method, we got a list with any code, 
but this code should contains a `match`-construction. 
This should be method or value definition. 
But for our need only a `match` definition: 
`case q"$expr match { case ..$cases }"` 
where we should fetch pattern match definition with quasiquotes help.

Firstly, collect on `cases` and 
fetch all branches without wildcard, and wrap each into `Some`. 

Secondly, a branch with wildcard (`_`) or we should define own, that return `None`.

In the end, we will return a new expression `q"$expr match { case ..$sumCases }"`.

This will return a list with cases, 
but when a list is empty, I should throw an error, because I need a `match`-statement.

As result, 
I replaced user code, 
with own, that contains a new expression and wrap all branches 
into specific function (`Option`-based).


4 Usage  
-----------

A few examples of usage:

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

I use the same technique for create `respondTo` method in the [spray-routing-ext](https://github.com/fntz/spray-routing-ext/issues/7).

References
------------

+ [Annotations](http://docs.scala-lang.org/overviews/macros/annotations.html)
+ [Quasiquotes Syntax](http://docs.scala-lang.org/overviews/quasiquotes/syntax-summary.html)
+ [Macros](http://docs.scala-lang.org/overviews/macros/usecases.html)
+ [Source code](https://gist.github.com/fntz/9350393a786385733e8a)


