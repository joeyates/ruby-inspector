# Get stuff before polluting namespace
$aRawObjects = ObjectSpace.each_object(Class).to_a + ObjectSpace.each_object(Module).to_a

require 'webrick'
require 'erb'

class ObjectData
  attr_reader :object, :public_instance_methods, :public_methods, :private_methods, :constants, :included_modules, :singleton_methods

  def self.build_array(a)
    a.sort!{|k1, k2| k1.name <=> k2.name}
    a.inject({}) do |memo, o|
      memo[o.name] = ObjectData.new(o)
      memo
    end
  end

  def initialize(o)
    @object                  = o
    @public_instance_methods = o.public_instance_methods(false).sort
    @public_methods          = ObjectData.base_methods(o, 'public_methods').sort
    @private_methods         = ObjectData.base_methods(o, 'private_methods').sort
    @constants               = ObjectData.base_methods(o, 'constants').sort
    if o.class == Class
      @included_modules      = ObjectData.base_methods(o, 'included_modules').collect{ |c| c.name } 
      @singleton_methods     = o.singleton_methods(false).sort
    end
  end

  private

=begin

The *_methods methods take a parameter, which, when 'false' excludes inherited methods.
Unfortunately, 'constants' and 'included_modules' lack this parameter, so this equivalent
has been written.

Eliminates items inherited from ancestors.

This could be Object.[sMethod](all = true) if I wanted to pollute base objects!

Even the methods with the 'false' parameter don't remove overridden methods.

=end

  def self.base_methods(cls, sMethod)
    case sMethod
    when 'public_methods'
      a = cls.__send__(sMethod, false)
    when 'private_methods'
      a = cls.__send__(sMethod, false)
      cls.included_modules.each { |mod| a -= mod.private_methods }
    else
      a = cls.__send__(sMethod)
    end
    a -= cls.superclass.__send__(sMethod) if cls.respond_to?('superclass') && cls.superclass
    a
  end
end

$hObjects = ObjectData.build_array($aRawObjects)

require_relative '../lib/ruby-inspector/rdoc-reader'

def not_found(req, rsp)
  rsp.status = 400
  rsp['Content-Type'] = 'text/html'
  rsp.body = 'Page not found'
end

srv = WEBrick::HTTPServer.new(:Port => 3000)

######################################################
# Index

IndexTemplate = <<EOT
<h1>Ruby Introspector</h1>

<ul>
  <li><a href="/classes">Classes</a></li>
  <li><a href="/modules">Modules</a></li>
</ul>
EOT

srv.mount_proc('/') do |req, rsp|
  if req.path != '/'
    not_found(req, rsp)
    next
  end
  erb = ERB.new(IndexTemplate)
  rsp.status = 200
  rsp['Content-Type'] = 'text/html'
  rsp.body = erb.result(binding)
end

####################################################
# Classes

def object_links(sType, asNames)
  s = asNames.map{|sName| "<li>#{ link_to(sType, sName) }</li>" }.join("\n")
  "<ul>\n#{ s }</ul>\n"
end

def link_to(sType, sName)
  "<a href=\"/#{ sType }/#{ sName }\">#{ sName }</a>"
end

def string_array_to_ul(a)
  return "\n" if a.length == 0
  "<ul>\n<li>\n" << a.join("</li>\n<li>") << "</li>\n</ul>\n"
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

srv.mount_proc('/classes') do |req, rsp|
  /^\/classes(\/(?<name>.*))?/ =~ req.path
  case
  when name.nil?
    sType = 'classes'
    erb = ERB.new(ObjectsTemplate)
    rsp.status = 200
    rsp['Content-Type'] = 'text/html'
    rsp.body = erb.result(binding)
  when $hObjects.has_key?(name)
    obd = $hObjects[name]
    erb = ERB.new(ObjectTemplate)
    rsp.status = 200
    rsp['Content-Type'] = 'text/html'
    rsp.body = erb.result(binding)
  else
    not_found(req, rsp)
    next
  end
end

srv.mount_proc('/modules') do |req, rsp|
  /^\/modules(\/(?<name>.*))?/ =~ req.path
  case
  when name.nil?
    sType = 'modules'
    erb = ERB.new(ObjectsTemplate)
    rsp.status = 200
    rsp['Content-Type'] = 'text/html'
    rsp.body = erb.result(binding)
  when $hObjects.has_key?(name)
    obd = $hObjects[name]
    erb = ERB.new(ObjectTemplate)
    rsp.status = 200
    rsp['Content-Type'] = 'text/html'
    rsp.body = erb.result(binding)
  else
    not_found(req, rsp)
    next
  end
end

trap('INT') { srv.shutdown }
srv.start
