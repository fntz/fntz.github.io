---
layout: post
title:  "Nginx and Consul"
date:   2017-10-22 12:00:00
comments: true
categories: consul
published: false
tags: nginx consul consult-template akka-http 
summary: "Control backend services with consul" 
---

### Overview

Often need to support a few services in actual _live_ state, and inform another services when whatever service is dead. Especially it is noticeable for microservices architecture. When one service depends on a few another. And need to know actual network configuration in current moment. Also it's need to know which services is live for load balancing, because return 502 not do user happy. 

As a solution it's a service discovery.

Consul one from many tools which support this feature. In this post i cover how to use consul and nginx for load balancing.

```

                             [server 1]
[user request] -> [nginx] -> [server 2]
                             [server 3]
```

In Nginx we should use `upstream` directive and `location` for send user request to service.

```
http {
  
  upstream backend {       
    server 127.0.0.1:10000;
  }

  server {
    location /resource {
      proxy_pass http://backend;
    }
  }
}

``` 

All requests to `/resource` will be pass to `backend` service.

### Register service

For work with consul from scala i will be use `consul-client` from `com.orbitz.consul`

For service registration need initialize consul and pass a few parameters:

```scala
val consul = Consul.builder().build()
val agentClient = consul.agentClient()

val service = "my-backend-service"
val url = new URL(s"http://$interface:$port/health")
agentClient.register(
                      port,                               // 1  
                      url,                                // 2
                      3L,                                 // 3 
                      service,                            // 4
                      serviceId,                          // 5
                      "http", "backend", "resource"       // 6 
                    )
```

1 - port for our service

2 - url, health check url, need for keep in actual state of our service

3 - how frequently need re-run health check (in my example - every 3 seconds)

4 - service name

5 - node name, hostname, an unique identifier

6 - tags


This is all, now if you open consul ui (`http://localhost:8500/ui/#/dc1/services/consul`) you might see

![consul-ui](https://raw.githubusercontent.com/fntz/fntz.github.io/master/imgs/consul-ui.png)

### Service implmentation

For service implementation i will use `akka-http` with two endpoints:

```scala

class HttpApi(serviceId: String)(
             implicit mat: ActorMaterializer,
             ec: ExecutionContext,
             timeout: Timeout
             ) {

  import Directives._

  val route = {
    path("resource") {
      complete(s"ok: $serviceId")
    } ~ path("health") {
      complete("ok")
    }
  }
}

```

As you can see, two endpoints:

one - just return `ok` + `serviceId`

second - return ok, it's our health check (from previous example)


### Consule template

If one service is dead, then we need update actual nginx configuration, for this i use `consule-template` project:

run:

```
consul-template -template="/path/nginx.tpl:/path/nginx.conf:nginx -s reload"
```

our template:


```
{% raw %}
http {
  upstream backend {
    {{ range service "my-backend-service"}} 
      server { {.Address} }:{ {.Port} };
    { {end} }
  }

  server {
    location /resource {
      proxy_pass http://backend;
    }
  }
}
{% endraw %}
```


In `range` block we need only `my-backend-service` and then just define `server host:port` from info about service.


### Check

just run `curl -XGET localhost/resource` in response you should see: `ok: 1` or `ok: 2`.

If you stop one from backend services, you anyway will be see response.  


This is all. See source code for full example. 


# References

[service discovery](https://en.wikipedia.org/wiki/Service_discovery) 

[consul-client](https://github.com/OrbitzWorldwide/consul-client)

[nginx](https://nginx.org/en/)

[consul](https://www.consul.io/)

[consul-template](https://github.com/hashicorp/consul-template)

[akka-http](https://doc.akka.io/docs/akka-http/current/scala/http/)

[source code](https://github.com/fntz/snippets/tree/master/nginx-consul)






