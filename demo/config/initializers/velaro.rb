
if RUBY_PLATFORM == "java"
  include Java

  # TODO: perhaps externalize this classpath thing so the environment or higher up config controls?
  # $CLASSPATH << "file:///#{File.expand_path(File.join(RAILS_ROOT, 'lib'))}/velocity-1.6.4-dep.jar"
	
	require Rails.root + '/lib/velocity-1.6.4-dep.jar'

  java_import 'org.apache.velocity.app.Velocity'
  java_import 'org.apache.velocity.VelocityContext'
  java_import 'java.io.StringWriter'
else
  Rails.logger.error "VelocityViewHandler requires JRuby"
end # if java

# Renders template through Apache Velocity when run in JRuby, otherwise it simply returns the template itself
module Velaro
  class VelocityViewHandler < ActionView::TemplateHandler
    include ActionView::Template::Handlers::Compilable
  
    cattr_accessor :templates
    self.templates = {}
    
    def compile(template)
      vt_name = template.virtual_path
      
      templates[vt_name] ||= VelocityTemplate.new
      templates[vt_name].template = template

      %{::Velaro::VelocityViewHandler.templates['#{vt_name}'].render_it(controller, self, local_assigns)}
    end
    
  end
  
  class VelocityTemplateRenderer
    attr_accessor :template
    
    def initialize(template)
      self.template = template
    end
    
    def render(context)
      writer = StringWriter.new
      Velocity.init
      Velocity.evaluate(context, writer, "LOG", template.source)
      writer.getBuffer.to_s
    end
  end
  
  class VelocityTemplate
    attr_accessor :renderer
    
    def initialize(template=nil)
      self.template = template unless template.nil?
    end
    
    def template=(template)
      self.renderer = VelocityTemplateRenderer.new(template)
    end
    
    def render_it(controller, view, local_assigns)
      return template.source if RUBY_PLATFORM != "java"

      #   "#{template} : #{local_assigns} :: #{template.source}"
      # TODO: Uberspecter for Ruby objects?
      # TODO: use VelocityEngine, etc, from Solritas usage
      context = VelocityContext.new

      load_instance_variables(context, controller)
      load_locals(context, local_assigns)

      context.put('view', self)
      context.put('local_assigns', local_assigns)
      # context.put('view', @view)
      
      renderer.render(context)      
    end
    
    def load_instance_variables(context, controller)
      instance_variable_names(controller).each do |name|
        context.put(name[1..-1], controller.instance_variable_get(name))
      end
    end
    
    def load_locals(context, local_assigns)
      local_assigns.each do |k,v|
        context.put(k, v)
      end
    end
    
    def instance_variable_names(controller)
      ivars = controller.instance_variable_names - ["@template"]
      return ivars unless controller.respond_to?(:protected_instance_variables)
      
      ivars - controller.protected_instance_variables
    end
  end
end

ActionView::Template.register_template_handler :vel, Velaro::VelocityViewHandler
