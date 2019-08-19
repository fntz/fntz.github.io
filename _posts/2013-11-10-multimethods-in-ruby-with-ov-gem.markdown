---
layout: post
title:  "Multimethods in Ruby with the Ov gem"
date:   2013-11-10 19:54:00
categories: ruby 
comments: true
tags: ruby multimethods ov
summary: "Create multimethods for convenient work." 
---

Many programming languages have a powerful feature - multimethods or method overloading, but Ruby doesn't have that feature.
But in the Ruby it's still possible to do it, but as extra code. 

`Ov` the special gem to do multimethods.  

Basic Usage
------------

```ruby
require 'ov'

class MyClass
  include Ov                       # add and use
  
  let :test, String  do |str| 
    p "string is received"
  end   

  let :test, Array do |arr|
    p "array is recevied"
  end
end

my_class = MyClass.new

my_class.test("string") #=> "string is received" 
my_class.test([])       #=> "array is recevied"
```

And, of course, we can create constructors:

```ruby
class MyArray 
  include Ov
  attr_accessor :arr

  let :initialize do
    @arr = []
  end

  let :initialize, Fixnum do |fx|
    @arr = fx.times.map { nil }
  end 

  let :initialize, Fixnum, Any do |fx, any|
    @arr = fx.times.map { any }
  end
 
end

p MyArray.new()             #=> #<MyArray:0x9d39290 @arr=[]>
p MyArray.new(3)            #=> #<MyArray:0x9d3904c @arr=[nil, nil, nil]>
p MyArray.new(3, true)      #=> #<MyArray:0x9d38e08 @arr=[true, true, true]>
``` 



Moar
-------------

Create your own [pattern-matching](https://en.wikipedia.org/wiki/Pattern_matching).

```ruby
# magic 

module Matching
  def match(*args, &block)
    z = Module.new do 
      include Ov
      extend self
      def try(*args, &block)
        let :anon_method, *args, &block
      end
      def otherwise(&block)
        let :otherwise, &block
      end
      instance_eval &block
    end
    begin
      z.anon_method(*args)
    rescue NotImplementError => e 
      z.otherwise
    end  
  end
end
```

We create a module with the `match` method, that takes several `*args` 
 these arguments will be passed to the block. 
And in this `match` method, we defined an anonymous module with two methods:
`try` - it's the same as `when`,
`otherwise` - it's `else'.
When the `*args` do not match with the types in `try` then call `otherwise`.
Example:

```ruby
include Matching # I'm using it in the Main

match("String", [123]) do 
  try(String, Array) {|str, arr| p "#{str} #{arr}" }
  try(String) {|str| p "#{str}"  }
  otherwise { p "none" }
end 

# => "String [123]"
```

Another example: get resource:

```ruby
require "net/http"

match(Net::HTTP.get_response(URI("https://httpbin.org/status/200"))) do
  try(Net::HTTPOK) {|r| p r.header }
  try(Net::HTTPMovedPermanently) {|r| p r.header }
  otherwise { p "error" }
end
```

Depending on the results, different blocks will be executed.

References
------------

+ [Multiple dispatch](http://en.wikipedia.org/wiki/Multiple_dispatch)
+ [Function_overloading](http://en.wikipedia.org/wiki/Function_overloading)
+ [Polymorphism](http://en.wikipedia.org/wiki/Polymorphism_(computer_science))
+ [Ov gem](https://github.com/fntz/ov)

