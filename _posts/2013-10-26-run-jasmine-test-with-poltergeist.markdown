---
layout: post
title:  "Run Jasmine tests with Poltergeist"
date:   2013-10-26 16:00:00
categories: tests
comments: true
tags: poltergeist jasmine tests
summary: "Sometimes comfortable viewing results of tests in terminal. With poltergeist driver it easy." 
---

In the terminal can faster see the results of the test run, then in the browser. For tests javascript code i use jasmine bdd framework, but it run in the browser, is not so convenient.

But you can run tests directly in the terminal with `capybara` and `poltergeist`. 

For this, i wrote simple rake task for run tests in terminal.

1 Rake task
-------------------------

You need install `capybara`, `poltergeist` for run tests.

```
gem install capybara
```

```
gem install poltergeist
```

And create simple rake task:

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

For running tests, i should choose `poltergeist` driver for `Capybara` and run `SpecRunner.html` file with capybara.

```ruby
Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app)
end
Capybara.current_driver = :poltergeist
```

Then, visit on our page with tests, it possibly with `visit` method from `Capybara::DSL`.

```ruby
module Test
  include Capybara::DSL
  extend self

  def run
    session = Capybara::Session.new(:poltergeist) #create new session
    session.visit "SpecRunner.html"
    #....
  end
end
```

Run this method with `rake` command.

3 Reporters
---------------------------

For parse results, i use `Nokogiri` gem and `colorize` for colorize output.

Red color for failed tests, and green for passed.

```ruby
module Test
  include Capybara::DSL
  extend self

  def run
    #....
    doc = Nokogiri::HTML(session.html) #get html from page

    # all failed messages
    failed = doc.css("div#details .failed div.resultMessage.fail").to_enum

    doc.css("div.results > div.summary > div.suite").each do |suite|
      # Root
      puts "> #{suite.css("a.description").first.text}"

      suite.css("div").each do |div|
        text = div.css("a").first.text 
        if div.class?('specSummary')
          if div.class?("passed")
            puts "---- #{text.colorize(:green)}"
          else
            puts div.text
            puts "---- #{text.colorize(:red)}"
            puts "#{failed.next.text}".colorize(:background => :red) #print failed message
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

Have something like this:

![terminal]( https://photos-3.dropbox.com/t/0/AAAdgwMe8m3Za9A7TJagNNi_DGq7gDqBE-wXribEsu_PyQ/12/186946245/png/1024x768/3/1382814000/0/2/jasmine-poltergeist.png/TEefMMSR_oTpKEc2ezneklzEDmPE4uoZs-XZZqEc1S8 "Output")


References
------------

+   [Github repo](https://github.com/fntzr/snippets/tree/master/jasmine-poltergeist)
+   [Poltergeist](https://github.com/jonleighton/poltergeist)
+   [Capybara](https://github.com/jnicklas/capybara)
+   [Jasmine BDD](http://pivotal.github.io/jasmine/)
+   [Nokogiri](http://nokogiri.org/)
+   [Rake](http://rake.rubyforge.org/)
+   [Colorize gem](https://github.com/fazibear/colorize)
