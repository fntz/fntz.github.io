---
layout: post
title:  "Writing Todo App with Sirius.js"
date:   2014-12-18 20:00:00
comments: true
categories: coffeescript
tags: coffeescript javascript mvc
summary: "Long post about how to write Todo App with Sirius.js" 
---

TL;DR Writing applications with `Sirius.js` is easy.

+ [Sirius.js](https://github.com/fntzr/sirius)
+ [Source Code](https://github.com/fntzr/sirius/blob/master/todomvc/js/app.coffee)
+ [TodoApp Site](http://todomvc.com/)


Sirius.js it's a modern MVC web framework, which is designed to simplify client side application development. 

It has the following features:

+ MVC style, separate work with Model, Controller and View if you want
+ All important events (routes, custom events) in one place
+ Binding, you might bind model and view, with modify any attributes (class, id, data-*) on changes, bind view to model, view to view, and any object property to view.
+ For models available Validators, and you might easy add new own validators.
+ Html5 Routing, in browsers which not support html5 routing, all routes will be convert to hashbase routes.
+ Log all actions in application.
+ Work with any javascript library (jQuery, Prototypejs).

Any way lets create a simple todo app with `Sirius`.

Need create a several parts of application:

+ When click on `checkbox` then task should mark as completed
+ When click on destroy button then should remove task 
+ We might add new Task with input 
+ When double click on task, then should be display input and we might modufy task title 
+ When click on `toggle-all` then all task should be marked as completed 
+ When click on `clear completed` then should remove completed tasks
+ When set Task as completed, need update clear task counter in bottom
+ When add a new Task need update task count in bottom
+ When application not contain Task need hide bottom  
+ When click on 'active', 'completed' or 'all' then application should display task for this property (completed)

### Before work

I use last `Sirius.js` v0.6.3 from master branch.

Sirius.js have a some parts, which help us to create Application. Obviously for work we need define some Model, which contain model state. Models in `Sirius.js` must be extend `BaseModel`, who worked with Rails know about it. Our model should contain next attributes for correct work, firsly it's `title` where we might save user input information.
And we need `completed` attribute for mark model as completed, and something for identify model like `primary key` it's `id` attribute. 

I override `constructor` for generate uniq id for model: 

```coffee
class Task extends Sirius.BaseModel
  @attrs: ["title", {completed: false}, "id"]

  constructor: (obj = {}) ->
    super(obj)
    @_id = "todo-#{Math.random().toString(36).substring(7)}"

  is_active: () -> !@completed()
  
  is_completed: () -> @completed()  
  
```

As you can see i add for `@attrs` default argument for `completed` attribute: `false`, this means, when we create a model then it not marked as `completed`.

And i call `super(obj)`, it's need if we want create model with defined attributes `TodoList.add(new Task(title: "Rule the web"))` 

Ok, we create model class. But for work with application, we should store our Task, for it we need collection:

```coffee
TodoList = new Sirius.Collection(Task)
``` 

Yes, we might use javascript array, but `Sirius.Collection` support synchronization with server, filters, and might guarantee that collection only for one type (it's means when you add in `TodoList` not `Task`, and other type (`String` for example) then collection throw Error).

### Start application

We alreay have `Task` class and collection for save all tasks. Then let's start application. 

```
Sirius.Application.run
  route   : {}
  adapter : new JQueryAdapter()
```

Any Sirius.Application must be start with `run` method call. We must pass to `run` - `route` object, and adapter for current application. At the current moment `Sirius` support `JQueryAdapter` and `PrototypeAdapter`.

Let's create a first route for application. When `Sirius` Application run, then it generate `application:run` event, it's perfect place for define default models.

First create a route:

```coffee
routes = 
  "application:run" : {controller: MainController, action: "start"}
```  

And for it need create Controller. Controller it's a javascript object, which contain methods.

```coffee
MainController =
  start: () ->
    TodoList.add(new Task({title : "Create a TodoMVC template", completed: true}))
    TodoList.add(new Task(title: "Rule the web"))
``` 

It's easy. When application start then application generate `application:run` event, and call `MainController#start` method.

Ok. We add Task in collection, but how to add it in our html? 

One option it's add in `#start` method more code and convert `Task` into html presentation, but it's not sirius way.

Let's look at `Sirius.Collection#subscribe` method, when we add task in collection, collection will be generate `add` event:

```coffee
TodoList.subscribe('add', (todo) -> Renderer.append(todo))
``` 

Then data flow: 

```
application:run -> MainController#start -> TaskList#add -> generate add -> call Render.append(todo)
``` 

What is Render?

It's not part of `Sirius` framework, it's only object which contain methods which convert `Task` into `html` presentation. But I do not like create html by hand, therefore i use javascript template engine: `EJS`.

```coffee
Renderer =
  todo_template: new EJS({url: 'js/todo.ejs'})              // 1 
  view: new Sirius.View("#todo-list")                       // 2

  append: (todo) ->
    template = @todo_template.render({todo: todo})          
    @view.render(template).append()                        // 3 
```

`1` it's standart EJS object, where i point path for `ejs` template file.

This file it's simple:

```
<li id="<%= todo.id() %>">
  <div class="view">
    <input class="toggle" type="checkbox" />
    <label><%= todo.title() %></label>
    <button class="destroy" data-id="<%= todo.id() %>"></button>
  </div>
  <input class="edit"
         data-id='<%= todo.id() %>' value="<%= todo.title() %>"
    />
</li>
```

As you can see this only contain html.

`2` it's more interesting, this is `Sirius.View` object. When we work with Rails for example, view it's a page (for simplification). But when we work with client side framework view it's might be any element. `Sirius.View` it's abstraction over HTMLElement, and it contain some necessary methods.

`3` in this line, firstly we pass compiled template into `render` method, think of it as a method of preparation, it's like a complile template, and then we call `append`, this method modify element content and add a new content. If we create it with plain jquery, it would look like this

```javascript
template = todo_template.render({todo: todo})
$("#todo-list").append(template)
```  

Ok, when application start we add in task list new tasks, and user might see this tasks.

But one as you can see we create one task with `complete: true`, but in html does not differ from other. For it's we need apply binding. We should bind model to view. And then if model mark as completed, then html the same will be mark as completed.

For binding in `Sirius` need add some attributes for html:

```
<li id="<%= todo.id() %>">
  <div class="view">
    <input class="toggle" type="checkbox"
           data-bind-view-to="checked"
           data-bind-view-from="completed">
    <label><%= todo.title() %></label>
    <button class="destroy" data-id="<%= todo.id() %>"></button>
  </div>
  <input class="edit"
         data-id='<%= todo.id() %>' value="<%= todo.title() %>" />
</li>
```

For model to view binding we need add attributes into html: `data-bind-view-from` - this attribute specify model attribute (`completed` at current case). `data-bind-view-to` - this attribute specify html attribute which will be modified, when model attribute will be changed.

Control flow: `Task#completed=true` -> `add 'checked' property for class`.

Modify `Rendere#append` for bind model to view:

```coffee
append: (todo) ->
  template = @todo_template.render({todo: todo})
  @view.render(template).append()
  todo_view = new Sirius.View("li\##{todo.id()}") # find our li element
  todo.bind(todo_view)  
```

Ok, now when we add Task where `complete` is `true`, then input checkbox will be set check.

But it's mark checkbox as completed, but does nothing with the `LI` element itself. Therefore we need add `data-bind-view` for `LI`:

```
<li id="<%= todo.id() %>"
    data-bind-view-to="class"
    data-bind-view-transform="mark_as_completed"
    data-bind-view-from="completed" class="">
    ...
</li>
```

You already see `data-bind-view-to` and `data-bind-view-from`, new attribute is `data-bind-view-transfrom`. I will explain what it means. 

`complete` attribute might be only `true` or `false`. Yes, we might set up `class` attribute as `true` or as `false`, but it's not correct. And therefore we need convert our attribute into valid value, for it's need `transform` function.

```coffee
append: (todo) ->
  template = @todo_template.render({todo: todo})
  @view.render(template).append()
  todo_view = new Sirius.View("li\##{todo.id()}")
  todo.bind(todo_view, {
    transform:
      mark_as_completed: (t) -> if t then "completed" else "" // 1
  })
```

`1` - we take a `completed` attribute (true or false) and if `true` convert to `compeleted`. All simple. The same in jQuery:

```javascript
template = todo_template.render({todo: todo})
$("#todo-list").append(template)

var transform = function(todo) {
  if (todo.completed) {
    $("li#" + todo.id()).addClass("completed")
  }  
};
transform(todo);

+ code for watch changes in model, and on each changes need call `transform` method.
```

### When click on `checkbox` then task should mark as completed

I.e when we click on `checkbox` then model `completed` attributes should be set in `true`.

For it, need bind `view` with `model`. Firsly modify `Render#append`:

```coffee
append: (todo) ->
  template = @todo_template.render({todo: todo})
  @view.render(template).append()
  todo_view = new Sirius.View("li\##{todo.id()}")
  todo.bind(todo_view, {
    transform:
      mark_as_completed: (t) -> if t then "completed" else ""
  })
  todo_view.bind(todo)                                       
```

I only add `todo_view.bind(todo)` line, where bind `todo_view` - `LI` element with current Task model.

### When click on destroy button then should remove task

It's more complicated task, because `destroy` method we must remove task from collection, and should remove task from `UL` todo tasks. For it, i will add a new route, which will react when user click on `button`.  

```coffee
routes =
  # ... other routes
  "click button.destroy"  : {controller: TodoController, action: "destroy", data: "data-id"}
```

With `controller` and `action` we are already familiar. A new property is `data`. 

When we click on element, it's generate `MouseEvent` which contain `target` property. This is element, where we click. This element contain different attributes like `class`, `id`, `type`, `data-*` and others. And `data` property tell what attributes from HTMLElement need, extract it and pass it into controller action. 

```coffee
TodoController =
  destroy: (e, id) ->                                      // 1
    todo = TodoList.filter((t) -> t.id() == id)[0]         // 2
    TodoList.remove(todo)                                  // 3
``` 

`1` - method take two arguments, first it's MouseEvent (it's first argument for all actions which work with mouse, key, or custom events). Second argument it's our `data-id`  from button element, if you forgot, our template:

```html
<button class="destroy" data-id="<%= todo.id() %>"></button>
```

And if we rewrite this without `data`:

```coffee 
destroy: (e) ->
  id = $(e.target).data('data-id')
  todo = TodoList.filter((t) -> t.id() == id)[0]
  TodoList.remove(todo)  
```


`2` - find task by id. `filter`.

`3` - remove from collection.


Ok, we remove task from collection, but also need remove from html, for it i use `subscribe` method for check if task remove from collection:

```
TodoList.subscribe('remove', (todo) -> $("\##{todo.id()}").remove())
```

Find element in html, and remove it. 

### We might add new Task with input

Consider following code:

```coffee
MainController =
  start: () ->
    view  = new Sirius.View("#todoapp")                          // 1
    model = new Task()                                           // 2          
    view.bind2(model)                                            // 3 
    view.on("#new-todo", "keypress", "todo:create", model)       // 4

    TodoList.add(new Task({title : "Create a TodoMVC template", completed: true}))
    TodoList.add(new Task(title: "Rule the web"))

```

This is our old method, which will be called when application run.

In `1` i create new `Sirius.View` for this element.

Then in `2` i create new `Task` model.

And in `3` i call `bind2` method for view, this double side binding, it's the same as 

```coffee
model.bind(view)
view.bind(model)
```

Becuase i bind view and model, i modify html code for `input` element:

```html
<input id="new-todo" data-bind-view-from='title' data-bind-to="title" name="title" placeholder="What needs to be done?" autofocus>
``` 

I add `data-bind-view-from` - it's for model to view binding, and `data-bind-to` - view to model binding. With binding we already familiar.

More interesting it's `4` - `view.on("#new-todo", "keypress", "todo:create", model)`
Here we bind event `keypress` for "#new-todo". When this event occurs then will be generate a new event `todo:create`, and for method will related for `todo:create` we pass `model`. If we write this in more simple:

```coffee
model = new Task()
$("#new-todo").on('keypres', (key_event) -> 
  adapter.fire(document, 'todo:create', key_event, model)
)

``` 

Also we must write route for handle `todo:create` event:

```coffee
routes = 
  "todo:create" :     {controller: TodoController, action: "create", guard: "is_enter"}
```

New property is a `guard`. In our case, when we change input, then will be call `keypress` event, right? But we need create new model, only when user press enter key. Therefore `TodoController#create` call only after `is_enter` return true.

```coffee
TodoController =
  is_enter: (custom_event, original_event) ->
    return true if original_event.which == 13                // 1
    false

  create: (custom_event, original_event, model) ->           // 2 
    todo = new Task(title: model.title())                    // 3
    TodoList.add(todo)                                        
    model.title("")                                          // 4 
```

`1` - must return `true` only when it's `enter` key.

`2` - take a custom event from `todo:create`, then original event from `keypress`, and our argument: `model`.

`3` - create a new task with title which from model, this model from `MainController#start`.

`4` - update title, you remember we bind model with view, and when we update title in model, then reset text for view.

### When double click on task, then should be display input and we might modufy task title

For it action add event for task in `Renderer#append`:

```coffee
Renderer = 
  append: (todo) ->
    # ...
    todo_view = 
    # ...
    todo_view.on('div', 'dblclick', (x) ->                       # 1 
      todo_view.render("editing").swap('class')                  # 2
    )
```

When double click on div, need add `editing` class for current `todo_view` i.e. for `LI` element `2`.

### When click on `toggle-all` then all task should be marked as completed

For this actions let's add a new route:

```coffee
routes = 
    "click #toggle-all" : {controller: TodoController, action: "mark_all", data: 'class'}
```

```coffee
TodoController =
  mark_all: (e, state) ->                                                       # 1
    if state == 'completed' 
      TodoList.filter((t) -> t.is_completed()).map((t) -> t.completed(false))   # 2  
    else
      TodoList.filter((t) -> t.is_active()).map((t) -> t.completed(true))       # 3

    $("#toggle-all").toggleClass('completed')
```

When we click on `#toggle-all` then need add `completed` class for `toggle-all`.

In `mark_all` method (`1`), i pass `state`, this is extract from `class` attribute for `#toggle-all`.

And in `2` and `3` i mark all model completed, or reset completed attribute. Because we bind model with view, then all changes in model will be pass into view.

### When click on `clear completed` then should remove completed tasks

Add a new route:

```coffee
routes = 
  "click #clear-completed": {controller: BottomController, action: "clear"}  
```    

And controller:

```coffee
BottomController =
  clear: () ->
    TodoList.filter((t) -> t.is_completed()).map((t) -> TodoList.remove(t))  # 1
    Renderer.clear(0)                                                        # 2
```

In `1` i find all completed model and then remove them. Are you remember that we remove from collection, we remove from html?

About `2` in next section.

### When set Task as completed, need update clear task counter in bottom 

Counter should contain all tasks. For it i add callback for model:

```coffee
class Task extends Sirius.BaseModel
  # ...
  after_update: (attribute, newvalue, oldvalue) ->                      # 1 
    if attribute == "completed" || newvalue == true                     
      Sirius.Application.get_adapter().and_then((adapter) -> adapter.fire(document, "collection:length"))                                             # 2

```    

`1` - `after_update` method take a `attribute` which update, `new value` for model, and last value for model.

`2` - and then we get current adapter for application, and then fire new event.

For this custom event need add a new route:

```coffee
routes =
    "collection:length" : {controller: BottomController, action: "change"}
``` 

In controller:

```coffee
BottomController =
  change: () ->
    Renderer.clear(TodoList.filter((t) -> t.is_completed()).length)      # 1
```

`1` - find all completed tasks.

In `Renderer` new method:

```coffee
Renderer =
  clear_view: new Sirius.View("#clear-completed", (size) -> "Clear completed (#{size})") # 1

  clear: (size) ->
    if size != 0
      @clear_view.render(size).swap()        # 2
    else
      @clear_view.render().clear()           # 3
```

`1` - view which contain element, and method, wrap function

`2` - update text for element

`3` - clear text for element

in other words this work like:

```coffee
wrap = (size) -> "Clear completed (#{size})"
if size != 0 
  $("#clear-completed").text(wrap(size))
else
  $("#clear-completed").text("") 
```

#### A small note about perfomance. 

When we have many tasks, then need walk through the collection and find all `completed` tasks. It can be slowly. So other way for check changes in collection, we might write the next code:

```coffee
class MyCollection extends Sirius.Collection
  
  constructor: (klass, args...) ->
    super(klass, args)

    @length_of_completed_tasks = 0                 # 1

  add: (model) ->
    super(model)
    if model.is_completed()
      @length_of_completed_tasks ++               # 2

  remove: (model) ->
    super(model)
    if model.is_completed() 
      @length_of_completed_tasks --               # 3

``` 

We create own class for collection which extends `Sirius.Collection` and redefine some method for work with necessary property, in constructor `1` we create instance variable which start with 0, and in add `2` method we increment it property if task completed. In `3` we decrement, when task completed. 


### When add a new Task need update task count in bottom

When we add a new Task then counter should update, in previous section we talk only about `completed` tasks. In this work with all tasks. `Sirius.Collection` contain `length` property, and for `Sirius.View` available bind with any javascript property.

```coffee
MainController =
  start: () ->
    length_view = new Sirius.View("#todo-count strong")        
    length_view.bind(TodoList, 'length')                       # 1
```   

`1` - as you can see we bind view with `TodoList.lenght` property, when we add a new Task to Collection, then length changes and view updated. 


### When application not contain Task need hide bottom

It's some like previous code, we need bind collection length and view.

```coffee
MainController =
  start: () ->
    footer = new Sirius.View("#footer")
    footer.bind(TodoList, 'length', {
      to: 'class'
      transform: (x) ->
        if x == 0
          "hidden"
        else
          ""
    })
```   

When length will be equal 0, then need add `hidden` class for `footer`. Because not possible add `data-view-*` for `property`, then we add it with parameters.

### When click on 'active', 'completed' or 'all' then application should display task for this property (completed)

For it actions need add routes:

```coffee
routes = 
  "/"               : {controller: MainController, action: "root"}
  "/active"        :  {controller: MainController, action: "active"}
  "/completed"     :  {controller: MainController, action: "completed"}
```

And actions for controller:

```coffee
MainController =
  root: () ->
    Renderer.render(TodoList.all())

  active: () ->
    Renderer.render(TodoList.filter((t) -> t.is_active()))

  completed: () ->
    Renderer.render(TodoList.filter((t) -> t.is_completed()))
```

And in depends what action we must display different tasks.

```coffee
Renderer =
  view: new Sirius.View("#todo-list")
  render: (todo_list) ->
    @view.render().clear()                             # 1
    for todo in todo_list
      @append(todo)
```

In `1` we clear task list and then add tasks in html.

#### small note about routes, we might rewrite `completed` and `active` actions in one route:

```coffee
routes = 
  "/:display" :  {controller: MainController, action: "display"}
```

then in controller:

```coffee
MainController = 
  display: (url_part) ->
    if url_part == 'active' 
      # ...
    else
      # ...  
```

Another part of this task, need add `selected` class for `A` link, when click on it. 

```coffee
Sirius.Application.run
  route   : routes
  adapter : new JQueryAdapter()
  class_name_for_active_link: 'selected'
```


That is all. 

References
--------------------

+ [Sirius.js](https://github.com/fntzr/sirius)
+ [Source Code](https://github.com/fntzr/sirius/blob/master/todomvc/js/app.coffee)
+ [TodoApp Site](http://todomvc.com/)
