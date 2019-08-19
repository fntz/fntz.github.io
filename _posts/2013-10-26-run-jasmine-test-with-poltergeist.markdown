---
layout: post
title:  "How to run Jasmine tests with Poltergeist"
date:   2013-10-26 16:00:00
categories: tests
comments: true
tags: poltergeist jasmine tests
summary: "Sometimes it's convenient to see the test results directly in the terminal. With poltergeist driver it is easy." 
---

Always see the test results faster in the terminal. I use the jasmine bdd framework to tests the javascript code, 
but it runs in the browser, which is not convenient for me.

But it's just to run the same tests in the terminal with `capybara` and `poltergeist`. 

I wrote a simple script (rake task) for that.

1 Rake task
-------------------------

You need to install `capybara`, `poltergeist` gems for tests.

```
gem install capybara

gem install poltergeist
```

And then create a simple rake task:

```ruby
require 'rubygems'
require 'bundler'
require 'capybara'
require 'capybara/poltergeist'

desc "Run Specs"
task :run do 
  #....
end

task :default => :run
```

2 Run tests
---------------

To run the tests, I need to choose the `poltergeist` driver for `capybara` and run the `SpecRunner.html` file.

```ruby
Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app)
end
Capybara.current_driver = :poltergeist
```

In order to see the results, we use the `visit` method from `Capybara::DSL`.

```ruby
module Test
  include Capybara::DSL
  extend self

  def run
    session = Capybara::Session.new(:poltergeist)       # new session
    session.visit "SpecRunner.html"
    #....
  end
end
```

We're gonna start it all up with the `rake` command.

3 Reporters
---------------------------

To parse the results, I use `Nokogiri` gem and `colorize` for colorize output.

Red color for failed tests, green for passed.

```ruby
module Test
  include Capybara::DSL
  extend self

  def run
    #....
    doc = Nokogiri::HTML(session.html)     # get the html from page

    # all failed messages
    failed = doc.css("div#details .failed div.resultMessage.fail").to_enum

    doc.css("div.results > div.summary > div.suite").each do |suite|
      # find out root
      puts "> #{suite.css("a.description").first.text}"

      suite.css("div").each do |div|
        text = div.css("a").first.text 
        if div.class?('specSummary')
          if div.class?("passed")
            puts "---- #{text.colorize(:green)}"
          else
            puts div.text
            puts "---- #{text.colorize(:red)}"
            puts "#{failed.next.text}".colorize(:background => :red) # print failed message
          end  
        end
        puts "-> #{text}" if div.class?('suite')
      end
    end
  end
end
``` 

4 Results
------------------

it's got to be something like that:

![terminal]( https://photos-3.dropbox.com/t/0/AAAdgwMe8m3Za9A7TJagNNi_DGq7gDqBE-wXribEsu_PyQ/12/186946245/png/1024x768/3/1382814000/0/2/jasmine-poltergeist.png/TEefMMSR_oTpKEc2ezneklzEDmPE4uoZs-XZZqEc1S8 "Output")


References
------------

+   [Github repo](https://github.com/fntz/snippets/tree/master/jasmine-poltergeist)
+   [Poltergeist](https://github.com/jonleighton/poltergeist)
+   [Capybara](https://github.com/jnicklas/capybara)
+   [Jasmine BDD](http://pivotal.github.io/jasmine/)
+   [Nokogiri](http://nokogiri.org/)
+   [Rake](http://rake.rubyforge.org/)
+   [Colorize gem](https://github.com/fazibear/colorize)
