require 'webrick'
require 'erb'
require_relative 'rdoc-reader'

module RubyInspector
  class Server < WEBrick::HTTPServer
    def initialize(hObjects)
      super(:Port => 3000)
      @hObjects = hObjects
      index
      classes
      modules
    end

    def not_found(req, rsp)
      rsp.status = 400
      rsp['Content-Type'] = 'text/html'
      rsp.body = 'Page not found'
    end

IndexTemplate = <<EOT
<h1>Ruby Introspector</h1>

<ul>
  <li><a href="/classes">Classes</a></li>
  <li><a href="/modules">Modules</a></li>
</ul>
EOT
    def index
      mount_proc('/') do |req, rsp|
        if req.path != '/'
          not_found(req, rsp)
          next
        end
        erb = ERB.new(IndexTemplate)
        rsp.status = 200
        rsp['Content-Type'] = 'text/html'
        rsp.body = erb.result(binding)
      end
    end

ObjectsTemplate = <<EOT
#{ IndexTemplate }
<%
klass = sType == 'classes' ? Class : Module
aObjects = $hObjects.select {|k, v| v.object.class == klass }.map{|k, v| k }
%>
<%= object_links(sType, aObjects) %>
EOT

ObjectTemplate = <<EOT
#{ IndexTemplate }
<%
obj = obd.object
%>
<h1><%= obj.name %></h1>
<% if obj.class == Class %>
<h3>superclass: <%= (obj.class == Class) and obj.superclass ? link_to('classes', obj.superclass) : '[None]' %></h3>
<h3>included_modules</h3>
<%= object_links('modules', obd.included_modules)  %>
<% end %>
<h3>constants</h3>
<%= string_array_to_ul(obd.constants) %>
<h3>class_methods</h3>
<%
bClassMethod = obj.class == Class ? true : false
%>
<%= string_array_to_ul(RDocReader.find_all(obj, bClassMethod, obd.public_methods)) %></br>
<h3>public_instance_methods</h3>
<%= string_array_to_ul(RDocReader.find_all(obj, false, obd.public_instance_methods)) %>
<h3>private_methods</h3>
<%= string_array_to_ul(obd.private_methods) %>
<% if obj.class == Class %>
<h3>singleton_methods</h3>
<%= string_array_to_ul(RDocReader.find_all(obj, false, obd.singleton_methods)) %>
<% end %>
EOT
    def classes
      mount_proc('/classes') do |req, rsp|
        /^\/classes(\/(?<name>.*))?/ =~ req.path
        case
        when name.nil?
          sType = 'classes'
          erb = ERB.new(ObjectsTemplate)
          rsp.status = 200
          rsp['Content-Type'] = 'text/html'
          rsp.body = erb.result(binding)
        when @hObjects.has_key?(name)
          obd = @hObjects[name]
          erb = ERB.new(ObjectTemplate)
          rsp.status = 200
          rsp['Content-Type'] = 'text/html'
          rsp.body = erb.result(binding)
        else
          not_found(req, rsp)
          next
        end
      end
    end

    def modules
      mount_proc('/modules') do |req, rsp|
        /^\/modules(\/(?<name>.*))?/ =~ req.path
        case
        when name.nil?
          sType = 'modules'
          erb = ERB.new(ObjectsTemplate)
          rsp.status = 200
          rsp['Content-Type'] = 'text/html'
          rsp.body = erb.result(binding)
        when @hObjects.has_key?(name)
          obd = @hObjects[name]
          erb = ERB.new(ObjectTemplate)
          rsp.status = 200
          rsp['Content-Type'] = 'text/html'
          rsp.body = erb.result(binding)
        else
          not_found(req, rsp)
          next
        end
      end
    end

    private
  
    def object_links(sType, asNames)
      s = asNames.map{|sName| "<li>#{ link_to(sType, sName) }</li>" }.join("\n")
      "<ul>\n#{ s }</ul>\n"
    end

    def link_to(sType, sName)
      "<a href=\"/#{ sType }/#{ sName }\">#{ sName }</a>"
    end

    def string_array_to_ul(a)
      return "None\n" if a.length == 0
      "<ul>\n<li>\n" << a.join("</li>\n<li>") << "</li>\n</ul>\n"
    end
  end
end
