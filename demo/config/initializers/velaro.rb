
if RUBY_PLATFORM == "java"
  include Java

  # TODO: perhaps externalize this classpath thing so the environment or higher up config controls?
  # $CLASSPATH << "file:///#{File.expand_path(File.join(RAILS_ROOT, 'lib'))}/velocity-1.6.4-dep.jar"
	
	require "#{Rails.root.join('lib/velocity-1.6.4-dep.jar')}"

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
  
    def compile(template)
      
      #  borrowed from http://gist.github.com/449345
      # <<-VELARO
      #   velaro = ::#{velaro_class}.new
      #   # velaro.view = self
      #   # velaro[:yield] = content_for(:layout)
      #   # velaro.context.update(local_assigns)
      #   # variables = controller.instance_variable_names
      #   # variables -= %w[@template]
      #   # if controller.respond_to?(:protected_instance_variables)
      #   #   variables -= controller.protected_instance_variables
      #   # end
      #   # variables.each do |name|
      #   #   velaro.instance_variable_set(name, controller.instance_variable_get(name))
      #   # end
      #   # Declaring an +attr_reader+ for each instance variable in the
      #   # Mustache::Rails subclass makes them available to your templates.
      #   # TODO: velaro.class.class_eval do
      #   #   attr_reader *variables.map { |name| name.sub(/^@/, '').to_sym }
      #   # end
      # 
      #   velaro.render
      # VELARO
      
      vtr_class = template.virtual_path.gsub(/\//,'_').camelize
      if !Velaro.const_defined?(vtr_class)
        Velaro.module_eval <<-VTRIMPL
          class #{vtr_class} < VelocityTemplateRenderer
            cattr_accessor :template
          end
        VTRIMPL
      end
      
      # TODO: does this deserve caching consideration?
      "Velaro::#{vtr_class}".constantize.template=template
      
      <<-VTR
        vtr=Velaro::#{vtr_class}.new
        var_names = controller.instance_variable_names - %w[@template]
        if controller.respond_to?(:protected_instance_variables)
          var_names -= controller.protected_instance_variables
        end
        variables = {}
        var_names.each do |name|
          variables[name[1..-1]] = controller.instance_variable_get(name)
        end
        vtr.instance_variables = variables
        vtr.local_assigns = local_assigns
        vtr.view = self
        # TODO: params?  request?  env? lookup context?  status? or all gotten from view?
        # content_for(:layout) - do we need to do something with this?
        vtr.render_it
      VTR
    end
  end
  
  class VelocityTemplateRenderer
    attr_accessor :instance_variables
    attr_accessor :view
    attr_accessor :local_assigns
    
    def render_it
      return template.source if RUBY_PLATFORM != "java"
  
      #   "#{template} : #{local_assigns} :: #{template.source}"
      # TODO: Uberspecter for Ruby objects?
      # TODO: use VelocityEngine, etc, from Solritas usage
      context = VelocityContext.new
      
      instance_variables.each do |k,v|
Rails.logger.debug("instance var:  #{k}=#{v}")
        context.put(k, v)
      end
      
      local_assigns.each do |k,v|
Rails.logger.debug("local var:  #{k}=#{v}")
        context.put(k, v)
      end
      
      context.put('view', view)
      
      context.put('local_assigns', local_assigns)
      # context.put('view', @view)
      writer = StringWriter.new
      Velocity.init
      Velocity.evaluate(context, writer, "LOG", self.template.source)
      writer.getBuffer.to_s
    end
  end
end

ActionView::Template.register_template_handler :vel, Velaro::VelocityViewHandler
