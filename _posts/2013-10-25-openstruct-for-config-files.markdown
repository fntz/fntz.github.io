---
layout: post
title:  "OpenStruct for Config files"
date:   2013-10-15 16:00:00
comments: true
categories: ruby
tags: ruby openstruct config snippet
summary: "Usage `OpenStruct` class for mapping config files." 
---


Simple config files like this:

```text
foo:bar
zed:set
baz:foo1


```

conveniently placed in `OpenStruct` class, which that seems designed for such thinsgs.


Implementation
--------------

```ruby
require "ostruct"

config = OpenStruct.new(
           File.read("config.conf")  #read file
            .each_line 
              .map(&:strip)          #strip string
                .reject(&:empty?)    #remove empty lines
                  .map(&->(str){str.split(":") }) #split lines
                    .reduce(Hash.new){ |hash, arr|  
                      hash.merge!({arr.first => arr.last}) #place in hash
                    }
          )

p config #=> #<OpenStruct foo="bar", zed="set", baz="foo1">
```

Simple.

Some Magic
------------

When you have that method defined, for example:

```ruby
config.foo? # => true or false
```

Then you need to add a module in `OpenStruct`:

```ruby
module MethodMissing
  def method_missing(method)
    method = method[0...-1].to_sym 
    !!marshal_dump[method] #cast to bool
  end
end

#and 

config = OpenStruct.new( 
          # ...
          ).extend(MethodMissing)

p config.foo?  #=> true
p config.foo0? #=> false
```

References
------------

+   [OpenStruct](http://www.ruby-doc.org/stdlib-2.0.0/libdoc/ostruct/rdoc/OpenStruct.html)

