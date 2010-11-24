#!/usr/bin/env ruby
# ./rails_refactor.rb rename DummyController HelloController 
# ./rails_refactor.rb rename DummyController.my_action new_action

require 'config/environment'

class Renamer
  def initialize(from, to)
    @from, @to = from, to

    @from_controller, @from_action = from.split(".")

    @from_resource_name = @from_controller.gsub(/Controller$/, "")
    @to_resource_name   = to.gsub(/Controller$/, "")

    @from_resource_path = @from_resource_name.underscore

    @to_resource_path   = @to_resource_name.underscore
  end

  def replace_in_file(path, find, replace)
    contents = File.read(path)
    contents.gsub!(find, replace)
    File.open(path, "w+") { |f| f.write(contents) }
  end

  def controller_rename
    @to_controller_path = "app/controllers/#{@to.underscore}.rb"

    `mv app/controllers/#{@from.underscore}.rb #{@to_controller_path}`
    replace_in_file(@to_controller_path, @from, @to)

    `mv app/views/#{@from_resource_path} app/views/#{@to_resource_path}`

    @to_helper_path = "app/helpers/#{@to_resource_path}_helper.rb"
    `mv app/helpers/#{@from_resource_path}_helper.rb #{@to_helper_path}`

    replace_in_file(@to_helper_path, @from_resource_name, @to_resource_name)

    replace_in_file('config/routes.rb', @from_resource_path, @to_resource_path)
  end

  def controller_action_rename
    controller, action = @from.split('.')
    controller_path = "app/controllers/#{controller.underscore}.rb"
    replace_in_file(controller_path, action, @to)
    
    views_for_action = "app/views/#{@from_resource_path}/#{action}.*"

    Dir[views_for_action].each do |file|
      extension = file.split('.')[1..2].join('.')
      cmd = "mv #{file} app/views/#{@from_resource_path}/#{@to}.#{extension}"
      `#{cmd}`
    end
  end
end

if ARGV.length == 3
  command, from, to = ARGV
  renamer = Renamer.new(from, to)

  if command == "rename"
    if from.include? '.'
      renamer.controller_action_rename 
    else
      rename.controller_rename
    end
  end
else
  require 'test/unit'
  class RailsRefactorTest < Test::Unit::TestCase

    def setup
      `git checkout .`
      `rm -rf app/views/hello_world`
    end

    def renamer(from, to)
      Renamer.new(from, to)
    end

    def controller_action_rename(from, to)
      renamer(from, to).controller_action_rename
    end

    def controller_rename(from, to)
      renamer(from, to).controller_rename
    end

    def assert_file_changed(path, from, to)
      contents = File.read(path)
      assert contents.include?(to) 
      assert !contents.include?(from) 
    end

    def test_controller_action_rename
      controller_action_rename('DummiesController.index', 'new_action')
      assert_file_changed("app/controllers/dummies_controller.rb", "index", "new_action")
      assert File.exists?("app/views/dummies/new_action.html.erb")
      assert !File.exists?("app/views/dummies/index.html.erb")
    end

    def test_controller_rename
      controller_rename("DummiesController", "HelloWorldController")
      assert File.exist?("app/controllers/hello_world_controller.rb")
      assert !File.exist?("app/controllers/dummies_controller.rb")

      assert File.exist?("app/views/hello_world/index.html.erb")
      assert !File.exist?("app/views/dummies/index.html.erb")

      controller_contents = File.read("app/controllers/hello_world_controller.rb")
      assert controller_contents.include?("HelloWorldController") 
      assert !controller_contents.include?("DummiesController") 

      routes_contents = File.read("config/routes.rb")
      assert routes_contents.include?("hello_world") 
      assert !routes_contents.include?("dummies") 

      helper_contents = File.read("app/helpers/hello_world_helper.rb")
      assert helper_contents.include?("HelloWorldHelper") 
      assert !helper_contents.include?("DummiesHelper") 

    end
  end
end
