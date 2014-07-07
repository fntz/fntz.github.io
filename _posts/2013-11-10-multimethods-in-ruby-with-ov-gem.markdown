---
layout: post
title:  "Multimethods in Ruby with Ov gem"
date:   2013-11-10 19:54:00
categories: ruby 
comments: true
tags: ruby multimethods ov
summary: "Create multimethods with Ov for comfortable work." 
---

Many programming language have the powerful feature - multimethods or method overloading, but in ruby not have this feature. However Ruby have a ability create this as library not built in feature. 

With `Ov` ruby gem ruby have ability of usage multimethods.   

Base Usage
------------

```ruby
class MyClass
  include Ov #only include and use
  
  let :test, String {|str| 
    p "string given"
  }  
  let :test, Array {|arr|
    p "array given"
  }
end

my_class = MyClass.new

my_class.test("sttring") #=> "string given" 
my_class.test([]) #=> "array given"
```

Ability to create constructors:

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

p MyArray.new() #=> #<MyArray:0x9d39290 @arr=[]>
p MyArray.new(3) #=> #<MyArray:0x9d3904c @arr=[nil, nil, nil]>
p MyArray.new(3, true) #=> #<MyArray:0x9d38e08 @arr=[true, true, true]>
``` 

More Usage
-------------

Create own `case-match` which work with types.

```ruby
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

We create a module with `match` method, which take a `*args` it's arguments which will be pass into block. And in `match` method, define anonymous module with 2 methods:
`try` - it's the same as and `when`,
`otherwise` - it's `else'.
When `*args` do not match with types in `try` then will be call `otherwise`.
Example:

```ruby
include Matching #include in Main

match("String", [123]) do 
  try(String, Array) {|str, arr| p "#{str} #{arr}" }
  try(String) {|str| p "#{str}"  }
  otherwise { p "none" }
end #=> "String [123]"
```

Other Example: Get resource:

```ruby
require "net/http"

match(Net::HTTP.get_response(URI("http://google.com"))) do
  try(Net::HTTPOK) {|r| p r.header }
  try(Net::HTTPMovedPermanently) {|r| p r.header }
  otherwise { p "error" }
end
```

Depending on the result call different blocks.


References
------------

+ [Multiple dispatch](http://en.wikipedia.org/wiki/Multiple_dispatch)
+ [Function_overloading](http://en.wikipedia.org/wiki/Function_overloading)
+ [Polymorphism](http://en.wikipedia.org/wiki/Polymorphism_(computer_science))
+ [Ov gem](https://github.com/fntzr/ov)

