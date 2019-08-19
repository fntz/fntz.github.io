---
layout: post
title:  "OpenStruct for configuration files"
date:   2013-10-15 16:00:00
comments: true
categories: ruby
tags: ruby openstruct config snippet
summary: "How to use `OpenStruct` class to mapping config files." 
---


Simple configuration files usually looks like:

```text
foo:bar
zed:set
baz:foo1
```

It all placed comfortably into `OpenStruct`, that are made for this kind of thing.


Implementation
--------------

```ruby
require "ostruct"

config = OpenStruct.new(
           File.read("config.conf")                           # read the file
            .each_line 
              .map(&:strip)                                   
                .reject(&:empty?)                             # remove the empty lines
                  .map(&->(str){str.split(":") })             # split the lines
                    .reduce(Hash.new){ |hash, arr|  
                      hash.merge!({arr.first => arr.last})    # place into hash
                    }
          )
# voila
p config #=> #<OpenStruct foo="bar", zed="set", baz="foo1">
```

Simple and easy.

Extra
------------

When we want to make sure that the method is really defined, for example:

```ruby
config.foo?             # => true or false
```

Then we need to add a module in the `OpenStruct`:

```ruby
module MethodMissing
  def method_missing(method)
    method = method[0...-1].to_sym 
    !!marshal_dump[method]              # cast to the bool
  end
end

# and then

config = OpenStruct.new( 
          # ...
          ).extend(MethodMissing)

p config.foo?  #=> true
p config.foo0? #=> false
```

References
------------

+   [OpenStruct](http://www.ruby-doc.org/stdlib-2.0.0/libdoc/ostruct/rdoc/OpenStruct.html)

